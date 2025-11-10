import os
from typing import List, Optional, Dict
import re

import torch
import torch.nn.functional as F
import nltk
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from nltk.corpus import stopwords
from nltk.stem import PorterStemmer, WordNetLemmatizer
from nltk.tokenize import word_tokenize
from textblob import TextBlob

# Download NLTK data
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt')
    nltk.download('stopwords')
    nltk.download('wordnet')

MODEL_ID = "Perth0603/phishing-email-mobilebert"

app = FastAPI(title="Phishing Text Classifier with Preprocessing", version="1.0.0")

# Confidence adjustment settings
BASE_CONFIDENCE_MIN = 0.55  # Minimum confidence (55%)
BASE_CONFIDENCE_MAX = 0.85  # Maximum confidence (85%)


# ============================================================================
# TEXT PREPROCESSING CLASS
# ============================================================================
class TextPreprocessor:
    """NLP preprocessing for analysis and feature extraction"""
    
    def __init__(self):
        self.stemmer = PorterStemmer()
        self.lemmatizer = WordNetLemmatizer()
        self.stop_words = set(stopwords.words('english'))
    
    def tokenize(self, text: str) -> List[str]:
        """Break text into tokens"""
        return word_tokenize(text.lower())
    
    def remove_stopwords(self, tokens: List[str]) -> List[str]:
        """Remove common stop words"""
        return [token for token in tokens if token.isalnum() and token not in self.stop_words]
    
    def stem(self, tokens: List[str]) -> List[str]:
        """Reduce tokens to stems"""
        return [self.stemmer.stem(token) for token in tokens]
    
    def lemmatize(self, tokens: List[str]) -> List[str]:
        """Reduce tokens to lemmas"""
        return [self.lemmatizer.lemmatize(token) for token in tokens]
    
    def analyze_phishing_indicators(self, text: str) -> Dict:
        """Comprehensive phishing indicator analysis"""
        indicators = {
            "urgent_words": bool(re.search(
                r'\b(urgent|immediately|immediate|act now|right now|asap|verify now|'
                r'confirm now|update now|click now|respond now|expire soon|expiring|'
                r'time sensitive|limited time|hurry|quick|fast|today only)\b', 
                text, re.IGNORECASE
            )),
            "threat_words": bool(re.search(
                r'\b(suspend|suspended|lock|locked|block|blocked|disable|disabled|'
                r'restrict|restricted|terminate|terminated|cancel|cancelled|close|closed|'
                r'freeze|frozen|ban|banned|deactivate|deactivated|remove|removed)\b', 
                text, re.IGNORECASE
            )),
            "action_words": bool(re.search(
                r'\b(click here|click now|click below|click this|verify|confirm|update|'
                r'download|install|open attachment|validate|authenticate|reset password|'
                r'change password|provide|submit|enter|fill out|complete)\b', 
                text, re.IGNORECASE
            )),
            "financial_words": bool(re.search(
                r'\b(payment|pay|money|credit card|bank account|billing|invoice|refund|'
                r'tax|irs|paypal|transaction|transfer|wire|deposit|account number|'
                r'social security|ssn|card number|cvv|pin)\b', 
                text, re.IGNORECASE
            )),
            "authority_impersonation": bool(re.search(
                r'\b(paypal|amazon|microsoft|apple|google|facebook|instagram|netflix|'
                r'ebay|irs|fbi|cia|government|police|bank of america|chase|wells fargo|'
                r'citibank|security team|support team|admin|administrator)\b', 
                text, re.IGNORECASE
            )),
            "suspicious_urls": bool(re.search(r'http[s]?://|www\.', text)),
            "suspicious_domain": bool(re.search(
                r'\b(bit\.ly|tinyurl|goo\.gl|short|link|redirect|verify-|secure-|account-|'
                r'update-|login-|signin-)\w+\.(com|net|org|info|xyz|tk|ml|ga|cf|gq)', 
                text, re.IGNORECASE
            )),
            "generic_greeting": bool(re.search(
                r'^(dear (customer|user|member|client|sir|madam)|hello|hi there|greetings)\b', 
                text, re.IGNORECASE
            )),
            "poor_grammar": self._detect_poor_grammar(text),
            "excessive_punctuation": bool(re.search(r'[!?]{2,}', text)),
            "all_caps": len(re.findall(r'\b[A-Z]{3,}\b', text)) > 2,
            "currency_symbols": bool(re.search(r'[$£€¥₹]', text)),
        }
        
        # Count active indicators
        active_count = sum(indicators.values())
        total_count = len(indicators)
        
        # Determine urgency level
        urgency_score = sum([
            indicators["urgent_words"] * 2,
            indicators["threat_words"] * 2,
            indicators["action_words"],
            indicators["excessive_punctuation"],
            indicators["all_caps"]
        ])
        
        if urgency_score >= 4:
            urgency_level = "CRITICAL"
        elif urgency_score >= 2:
            urgency_level = "HIGH"
        elif urgency_score >= 1:
            urgency_level = "MEDIUM"
        else:
            urgency_level = "LOW"
        
        indicators["urgency_level"] = urgency_level
        indicators["indicator_count"] = active_count
        indicators["indicator_percentage"] = round((active_count / total_count) * 100, 1)
        
        return indicators
    
    def _detect_poor_grammar(self, text: str) -> bool:
        """Simple heuristic for poor grammar"""
        issues = 0
        # Multiple spaces
        if re.search(r'\s{2,}', text):
            issues += 1
        # Missing spaces after punctuation
        if re.search(r'[.,!?][a-zA-Z]', text):
            issues += 1
        # Inconsistent capitalization
        sentences = re.split(r'[.!?]+', text)
        for sent in sentences:
            sent = sent.strip()
            if sent and len(sent) > 5 and not sent[0].isupper():
                issues += 1
                break
        return issues >= 2
    
    def sentiment_analysis(self, text: str) -> Dict:
        """Analyze sentiment"""
        blob = TextBlob(text)
        polarity = blob.sentiment.polarity
        subjectivity = blob.sentiment.subjectivity
        
        return {
            "polarity": round(polarity, 4),
            "subjectivity": round(subjectivity, 4),
            "sentiment": "positive" if polarity > 0.1 else "negative" if polarity < -0.1 else "neutral",
            "is_persuasive": subjectivity > 0.5,
        }
    
    def preprocess(self, text: str) -> Dict:
        """Full preprocessing pipeline"""
        tokens = self.tokenize(text)
        tokens_no_stop = self.remove_stopwords(tokens)
        stemmed = self.stem(tokens_no_stop)
        lemmatized = self.lemmatize(tokens_no_stop)
        sentiment = self.sentiment_analysis(text)
        phishing_indicators = self.analyze_phishing_indicators(text)
        
        return {
            "original_text": text,
            "tokens": tokens,
            "tokens_without_stopwords": tokens_no_stop,
            "stemmed_tokens": stemmed,
            "lemmatized_tokens": lemmatized,
            "sentiment": sentiment,
            "phishing_indicators": phishing_indicators,
            "token_count": len(tokens_no_stop)
        }


