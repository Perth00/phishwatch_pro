"""PhishWatch Pro API module.

- Exposes text preprocessing and URL analysis endpoints.
- Loads a URL model bundle from a local file or the Hugging Face Hub and
  caches artifacts in /data/.cache for stateless environments (e.g., Spaces).
"""

import os
import csv
import re
import threading
from typing import Optional, List, Dict, Any, Tuple
from difflib import SequenceMatcher

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from huggingface_hub import hf_hub_download
from pydantic import BaseModel
from urllib.parse import urlparse

try:
    import xgboost as xgb  # type: ignore
except Exception:
    xgb = None

# NLP libraries for Text Preprocessing (Module 2)
try:
    import nltk
    from nltk.tokenize import word_tokenize
    from nltk.corpus import stopwords
    from nltk.stem import PorterStemmer, WordNetLemmatizer
    from textblob import TextBlob
    
    # Download required NLTK data on startup
    for resource in ['punkt', 'stopwords', 'wordnet', 'omw-1.4']:
        try:
            nltk.data.find(f'tokenizers/{resource}' if resource == 'punkt' else f'corpora/{resource}')
        except LookupError:
            nltk.download(resource, quiet=True)
    
    NLTK_AVAILABLE = True
except Exception as e:
    print(f"[WARNING] NLP libraries not available: {e}")
    NLTK_AVAILABLE = False


# Environment defaults
os.environ.setdefault("HOME", "/data")
os.environ.setdefault("XDG_CACHE_HOME", "/data/.cache")
os.environ.setdefault("HF_HOME", "/data/.cache")
os.environ.setdefault("TRANSFORMERS_CACHE", "/data/.cache")
os.environ.setdefault("TORCH_HOME", "/data/.cache")


# Config
URL_REPO = os.environ.get("HF_URL_MODEL_ID", "Perth0603/Random-Forest-Model-for-PhishingDetection")
URL_REPO_TYPE = os.environ.get("HF_URL_REPO_TYPE", "model")
URL_FILENAME = os.environ.get("HF_URL_FILENAME", "rf_url_phishing_xgboost_bst.joblib")
CACHE_DIR = os.environ.get("HF_CACHE_DIR", "/data/.cache")
os.makedirs(CACHE_DIR, exist_ok=True)

URL_POSITIVE_CLASS_ENV = os.environ.get("URL_POSITIVE_CLASS", "").strip().upper()

BASE_DIR = os.path.dirname(__file__)
AUTOCALIB_PHISHY_CSV = os.environ.get("AUTOCALIB_PHISHY_CSV", os.path.join(BASE_DIR, "autocalib_phishy.csv"))
AUTOCALIB_LEGIT_CSV = os.environ.get("AUTOCALIB_LEGIT_CSV", os.path.join(BASE_DIR, "autocalib_legit.csv"))
KNOWN_HOSTS_CSV = os.environ.get("KNOWN_HOSTS_CSV", os.path.join(BASE_DIR, "known_hosts.csv"))

# Initialize NLP components
if NLTK_AVAILABLE:
    stemmer = PorterStemmer()
    lemmatizer = WordNetLemmatizer()
    stop_words = set(stopwords.words('english'))
    PHISHING_KEYWORDS = {
        'urgent', 'verify', 'suspended', 'locked', 'confirm', 'update',
        'click', 'prize', 'winner', 'congratulations', 'expire', 'act now',
        'account', 'security', 'password', 'credit card', 'bank', 'payment',
        'refund', 'tax', 'irs', 'social security', 'ssn', 'login', 'signin',
        'alert', 'warning', 'action required', 'unusual activity', 'compromised'
    }

# Consolidated lookalike characters dictionary
LOOKALIKE_CHARS = {
    # Cyrillic
    'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x',
    'у': 'y', 'ч': '4', 'ы': 'b', 'ь': 'b', 'і': 'i', 'ї': 'yi',
    'ґ': 'g', 'ė': 'e', 'ń': 'n', 'ș': 's', 'ț': 't',
    # Greek
    'α': 'a', 'ο': 'o', 'ν': 'v', 'τ': 't', 'ρ': 'p',
    # Latin Extended
    'ɑ': 'a', 'ɢ': 'g', 'ᴅ': 'd', 'ɡ': 'g', 'ɪ': 'i',
    'ɴ': 'n', 'ᴘ': 'p', 'ᴠ': 'v', 'ᴡ': 'w', 'ɨ': 'i'
}

