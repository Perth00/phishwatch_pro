import os
import csv
import re
import threading
from typing import Optional, List, Dict, Any
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


# Environment defaults suitable for HF Spaces
os.environ.setdefault("HOME", "/data")
os.environ.setdefault("XDG_CACHE_HOME", "/data/.cache")
os.environ.setdefault("HF_HOME", "/data/.cache")
os.environ.setdefault("TRANSFORMERS_CACHE", "/data/.cache")
os.environ.setdefault("TORCH_HOME", "/data/.cache")


# Config
URL_REPO = os.environ.get(
    "HF_URL_MODEL_ID",
    os.environ.get("URL_REPO", "Perth0603/Random-Forest-Model-for-PhishingDetection"),
)
URL_REPO_TYPE = os.environ.get("HF_URL_REPO_TYPE", os.environ.get("URL_REPO_TYPE", "model"))
URL_FILENAME = os.environ.get("HF_URL_FILENAME", os.environ.get("URL_FILENAME", "rf_url_phishing_xgboost_bst.joblib"))
CACHE_DIR = os.environ.get("HF_CACHE_DIR", "/data/.cache")
os.makedirs(CACHE_DIR, exist_ok=True)

# Polarity override: "PHISH" or "LEGIT"; empty means default (class 1 = PHISH)
URL_POSITIVE_CLASS_ENV = os.environ.get("URL_POSITIVE_CLASS", "").strip().upper()

# CSV configuration (defaults to files in same directory)
BASE_DIR = os.path.dirname(__file__)
AUTOCALIB_PHISHY_CSV = os.environ.get("AUTOCALIB_PHISHY_CSV", os.path.join(BASE_DIR, "autocalib_phishy.csv"))
AUTOCALIB_LEGIT_CSV = os.environ.get("AUTOCALIB_LEGIT_CSV", os.path.join(BASE_DIR, "autocalib_legit.csv"))
KNOWN_HOSTS_CSV = os.environ.get("KNOWN_HOSTS_CSV", os.path.join(BASE_DIR, "known_hosts.csv"))


app = FastAPI(title="PhishWatch URL API", version="2.0.0")


class PredictUrlPayload(BaseModel):
    url: str


_url_bundle: Optional[Dict[str, Any]] = None
_url_lock = threading.Lock()


def _normalize_host(value: str) -> str:
    v = value.strip().lower()
    if v.startswith("www."):
        v = v[4:]
    return v


def _host_matches_any(host: str, known: List[str]) -> bool:
    base = _normalize_host(host)
    for item in known:
        k = _normalize_host(item)
        if base == k or base.endswith("." + k):
            return True
    return False


_URL_EXTRACT_RE = re.compile(r"(https?://[^\s<>\"'\)\]]+)", re.IGNORECASE)

def _sanitize_input_url(text: str) -> str:
    v = (text or "").strip()
    if v.startswith("@"):
        v = v.lstrip("@").strip()
    m = _URL_EXTRACT_RE.search(v)
    if m:
        v = m.group(1)
    v = v.strip("<>[]()")
    return v

_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+\-.]*://")
def _ensure_scheme(u: str) -> str:
    u = (u or "").strip()
    return u if _SCHEME_RE.match(u) else ("http://" + u)

def _read_urls_from_csv(path: str) -> List[str]:
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
                f2 = csv.reader(f)
                for row in f2:
                    if not row:
                        continue
                    val = str(row[0]).strip()
                    if val.lower() == "url":
                        continue
                    if val:
                        urls.append(val)
    except FileNotFoundError:
        pass
    except Exception as e:
        print(f"[csv] failed reading URLs from {path}: {e}")
    return urls


def _read_hosts_from_csv(path: str) -> Dict[str, str]:
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