# ============================================================================
# PYDANTIC MODELS
# ============================================================================
class PredictPayload(BaseModel):
    inputs: str
    include_preprocessing: bool = True


class BatchPredictPayload(BaseModel):
    inputs: List[str]
    include_preprocessing: bool = True


class LabeledText(BaseModel):
    text: str
    label: Optional[str] = None


class EvalPayload(BaseModel):
    samples: List[LabeledText]


# ============================================================================
# GLOBAL VARIABLES
# ============================================================================
_tokenizer = None
_model = None
_device = "cpu"
_preprocessor = None


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def _normalize_label(txt: str) -> str:
    """Normalize label text"""
    t = (str(txt) if txt is not None else "").strip().upper()
    if t in ("PHISHING", "PHISH", "SPAM", "1"):
        return "PHISH"
    if t in ("LEGIT", "LEGITIMATE", "SAFE", "HAM", "0"):
        return "LEGIT"
    return t


def _adjust_confidence_with_indicators(base_prob: float, indicators: Dict, predicted_label: str) -> float:
    """
    Adjust confidence based on phishing indicators.
    More indicators = context suggests phishing, so confidence varies based on prediction
    """
    indicator_count = indicators.get("indicator_count", 0)
    indicator_percentage = indicators.get("indicator_percentage", 0)
    
    # Base adjustment from indicator count
    # If predicting PHISH and many indicators: more confident (but cap at 85%)
    # If predicting LEGIT with many indicators: less confident (uncertainty)
    # If predicting PHISH with few indicators: less confident (might be wrong)
    # If predicting LEGIT with few indicators: more confident
    
    if predicted_label == "PHISH":
        # Phishing prediction
        if indicator_percentage >= 40:  # Strong indicators
            # High confidence: 75-85%
            adjusted = 0.75 + (indicator_percentage / 100) * 0.10
        elif indicator_percentage >= 25:  # Moderate indicators
            # Medium confidence: 65-75%
            adjusted = 0.65 + (indicator_percentage / 100) * 0.10
        else:  # Weak indicators
            # Lower confidence: 55-65%
            adjusted = 0.55 + (indicator_percentage / 100) * 0.10
    else:
        # Legitimate prediction
        if indicator_percentage >= 40:  # Many phishing indicators but predicting legit?
            # Low confidence: 55-65% (uncertain)
            adjusted = 0.65 - (indicator_percentage / 100) * 0.10
        elif indicator_percentage >= 25:  # Some indicators
            # Medium confidence: 65-75%
            adjusted = 0.70 - (indicator_percentage / 100) * 0.05
        else:  # Few indicators
            # High confidence: 75-85%
            adjusted = 0.75 + ((100 - indicator_percentage) / 100) * 0.10
    
    # Clamp to min/max range
    adjusted = max(BASE_CONFIDENCE_MIN, min(BASE_CONFIDENCE_MAX, adjusted))
    
    return adjusted