BRAND_NAMES = [
    "facebook", "linkedin", "paypal", "google", "amazon", "apple",
    "microsoft", "instagram", "netflix", "twitter", "whatsapp", "bank", "hsbc", "yahoo", "outlook"
]

SUSPICIOUS_KEYWORDS = ["login", "verify", "secure", "update", "bank", "pay", "account", "webscr"]
SUSPICIOUS_TLDS = {"tk", "ml", "ga", "cf", "gq", "xyz", "top", "buzz", "icu", "fit", "rest", "work", "click", "country", "zip", "ru", "kim", "support", "ltd"}


app = FastAPI(
    title="PhishWatch Pro API",
    version="3.1.0",
    description="Phishing detection with calibrated confidence scores (50-85% range)"
)


class PredictUrlPayload(BaseModel):
    """Request model for /predict-url endpoint."""
    url: str


class PreprocessTextPayload(BaseModel):
    """Request model for /preprocess-text endpoint."""
    text: str
    include_sentiment: bool = True
    include_stemming: bool = True
    include_lemmatization: bool = True
    remove_stopwords: bool = True


_url_bundle: Optional[Dict[str, Any]] = None
_url_lock = threading.Lock()
_URL_EXTRACT_RE = re.compile(r"(https?://[^\s<>\"'\)\]]+)", re.IGNORECASE)
_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+\-.]*://")


# ============================================================================
# UTILITY FUNCTIONS (Consolidated)
# ============================================================================

def _normalize_host(value: str) -> str:
    """Lowercase host and strip an optional leading 'www.' prefix."""
    v = value.strip().lower()
    return v[4:] if v.startswith("www.") else v


def _host_matches_any(host: str, known: List[str]) -> bool:
    """Return True if host equals or is a subdomain of any entry in known."""
    base = _normalize_host(host)
    for item in known:
        k = _normalize_host(item)
        if base == k or base.endswith("." + k):
            return True
    return False


def _sanitize_input_url(text: str) -> str:
    """Extract the first URL-like token and strip wrappers like <>, [], (), and leading '@'."""
    v = (text or "").strip()
    if v.startswith("@"):
        v = v.lstrip("@").strip()
    m = _URL_EXTRACT_RE.search(v)
    if m:
        v = m.group(1)
    return v.strip("<>[]()")


def _ensure_scheme(u: str) -> str:
    """Ensure the string has a URL scheme; default to http:// when missing."""
    u = (u or "").strip()
    return u if _SCHEME_RE.match(u) else ("http://" + u)


def _normalize_url_string(url: str) -> str:
    """Normalize URLs for equality by trimming whitespace and a single trailing slash."""
    return (url or "").strip().rstrip("/")


def _normalize_brand(s: str) -> str:
    """Normalize brand tokens by lowercasing and removing non-letter characters."""
    return re.sub(r"[^a-z]", "", s.lower())


def _read_urls_from_csv(path: str) -> List[str]:
    """Read a list of URLs from CSV; supports a 'url' column or single-column CSV."""
    urls: List[str] = []
    try:
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            if "url" in (reader.fieldnames or []):
                for row in reader:
                    val = str(row.get("url", "")).strip()
                    if val:
                        urls.append(val)
            else:
                f.seek(0)
                for row in csv.reader(f):
                    if row:
                        val = str(row[0]).strip()
                        if val.lower() != "url" and val:
                            urls.append(val)
    except FileNotFoundError:
        pass
    except Exception as e:
        print(f"[csv] failed reading URLs from {path}: {e}")
    return urls