def _engineer_features(urls: List[str], feature_cols: List[str]) -> pd.DataFrame:
    s = pd.Series(urls, dtype=str)
    out = pd.DataFrame()

    # Base URL-wide counts used by older models
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
    for tok in ["login", "verify", "secure", "update", "bank", "pay", "account", "webscr"]:
        out[f"has_{tok}"] = s.str.contains(tok, case=False, regex=False).astype(int)
    out["starts_https"] = s.str.startswith("https").astype(int)
    out["ends_with_exe"] = s.str.endswith(".exe").astype(int)
    out["ends_with_zip"] = s.str.endswith(".zip").astype(int)

    # Host/SLD/TLD derived features used by newer models
    hosts = s.apply(lambda x: (urlparse(_ensure_scheme(x)).hostname or "").lower())
    out["host_len"] = hosts.str.len().fillna(0)

    # Subdomain count: number of labels minus 2 (for sld.tld); never below 0
    label_counts = hosts.str.count(r"\.") + 1
    sub_count = (label_counts - 2).clip(lower=0)
    out["subdomain_count"] = sub_count.fillna(0)

    # TLD and SLD extraction (simple heuristic; handles common cases)
    parts_series = hosts.str.split(".")
    tld_series = parts_series.apply(lambda p: p[-1] if len(p) >= 1 else "")
    sld_series = parts_series.apply(lambda p: p[-2] if len(p) >= 2 else "")

    # Suspicious TLD flag (expand as needed)
    suspicious_tlds = {
        "tk", "ml", "ga", "cf", "gq", "xyz", "top", "buzz", "icu",
        "fit", "rest", "work", "click", "country", "zip"
    }
    out["tld_suspicious"] = tld_series.apply(lambda t: 1 if t.lower() in suspicious_tlds else 0)

    # Punycode indicator
    out["has_punycode"] = hosts.str.contains("xn--").astype(int)

    # SLD stats
    out["sld_len"] = sld_series.str.len().fillna(0)
    def _ratio_digits(txt: str) -> float:
        txt = txt or ""
        if not txt:
            return 0.0
        digits = sum(c.isdigit() for c in txt)
        return float(digits) / float(len(txt))
    out["sld_digit_ratio"] = sld_series.apply(_ratio_digits)

    def _shannon_entropy(txt: str) -> float:
        txt = txt or ""
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
    out["sld_entropy"] = sld_series.apply(_shannon_entropy)

    # Brand similarity features (lightweight; stdlib only)
    common_brands = [
        "facebook", "google", "youtube", "apple", "microsoft",
        "paypal", "amazon", "netflix", "instagram", "whatsapp",
        "tiktok", "twitter", "telegram", "linkedin", "bank", "login"
    ]

    def _max_brand_similarity(host: str) -> float:
        host = host or ""
        if not host:
            return 0.0
        # Compare against host and sld specifically
        best = 0.0
        sld_local = host.split(".")[-2] if "." in host else host
        for brand in common_brands:
            best = max(
                best,
                SequenceMatcher(None, host, brand).ratio(),
                SequenceMatcher(None, sld_local, brand).ratio(),
            )
        return float(best)

    def _like_brand(host: str, brand: str, threshold: float = 0.82) -> int:
        h = host or ""
        if not h:
            return 0
        if brand in h:
            return 1
        sld_local = h.split(".")[-2] if "." in h else h
        score = max(
            SequenceMatcher(None, h, brand).ratio(),
            SequenceMatcher(None, sld_local, brand).ratio(),
        )
        return 1 if score >= threshold else 0

    out["max_brand_sim"] = hosts.apply(_max_brand_similarity)
    out["like_facebook"] = hosts.apply(lambda h: _like_brand(h, "facebook"))

    # Lookalike/homoglyph detection: unusual Unicode symbols that resemble ASCII letters
    # Examples: Cyrillic а (U+0430) looks like 'a', Greek α (U+03B1) looks like 'a', etc.
    def _detect_lookalike_chars(url: str) -> int:
        """
        Detects if URL contains Unicode characters that visually resemble ASCII letters.
        Common lookalikes used in phishing:
        - Cyrillic: а, е, о, р, с, х, у, ч, ы, ь (look like a,e,o,p,c,x,y,4,b,b)
        - Greek: α, ο (look like a, o)
        - Latin Extended: ɑ, ɢ, ᴅ, ɡ, ɪ, ɴ, ɪ (look like a,G,D,g,i,N,I)
        """
        url_str = url or ""
        
        # Cyrillic characters that look like ASCII letters
        lookalikes_cyrillic = {
            'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x',
            'у': 'y', 'ч': '4', 'ы': 'b', 'ь': 'b', 'і': 'i', 'ї': 'yi',
            'ґ': 'g', 'ė': 'e', 'ń': 'n', 'ș': 's', 'ț': 't'
        }
        
        # Greek characters that look like ASCII letters
        lookalikes_greek = {
            'α': 'a', 'ο': 'o', 'ν': 'v', 'τ': 't', 'ρ': 'p'
        }
        
        # Latin Extended lookalikes
        lookalikes_latin = {
            'ɑ': 'a', 'ɢ': 'g', 'ᴅ': 'd', 'ɡ': 'g', 'ɪ': 'i',
            'ɴ': 'n', 'ᴘ': 'p', 'ᴠ': 'v', 'ᴡ': 'w', 'ɨ': 'i'
        }
        
        all_lookalikes = {**lookalikes_cyrillic, **lookalikes_greek, **lookalikes_latin}
        
        for char in url_str:
            if char in all_lookalikes:
                return 1
        return 0
    
    out["has_lookalike_chars"] = s.apply(_detect_lookalike_chars)

    # Return columns in the exact order expected by the model; fill any
    # still-missing engineered columns with zeros to stay robust across
    # model updates.
    return out.reindex(columns=feature_cols, fill_value=0)