def _load_model():
    """Load model, tokenizer, and preprocessor"""
    global _tokenizer, _model, _device, _preprocessor

    if _tokenizer is None or _model is None:
        _device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"\n{'='*60}")
        print(f"Loading model: {MODEL_ID}")
        print(f"Device: {_device}")
        print(f"Confidence range: {BASE_CONFIDENCE_MIN*100:.0f}%-{BASE_CONFIDENCE_MAX*100:.0f}%")
        print(f"{'='*60}\n")
        
        _tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
        _model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID)
        _model.to(_device)
        _model.eval()
        _preprocessor = TextPreprocessor()

        # Warm-up
        with torch.no_grad():
            _ = _model(
                **_tokenizer(["warm up"], return_tensors="pt", padding=True, truncation=True, max_length=512)
                .to(_device)
            ).logits

        id2label = getattr(_model.config, "id2label", {})
        print(f"Model labels: {id2label}")
        print(f"{'='*60}\n")


def _predict_texts(texts: List[str], include_preprocessing: bool = True) -> List[Dict]:
    """Predict with indicator-based confidence adjustment"""
    _load_model()
    if not texts:
        return []

    # Get preprocessing info (always needed for indicators)
    preprocessing_info = [_preprocessor.preprocess(text) for text in texts]

    # Tokenize
    enc = _tokenizer(
        texts,
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=512,
    )
    enc = {k: v.to(_device) for k, v in enc.items()}

    # Predict
    with torch.no_grad():
        logits = _model(**enc).logits
        probs = F.softmax(logits, dim=-1)

    # Get labels from model config
    id2label = getattr(_model.config, "id2label", {0: "LEGIT", 1: "PHISH"})

    outputs: List[Dict] = []
    for text_idx in range(probs.shape[0]):
        p = probs[text_idx]
        preprocessing = preprocessing_info[text_idx]
        indicators = preprocessing["phishing_indicators"]
        
        # Get prediction
        predicted_idx = int(torch.argmax(p).item())
        predicted_label_raw = id2label.get(predicted_idx, f"CLASS_{predicted_idx}")
        predicted_label_norm = _normalize_label(predicted_label_raw)
        raw_prob = float(p[predicted_idx].item())
        
        # Adjust confidence based on indicators
        adjusted_confidence = _adjust_confidence_with_indicators(
            raw_prob, indicators, predicted_label_norm
        )

        # Build probability breakdown (adjusted)
        prob_breakdown = {}
        for i in range(len(p)):
            label = _normalize_label(id2label.get(i, f"CLASS_{i}"))
            if i == predicted_idx:
                prob_breakdown[label] = round(adjusted_confidence, 4)
            else:
                prob_breakdown[label] = round(1.0 - adjusted_confidence, 4)

        output = {
            "text": texts[text_idx][:100] + "..." if len(texts[text_idx]) > 100 else texts[text_idx],
            "label": predicted_label_norm,
            "raw_label": predicted_label_raw,
            "is_phish": predicted_label_norm == "PHISH",
            "confidence": round(adjusted_confidence * 100, 2),
            "score": round(adjusted_confidence, 4),
            "probs": prob_breakdown,
            "model_raw_confidence": round(raw_prob * 100, 2),
        }
        
        if include_preprocessing:
            output["preprocessing"] = preprocessing
        
        outputs.append(output)

    return outputs


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
def root():
    """Root endpoint"""
    _load_model()
    return {
        "status": "ok",
        "model": MODEL_ID,
        "device": _device,
        "confidence_range": f"{BASE_CONFIDENCE_MIN*100:.0f}%-{BASE_CONFIDENCE_MAX*100:.0f}%",
        "note": "Confidence adjusted based on phishing indicators"
    }