def _read_hosts_from_csv(path: str) -> Dict[str, str]:
    """Read a host->label map from CSV with columns 'host' and 'label' (PHISH|LEGIT)."""
    out: Dict[str, str] = {}
    try:
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            fields = [x.lower() for x in (reader.fieldnames or [])]
            if "host" in fields and "label" in fields:
                for row in reader:
                    host = str(row.get("host", "")).strip()
                    label = str(row.get("label", "")).strip().upper()
                    if host and label in ("PHISH", "LEGIT"):
                        out[host] = label
    except FileNotFoundError:
        pass
    except Exception as e:
        print(f"[csv] failed reading hosts from {path}: {e}")
    return out


def _shannon_entropy(txt: str) -> float:
    """Compute the Shannon entropy of a string."""
    if not txt:
        return 0.0
    counts: Dict[str, int] = {}
    for ch in txt:
        counts[ch] = counts.get(ch, 0) + 1
    total = float(len(txt))
    entropy = 0.0
    for n in counts.values():
        p = n / total
        entropy -= p * np.log2(p)
    return float(entropy)


def _detect_lookalike_chars(url: str) -> bool:
    """Check if URL contains homoglyph/lookalike characters"""
    for char in (url or ""):
        if char in LOOKALIKE_CHARS:
            return True
    return False


def _check_typosquat(url_str: str) -> bool:
    """Check for typosquatting patterns"""
    host = (urlparse(_ensure_scheme(url_str)).hostname or "").lower()
    sld = host.split(".")[-2] if "." in host else host
    clean_sld = _normalize_brand(sld)
    
    if not clean_sld:
        return False
    
    best_similarity = max(
        SequenceMatcher(None, clean_sld, _normalize_brand(b)).ratio()
        for b in BRAND_NAMES
    )
    
    has_digits = bool(re.search(r"\d", sld))
    has_hyphen = "-" in sld
    is_official = any(host.endswith(f"{_normalize_brand(b)}.com") for b in BRAND_NAMES)
    
    return (best_similarity >= 0.90) and (has_digits or has_hyphen) and (not is_official)


def _count_suspicious_features(url_str: str) -> Tuple[int, List[str]]:
    """Count suspicious indicators in URL"""
    count = 0
    features = []
    
    # Suspicious keywords
    for kw in SUSPICIOUS_KEYWORDS:
        if kw in url_str.lower():
            count += 1
            features.append(f"keyword:{kw}")
    
    # IP address
    if re.search(r"(?:\d{1,3}\.){3}\d{1,3}", url_str):
        count += 1
        features.append("ip_address")
    
    # Excessive length
    if len(url_str) > 75:
        count += 1
        features.append("long_url")
    
    # Many subdomains
    host = (urlparse(_ensure_scheme(url_str)).hostname or "").lower()
    if host.count('.') > 3:
        count += 1
        features.append("many_subdomains")
    
    return count, features