def _load_url_model():
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


def _normalize_url_string(url: str) -> str:
    return (url or "").strip().rstrip("/")


@app.get("/")
def root():
    return {"status": "ok", "backend": "url-only"}


@app.post("/predict-url")
def predict_url(payload: PredictUrlPayload):
    try:
        _load_url_model()

        # Load CSVs on every request (keeps behavior in sync without code edits)
        phishy_list = _read_urls_from_csv(AUTOCALIB_PHISHY_CSV)
        legit_list = _read_urls_from_csv(AUTOCALIB_LEGIT_CSV)
        host_map = _read_hosts_from_csv(KNOWN_HOSTS_CSV)

        bundle = _url_bundle
        if not isinstance(bundle, dict) or "model" not in bundle:
            raise RuntimeError("Loaded URL artifact is not a bundle dict with 'model'.")

        model = bundle["model"]
        feature_cols: List[str] = bundle.get("feature_cols") or []
        url_col: str = bundle.get("url_col") or "url"
        model_type: str = bundle.get("model_type") or ""

        raw_input = (payload.url or "").strip()
        url_str = _sanitize_input_url(raw_input)
        if not url_str:
            return JSONResponse(status_code=400, content={"error": "Empty url"})

        # URL-level override via CSV lists (normalized exact match, ignoring trailing slash)
        norm_url = _normalize_url_string(url_str)
        phishy_set = { _normalize_url_string(u) for u in phishy_list }
        legit_set = { _normalize_url_string(u) for u in legit_list }

        if norm_url in phishy_set or norm_url in legit_set:
            phish_is_positive = True if URL_POSITIVE_CLASS_ENV == "" else (URL_POSITIVE_CLASS_ENV == "PHISH")
            label = "PHISH" if norm_url in phishy_set else "LEGIT"
            predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
            phish_proba = 0.99 if label == "PHISH" else 0.01
            score = phish_proba if label == "PHISH" else (1.0 - phish_proba)
            return {
                "label": label,
                "predicted_label": int(predicted_label),
                "score": float(score),
                "phishing_probability": float(phish_proba),
                "backend": str(model_type),
                "threshold": 0.5,
                "url_col": url_col,
                "override": {"reason": "csv_url_match"},
            }

        # Known-host override (suffix match)
        host = (urlparse(_ensure_scheme(url_str)).hostname or "").lower()
        if host and host_map:
            for h, lbl in host_map.items():
                if _host_matches_any(host, [h]):
                    phish_is_positive = True if URL_POSITIVE_CLASS_ENV == "" else (URL_POSITIVE_CLASS_ENV == "PHISH")
                    label = lbl
                    predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
                    phish_proba = 0.99 if label == "PHISH" else 0.01
                    score = phish_proba if label == "PHISH" else (1.0 - phish_proba)
                    return {
                        "label": label,
                        "predicted_label": int(predicted_label),
                        "score": float(score),
                        "phishing_probability": float(phish_proba),
                        "backend": str(model_type),
                        "threshold": 0.5,
                        "url_col": url_col,
                    }

        # Lookalike character guard: detect homoglyph/lookalike attacks
        try:
            # Cyrillic characters that look like ASCII letters
            lookalikes_cyrillic = {
                'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x',
                'у': 'y', 'ч': '4', 'ы': 'b', 'ь': 'b', 'і': 'i', 'ї': 'yi',
                'ґ': 'g', 'ė': 'e', 'ń': 'n', 'ș': 's', 'ț': 't'
            }
            
            # Greek characters that look like ASCII letters
            lookalikes_greek = {
                'α': 'a', 'ο': 'o', 'ν': 'v', 'τ': 't', 'ρ': 'p'
            }
            
            # Latin Extended lookalikes
            lookalikes_latin = {
                'ɑ': 'a', 'ɢ': 'g', 'ᴅ': 'd', 'ɡ': 'g', 'ɪ': 'i',
                'ɴ': 'n', 'ᴘ': 'p', 'ᴠ': 'v', 'ᴡ': 'w', 'ɨ': 'i'
            }
            
            all_lookalikes = {**lookalikes_cyrillic, **lookalikes_greek, **lookalikes_latin}
            
            for char in url_str:
                if char in all_lookalikes:
                    phish_is_positive = True if URL_POSITIVE_CLASS_ENV == "" else (URL_POSITIVE_CLASS_ENV == "PHISH")
                    label = "PHISH"
                    predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
                    phish_proba = 0.95
                    score = phish_proba
                    return {
                        "label": label,
                        "predicted_label": int(predicted_label),
                        "score": float(score),
                        "phishing_probability": float(phish_proba),
                        "backend": "lookalike_guard",
                        "threshold": 0.5,
                        "url_col": url_col,
                        "rule": "lookalike_character_detected",
                    }
        except Exception:
            pass

        # Typosquat guard: mirror notebook fallback logic.
        try:
            s_host = (urlparse(_ensure_scheme(url_str)).hostname or "").lower()
            s_sld = s_host.split(".")[-2] if "." in s_host else s_host
            def _normalize_brand(s: str) -> str:
                return re.sub(r"[^a-z]", "", s.lower())
            s_clean = _normalize_brand(s_sld)
            brands = [
                "facebook","linkedin","paypal","google","amazon","apple",
                "microsoft","instagram","netflix","twitter","whatsapp"
            ]
            def _sim(a: str, b: str) -> float:
                try:
                    from rapidfuzz import fuzz  # type: ignore
                    return float(fuzz.ratio(a, b)) / 100.0
                except Exception:
                    from difflib import SequenceMatcher
                    return SequenceMatcher(None, a, b).ratio()
            if s_clean:
                best = 0.0
                for b in brands:
                    best = max(best, _sim(s_clean, _normalize_brand(b)))
                has_digits = bool(re.search(r"\d", s_sld))
                has_hyphen = ("-" in s_sld)
                is_official = any(s_host.endswith(f"{_normalize_brand(b)}.com") for b in brands)
                if (best >= 0.90) and (has_digits or has_hyphen) and (not is_official):
                    phish_is_positive = True if URL_POSITIVE_CLASS_ENV == "" else (URL_POSITIVE_CLASS_ENV == "PHISH")
                    label = "PHISH"
                    predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
                    phish_proba = 0.90
                    score = phish_proba
                    return {
                        "label": label,
                        "predicted_label": int(predicted_label),
                        "score": float(score),
                        "phishing_probability": float(phish_proba),
                        "backend": "typosquat_guard",
                        "threshold": 0.5,
                        "url_col": url_col,
                        "rule": "typosquat_guard",
                    }
        except Exception:
            pass

        # Mirror inference flow for probability of class 1
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

        # Polarity: strictly env or default (class1==PHISH)
        phish_is_positive = True if URL_POSITIVE_CLASS_ENV == "" else (URL_POSITIVE_CLASS_ENV == "PHISH")

        phish_proba = raw_p_class1 if phish_is_positive else (1.0 - raw_p_class1)
        label = "PHISH" if phish_proba >= 0.5 else "LEGIT"
        predicted_label = 1 if ((label == "PHISH") == phish_is_positive) else 0
        score = phish_proba if label == "PHISH" else (1.0 - phish_proba)

        return {
            "label": label,
            "predicted_label": int(predicted_label),
            "score": float(score),
            "phishing_probability": float(phish_proba),
            "backend": str(model_type),
            "threshold": 0.5,
            "url_col": url_col,
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