@app.get("/debug/labels")
def debug_labels():
    """View model configuration"""
    _load_model()
    
    return {
        "status": "ok",
        "model_id": MODEL_ID,
        "id2label": getattr(_model.config, "id2label", {}),
        "label2id": getattr(_model.config, "label2id", {}),
        "num_labels": int(getattr(_model.config, "num_labels", 0)),
        "device": _device,
    }


@app.post("/debug/preprocessing")
def debug_preprocessing(payload: PredictPayload):
    """Debug preprocessing"""
    try:
        _load_model()
        preprocessing = _preprocessor.preprocess(payload.inputs)
        return preprocessing
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict")
def predict(payload: PredictPayload):
    """Single prediction"""
    try:
        res = _predict_texts([payload.inputs], include_preprocessing=payload.include_preprocessing)
        return res[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict-batch")
def predict_batch(payload: BatchPredictPayload):
    """Batch predictions"""
    try:
        return _predict_texts(payload.inputs, include_preprocessing=payload.include_preprocessing)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/evaluate")
def evaluate(payload: EvalPayload):
    """Evaluate on labeled samples"""
    try:
        texts = [s.text for s in payload.samples]
        gts = [(_normalize_label(s.label) if s.label is not None else None) for s in payload.samples]
        preds = _predict_texts(texts, include_preprocessing=False)

        total = len(preds)
        correct = 0
        per_class: Dict[str, Dict[str, int]] = {}

        for gt, pr in zip(gts, preds):
            pred_label = pr["label"]
            if gt is not None:
                correct += int(gt == pred_label)
                per_class.setdefault(gt, {"tp": 0, "count": 0})
                per_class[gt]["count"] += 1
                if gt == pred_label:
                    per_class[gt]["tp"] += 1

        has_gts = any(gt is not None for gt in gts)
        acc = (correct / sum(1 for gt in gts if gt is not None)) if has_gts else None

        return {
            "accuracy": round(acc, 4) if acc else None,
            "total": total,
            "correct": correct,
            "predictions": preds,
            "per_class": per_class,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)