def _calibrate_confidence(
    is_phishing: bool,
    raw_proba: float,
    url_str: str,
    detection_method: str
) -> Dict[str, Any]:
    """
    Universal confidence calibration function.
    Returns scores in 50-85% range for both phishing and legitimate URLs.
    """
    
    # === PHISHING DETECTION ===
    if is_phishing:
        if detection_method == "lookalike":
            # Lookalike: 68-78%
            calibrated = 0.68 + (min(raw_proba, 1.0) * 0.10)
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": "MEDIUM-HIGH",
                "detection_method": "Homoglyph/Lookalike Character",
                "explanation": "URL contains visually deceptive characters (e.g., Cyrillic 'а' vs ASCII 'a')"
            }
        
        elif detection_method == "typosquat":
            # Typosquatting: 63-75%
            calibrated = 0.63 + (min(raw_proba, 1.0) * 0.12)
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": "MEDIUM",
                "detection_method": "Brand Typosquatting",
                "explanation": "Domain mimics a popular brand with suspicious modifications"
            }
        
        elif detection_method == "csv_match":
            # Known phishing URL: 78-85%
            calibrated = 0.78 + (min(raw_proba, 1.0) * 0.07)
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": "HIGH",
                "detection_method": "Known Phishing Database",
                "explanation": "URL matches verified phishing database"
            }
        
        elif detection_method == "host_match":
            # Known malicious host: 75-83%
            calibrated = 0.75 + (min(raw_proba, 1.0) * 0.08)
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": "HIGH",
                "detection_method": "Malicious Host Database",
                "explanation": "Domain listed in malicious hosts database"
            }
        
        else:  # ML model detection
            susp_count, susp_features = _count_suspicious_features(url_str)
            
            if raw_proba >= 0.90 and susp_count >= 3:
                # Very confident + multiple indicators: 78-85%
                calibrated = 0.78 + (min(raw_proba, 1.0) * 0.07)
                confidence = "HIGH"
            elif raw_proba >= 0.75:
                # Medium-high confidence: 70-80%
                calibrated = 0.70 + (min(raw_proba, 1.0) * 0.10)
                confidence = "MEDIUM-HIGH"
            elif raw_proba >= 0.60:
                # Medium confidence: 62-75%
                calibrated = 0.62 + (min(raw_proba, 1.0) * 0.13)
                confidence = "MEDIUM"
            else:
                # Lower confidence: 55-68%
                calibrated = 0.55 + (min(raw_proba, 1.0) * 0.13)
                confidence = "LOW-MEDIUM"
            
            feature_text = f" ({susp_count} indicators: {', '.join(susp_features[:3])})" if susp_features else ""
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": confidence,
                "detection_method": f"ML Analysis{feature_text}",
                "explanation": "Random Forest model detected phishing patterns in URL structure"
            }
    
    # === LEGITIMATE DETECTION ===
    else:
        if detection_method in ["csv_match", "host_match"]:
            # Known legitimate: 70-80%
            calibrated = 0.70 + (min(1.0 - raw_proba, 1.0) * 0.10)
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": "HIGH",
                "detection_method": "Verified Legitimate Database",
                "explanation": "URL verified as legitimate in trusted database"
            }
        else:
            # ML model says legitimate: 72-82%
            legit_confidence = 1.0 - raw_proba
            calibrated = 0.72 + (min(legit_confidence, 1.0) * 0.10)
            return {
                "calibrated_proba": float(calibrated),
                "confidence_level": "HIGH" if legit_confidence > 0.8 else "MEDIUM-HIGH",
                "detection_method": "ML Analysis",
                "explanation": "Random Forest model detected legitimate URL patterns"
            }


def _engineer_features(urls: List[str], feature_cols: List[str]) -> pd.DataFrame:
    """Feature engineering matching notebook implementation"""
    s = pd.Series(urls, dtype=str)
    out = pd.DataFrame()

    # Basic features
    out["url_len"] = s.str.len().fillna(0)
    out["count_dot"] = s.str.count(r"\.")
    out["count_hyphen"] = s.str.count("-")
    out["count_digit"] = s.str.count(r"\d")
    out["count_at"] = s.str.count("@")
    out["count_qmark"] = s.str.count(r"\?")
    out["count_eq"] = s.str.count("=")
    out["count_slash"] = s.str.count("/")
    out["digit_ratio"] = (out["count_digit"] / out["url_len"].replace(0, np.nan)).fillna(0)
    out["has_ip"] = s.str.contains(r"(?:\d{1,3}\.){3}\d{1,3}").astype(int)
    
    for tok in SUSPICIOUS_KEYWORDS:
        out[f"has_{tok}"] = s.str.contains(tok, case=False, regex=False).astype(int)
    
    out["starts_https"] = s.str.startswith("https").astype(int)
    out["ends_with_exe"] = s.str.endswith(".exe").astype(int)
    out["ends_with_zip"] = s.str.endswith(".zip").astype(int)

    # Host/domain features
    hosts = s.apply(lambda x: (urlparse(_ensure_scheme(x)).hostname or "").lower())
    out["host_len"] = hosts.str.len().fillna(0)
    
    label_counts = hosts.str.count(r"\.") + 1
    out["subdomain_count"] = (label_counts - 2).clip(lower=0).fillna(0)

    parts_series = hosts.str.split(".")
    tld_series = parts_series.apply(lambda p: p[-1] if len(p) >= 1 else "")
    sld_series = parts_series.apply(lambda p: p[-2] if len(p) >= 2 else "")

    out["tld_suspicious"] = tld_series.apply(lambda t: 1 if t.lower() in SUSPICIOUS_TLDS else 0)
    out["has_punycode"] = hosts.str.contains("xn--").astype(int)
    out["sld_len"] = sld_series.str.len().fillna(0)
    
    def _ratio_digits(txt: str) -> float:
        if not txt:
            return 0.0
        digits = sum(c.isdigit() for c in txt)
        return float(digits) / float(len(txt))
    
    out["sld_digit_ratio"] = sld_series.apply(_ratio_digits)
    out["sld_entropy"] = sld_series.apply(_shannon_entropy)

    # Brand similarity
    def _max_brand_similarity(host: str) -> float:
        if not host:
            return 0.0
        sld = host.split(".")[-2] if "." in host else host
        similarities = []
        for brand in BRAND_NAMES:
            similarities.append(SequenceMatcher(None, host, brand).ratio())
            similarities.append(SequenceMatcher(None, sld, brand).ratio())
        return max(similarities) if similarities else 0.0

    out["max_brand_sim"] = hosts.apply(_max_brand_similarity)
    out["like_facebook"] = hosts.apply(
        lambda h: 1 if SequenceMatcher(None, h.split(".")[-2] if "." in h else h, "facebook").ratio() >= 0.82 else 0
    )
    out["has_lookalike_chars"] = s.apply(lambda u: 1 if _detect_lookalike_chars(u) else 0)

    return out.reindex(columns=feature_cols, fill_value=0)


def _load_url_model():
    """Load and memoize the URL model bundle from local path or Hugging Face Hub."""
    global _url_bundle
    if _url_bundle is None:
        with _url_lock:
            if _url_bundle is None:
                local_path = os.path.join(os.getcwd(), URL_FILENAME)
                if os.path.exists(local_path):
                    _url_bundle = joblib.load(local_path)
                else:
                    model_path = hf_hub_download(
                        repo_id=URL_REPO,
                        filename=URL_FILENAME,
                        repo_type=URL_REPO_TYPE,
                        cache_dir=CACHE_DIR,
                    )
                    _url_bundle = joblib.load(model_path)


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
def root():
    """Health endpoint with service metadata and enabled modules."""
    return {
        "status": "ok",
        "service": "PhishWatch Pro API",
        "version": "3.1.0",
        "modules": {
            "module_2_text_preprocessing": NLTK_AVAILABLE,
            "module_4_url_analyzer": True
        },
        "confidence_range": "50-85% (calibrated for both phishing and legitimate)"
    }


@app.post("/preprocess-text")
def preprocess_text(payload: PreprocessTextPayload):
    """Module 2: Text Preprocessing with calibrated confidence (50-85%)"""
    if not NLTK_AVAILABLE:
        return JSONResponse(
            status_code=503,
            content={"error": "NLP libraries not available. Install: pip install nltk textblob"}
        )
    
    try:
        text = (payload.text or "").strip()
        if not text:
            return JSONResponse(status_code=400, content={"error": "Empty text"})

        tokens = word_tokenize(text.lower())
        tokens_filtered = [
            t for t in tokens 
            if t.isalnum() and (not payload.remove_stopwords or t not in stop_words)
        ]

        stemmed_tokens = [stemmer.stem(t) for t in tokens_filtered] if payload.include_stemming else []
        lemmatized_tokens = [lemmatizer.lemmatize(t) for t in tokens_filtered] if payload.include_lemmatization else []

        sentiment_data = {}
        phishing_indicators = {}
        
        if payload.include_sentiment:
            blob = TextBlob(text)
            sentiment_data = {
                "polarity": float(blob.sentiment.polarity),
                "subjectivity": float(blob.sentiment.subjectivity),
                "classification": (
                    "positive" if blob.sentiment.polarity > 0.1 else
                    "negative" if blob.sentiment.polarity < -0.1 else "neutral"
                )
            }

            text_lower = text.lower()
            detected_keywords = [kw for kw in PHISHING_KEYWORDS if kw in text_lower]
            keyword_density = len(detected_keywords) / max(len(tokens_filtered), 1)
            
            urgency_detected = any(
                kw in detected_keywords 
                for kw in ['urgent', 'expire', 'act now', 'suspended', 'locked', 'warning', 'alert']
            )
            emotional_appeal = blob.sentiment.subjectivity > 0.6
            
            # Calibrated confidence: 50-82%
            base_score = 0.50 + (len(detected_keywords) * 0.08) + (keyword_density * 0.15)
            if urgency_detected:
                base_score += 0.12
            if emotional_appeal:
                base_score += 0.08
            base_score = min(0.82, base_score)
            
            phishing_indicators = {
                "suspicious_keywords": detected_keywords,
                "keyword_count": len(detected_keywords),
                "keyword_density": float(keyword_density),
                "urgency_detected": urgency_detected,
                "emotional_appeal": emotional_appeal,
                "risk_score": float(base_score),
                "confidence_level": (
                    "HIGH" if base_score >= 0.72 else
                    "MEDIUM" if base_score >= 0.58 else "LOW"
                ),
                "risk_level": (
                    "HIGH" if len(detected_keywords) >= 3 or urgency_detected else
                    "MEDIUM" if len(detected_keywords) >= 1 else "LOW"
                )
            }

        return {
            "module": "text_preprocessing",
            "original_text": text,
            "tokens": tokens[:100],
            "token_count": len(tokens),
            "filtered_tokens": tokens_filtered[:100],
            "filtered_token_count": len(tokens_filtered),
            "cleaned_text": " ".join(tokens_filtered),
            "stemmed_text": " ".join(stemmed_tokens) if stemmed_tokens else None,
            "lemmatized_text": " ".join(lemmatized_tokens) if lemmatized_tokens else None,
            "sentiment": sentiment_data if sentiment_data else None,
            "phishing_indicators": phishing_indicators if phishing_indicators else None,
            "preprocessing_applied": {
                "tokenization": True,
                "stopword_removal": payload.remove_stopwords,
                "stemming": payload.include_stemming,
                "lemmatization": payload.include_lemmatization,
                "sentiment_analysis": payload.include_sentiment
            }
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


@app.post("/predict-url")
def predict_url(payload: PredictUrlPayload):
    """Module 4: URL Analyzer with calibrated confidence (both phishing and legit: 50-85%)"""
    try:
        _load_url_model()

        phishy_list = _read_urls_from_csv(AUTOCALIB_PHISHY_CSV)
        legit_list = _read_urls_from_csv(AUTOCALIB_LEGIT_CSV)
        host_map = _read_hosts_from_csv(KNOWN_HOSTS_CSV)

        bundle = _url_bundle
        if not isinstance(bundle, dict) or "model" not in bundle:
            raise RuntimeError("Invalid model bundle")

        model = bundle["model"]
        feature_cols: List[str] = bundle.get("feature_cols") or []
        url_col: str = bundle.get("url_col") or "url"
        model_type: str = bundle.get("model_type") or ""

        raw_input = (payload.url or "").strip()
        url_str = _sanitize_input_url(raw_input)
        if not url_str:
            return JSONResponse(status_code=400, content={"error": "Empty url"})

        phish_is_positive = True if URL_POSITIVE_CLASS_ENV == "" else (URL_POSITIVE_CLASS_ENV == "PHISH")
        norm_url = _normalize_url_string(url_str)
        phishy_set = {_normalize_url_string(u) for u in phishy_list}
        legit_set = {_normalize_url_string(u) for u in legit_list}

        # CSV match
        if norm_url in phishy_set or norm_url in legit_set:
            is_phishing = norm_url in phishy_set
            raw_proba = 0.99 if is_phishing else 0.01
            calibration = _calibrate_confidence(is_phishing, raw_proba, url_str, "csv_match")
            
            label = "PHISH" if is_phishing else "LEGIT"
            phish_proba = calibration["calibrated_proba"] if is_phishing else (1.0 - calibration["calibrated_proba"])
            predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
            score = phish_proba if is_phishing else calibration["calibrated_proba"]
            
            return {
                "module": "url_analyzer",
                "label": label,
                "predicted_label": int(predicted_label),
                "score": float(score),
                "phishing_probability": float(phish_proba) if is_phishing else float(1.0 - score),
                "confidence_level": calibration["confidence_level"],
                "detection_method": calibration["detection_method"],
                "explanation": calibration["explanation"],
                "backend": str(model_type),
                "threshold": 0.5,
                "url_col": url_col,
            }

        # Host match
        host = (urlparse(_ensure_scheme(url_str)).hostname or "").lower()
        if host and host_map:
            for h, lbl in host_map.items():
                if _host_matches_any(host, [h]):
                    is_phishing = (lbl == "PHISH")
                    raw_proba = 0.99 if is_phishing else 0.01
                    calibration = _calibrate_confidence(is_phishing, raw_proba, url_str, "host_match")
                    
                    label = lbl
                    phish_proba = calibration["calibrated_proba"] if is_phishing else (1.0 - calibration["calibrated_proba"])
                    predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
                    score = phish_proba if is_phishing else calibration["calibrated_proba"]
                    
                    return {
                        "module": "url_analyzer",
                        "label": label,
                        "predicted_label": int(predicted_label),
                        "score": float(score),
                        "phishing_probability": float(phish_proba) if is_phishing else float(1.0 - score),
                        "confidence_level": calibration["confidence_level"],
                        "detection_method": calibration["detection_method"],
                        "explanation": calibration["explanation"],
                        "backend": str(model_type),
                        "threshold": 0.5,
                        "url_col": url_col,
                    }

        # Lookalike check
        if _detect_lookalike_chars(url_str):
            calibration = _calibrate_confidence(True, 0.95, url_str, "lookalike")
            return {
                "module": "url_analyzer",
                "label": "PHISH",
                "predicted_label": 1 if phish_is_positive else 0,
                "score": float(calibration["calibrated_proba"]),
                "phishing_probability": float(calibration["calibrated_proba"]),
                "confidence_level": calibration["confidence_level"],
                "detection_method": calibration["detection_method"],
                "explanation": calibration["explanation"],
                "backend": "heuristic",
                "threshold": 0.5,
                "url_col": url_col,
            }

        # Typosquat check
        if _check_typosquat(url_str):
            calibration = _calibrate_confidence(True, 0.90, url_str, "typosquat")
            return {
                "module": "url_analyzer",
                "label": "PHISH",
                "predicted_label": 1 if phish_is_positive else 0,
                "score": float(calibration["calibrated_proba"]),
                "phishing_probability": float(calibration["calibrated_proba"]),
                "confidence_level": calibration["confidence_level"],
                "detection_method": calibration["detection_method"],
                "explanation": calibration["explanation"],
                "backend": "heuristic",
                "threshold": 0.5,
                "url_col": url_col,
            }

        # ML model inference
        feats = _engineer_features([url_str], feature_cols)
        
        if model_type == "xgboost_bst":
            if xgb is None:
                raise RuntimeError("xgboost not installed")
            dmat = xgb.DMatrix(feats)
            raw_p_class1 = float(model.predict(dmat)[0])
        elif hasattr(model, "predict_proba"):
            raw_p_class1 = float(model.predict_proba(feats)[:, 1][0])
        else:
            pred = model.predict(feats)[0]
            raw_p_class1 = 1.0 if int(pred) == 1 else 0.0

        raw_phish_proba = raw_p_class1 if phish_is_positive else (1.0 - raw_p_class1)
        is_phishing = raw_phish_proba >= 0.5
        
        calibration = _calibrate_confidence(is_phishing, raw_phish_proba, url_str, "ml_model")
        
        label = "PHISH" if is_phishing else "LEGIT"
        predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
        
        if is_phishing:
            phish_proba = calibration["calibrated_proba"]
            score = phish_proba
        else:
            legit_confidence = calibration["calibrated_proba"]
            phish_proba = 1.0 - legit_confidence
            score = legit_confidence

        return {
            "module": "url_analyzer",
            "label": label,
            "predicted_label": int(predicted_label),
            "score": float(score),
            "phishing_probability": float(phish_proba),
            "confidence_level": calibration["confidence_level"],
            "detection_method": calibration["detection_method"],
            "explanation": calibration["explanation"],
            "backend": str(model_type),
            "threshold": 0.5,
            "url_col": url_col,
        }
        
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})