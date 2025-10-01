import os
os.environ.setdefault("HOME", "/data")
os.environ.setdefault("XDG_CACHE_HOME", "/data/.cache")
os.environ.setdefault("HF_HOME", "/data/.cache")
os.environ.setdefault("TRANSFORMERS_CACHE", "/data/.cache")
os.environ.setdefault("TORCH_HOME", "/data/.cache")

from typing import Optional, List, Dict, Any
import threading
import re
import numpy as np
import pandas as pd
import joblib
import torch
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from huggingface_hub import hf_hub_download

try:
    import xgboost as xgb  # type: ignore
except Exception:
    xgb = None

# -------------------------
# Environment / config
# -------------------------
MODEL_ID = os.environ.get("MODEL_ID", "Perth0603/phishing-email-mobilebert")
URL_REPO = os.environ.get("URL_REPO", "Perth0603/Random-Forest-Model-for-PhishingDetection")
URL_REPO_TYPE = os.environ.get("URL_REPO_TYPE", "model")  # model|space|dataset
URL_FILENAME = os.environ.get("URL_FILENAME", "rf_url_phishing_xgboost_bst.joblib")
CACHE_DIR = os.environ.get("HF_CACHE_DIR", "/data/.cache")
os.makedirs(CACHE_DIR, exist_ok=True)

# Force-thread cap helps tiny Spaces
torch.set_num_threads(int(os.environ.get("TORCH_NUM_THREADS", "1")))

# Optional manual override (beats everything): "PHISH" or "LEGIT"
URL_POSITIVE_CLASS_ENV = os.environ.get("URL_POSITIVE_CLASS", "").strip().upper()  # "", "PHISH", "LEGIT"

app = FastAPI(title="PhishWatch API", version="1.2.0")

# -------------------------
# Schemas
# -------------------------
class PredictPayload(BaseModel):
    inputs: str

class PredictUrlPayload(BaseModel):
    url: str

# -------------------------
# Lazy singletons
# -------------------------
_tokenizer: Optional[AutoTokenizer] = None
_model: Optional[AutoModelForSequenceClassification] = None
_id2label: Dict[int, str] = {0: "LEGIT", 1: "PHISH"}
_label2id: Dict[str, int] = {"LEGIT": 0, "PHISH": 1}

_url_bundle: Optional[Dict[str, Any]] = None
_model_lock = threading.Lock()
_url_lock = threading.Lock()

# Calibrated flag: is XGB class 1 == PHISH?
_url_phish_is_positive: Optional[bool] = None

# -------------------------
# URL features (must match training)
# -------------------------
_SUSPICIOUS_TOKENS = ["login", "verify", "secure", "update", "bank", "pay", "account", "webscr"]
_ipv4_pattern = re.compile(r"(?:\d{1,3}\.){3}\d{1,3}")

def _engineer_features(df: pd.DataFrame, url_col: str, feature_cols: Optional[List[str]] = None) -> pd.DataFrame:
    s = df[url_col].astype(str).fillna("")
    out = pd.DataFrame(index=df.index)
    out["url_len"] = s.str.len()
    out["count_dot"] = s.str.count(r"\.")
    out["count_hyphen"] = s.str.count("-")
    out["count_digit"] = s.str.count(r"\d")
    out["count_at"] = s.str.count("@")
    out["count_qmark"] = s.str.count(r"\?")
    out["count_eq"] = s.str.count("=")
    out["count_slash"] = s.str.count("/")
    out["digit_ratio"] = (out["count_digit"] / out["url_len"].replace(0, np.nan)).fillna(0)
    out["has_ip"] = s.str.contains(_ipv4_pattern).fillna(False).astype(int)
    for tok in _SUSPICIOUS_TOKENS:
        out[f"has_{tok}"] = s.str.contains(tok, case=False, regex=False).fillna(False).astype(int)
    out["starts_https"] = s.str.startswith("https").astype(int)
    out["ends_with_exe"] = s.str.endswith(".exe").astype(int)
    out["ends_with_zip"] = s.str.endswith(".zip").astype(int)
    return out if not feature_cols else out[feature_cols]

# -------------------------
# Loaders
# -------------------------
def _load_model():
    global _tokenizer, _model, _id2label, _label2id
    if _tokenizer is None or _model is None:
        with _model_lock:
            if _tokenizer is None or _model is None:
                _tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, cache_dir=CACHE_DIR)
                _model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID, cache_dir=CACHE_DIR)
                cfg = getattr(_model, "config", None)
                if cfg is not None and getattr(cfg, "id2label", None):
                    _id2label = {int(k): v for k, v in cfg.id2label.items()}
                    _label2id = {v: int(k) for k, v in _id2label.items()}
                with torch.no_grad():
                    _ = _model(**_tokenizer(["warm up"], return_tensors="pt")).logits

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

def _xgb_predict_class1_prob(booster, feats: pd.DataFrame) -> float:
    # predicts P(class==1) under binary:logistic objective
    dmat = xgb.DMatrix(feats)
    return float(booster.predict(dmat)[0])

def _auto_calibrate_phish_positive(bundle: Dict[str, Any], feature_cols: List[str], url_col: str) -> bool:
    """
    Heuristic: probe with 'obviously phishy' and 'obviously legit' URLs.
    If mean P(class1) for phishy < legit, then class1 ≈ LEGIT → return False.
    Otherwise, class1 ≈ PHISH → return True.
    """
    # If user forces it via env, honor that first.
    if URL_POSITIVE_CLASS_ENV in ("PHISH", "LEGIT"):
        return URL_POSITIVE_CLASS_ENV == "PHISH"

    # If bundle has explicit flag, use it.
    if "phish_is_positive" in bundle:
        return bool(bundle["phish_is_positive"])

    phishy = [
        "http://198.51.100.23/login/update?acc=123",
        "http://secure-login-account-update.example.com/session?id=123",
        "http://bank.verify-update-security.com/confirm",
        "http://paypal.com.account-verify.cn/login",
        "http://abc.xyz/downloads/invoice.exe"
    ]
    legit = [
        "https://www.wikipedia.org/",
        "https://www.microsoft.com/",
        "https://www.openai.com/",
        "https://www.python.org/",
        "https://www.gov.uk/"
    ]

    def _batch_mean(urls: List[str]) -> float:
        df = pd.DataFrame({url_col: urls})
        f = _engineer_features(df, url_col, feature_cols)
        return float(np.mean([_xgb_predict_class1_prob(bundle["model"], pd.DataFrame([f.iloc[i]])) for i in range(len(f))]))

    try:
        phishy_mean = _batch_mean(phishy)
        legit_mean = _batch_mean(legit)
    except Exception as e:
        # If anything goes wrong, default to class1=PHISH to mimic common convention
        print(f"[autocalib] failed: {e}")
        return True

    # If phishy scores LOWER than legit for class1, then class1 is likely LEGIT
    class1_is_phish = phishy_mean > legit_mean
    print(f"[autocalib] phishy_mean={phishy_mean:.6f} legit_mean={legit_mean:.6f} -> class1_is_phish={class1_is_phish}")
    return class1_is_phish

# Optional: pre-load on startup
@app.on_event("startup")
def _startup():
    try:
        _load_model()
    except Exception as e:
        print(f"[startup] text model load failed: {e}")
    try:
        _load_url_model()
        # Calibrate for XGB if needed
        global _url_phish_is_positive
        b = _url_bundle
        if isinstance(b, dict) and b.get("model_type") == "xgboost_bst" and _url_phish_is_positive is None:
            if xgb is None:
                print("[startup] xgboost not installed; cannot calibrate URL model.")
            else:
                feature_cols: List[str] = b.get("feature_cols") or []
                url_col: str = b.get("url_col") or "url"
                _url_phish_is_positive = _auto_calibrate_phish_positive(b, feature_cols, url_col)
    except Exception as e:
        print(f"[startup] url model load failed: {e}")

# -------------------------
# Routes
# -------------------------
@app.get("/")
def root():
    return {"status": "ok", "model": MODEL_ID}

@app.post("/predict")
def predict(payload: PredictPayload):
    try:
        _load_model()
        text = (payload.inputs or "").strip()
        if not text:
            return JSONResponse(status_code=400, content={"error": "Empty input"})
        with torch.no_grad():
            inputs = _tokenizer([text], return_tensors="pt", truncation=True, max_length=512)
            logits = _model(**inputs).logits
            probs = torch.softmax(logits, dim=-1)[0]
            score, idx = torch.max(probs, dim=0)
            label = _id2label.get(int(idx), str(int(idx)))
        return {"label": label, "score": float(score), "raw_index": int(idx)}
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.post("/predict-url")
def predict_url(payload: PredictUrlPayload):
    try:
        _load_url_model()
        bundle = _url_bundle
        if not isinstance(bundle, dict) or "model" not in bundle:
            raise RuntimeError("Loaded URL artifact is not a bundle dict with 'model'.")

        model = bundle["model"]
        feature_cols: List[str] = bundle.get("feature_cols") or []
        url_col: str = bundle.get("url_col") or "url"
        model_type: str = bundle.get("model_type") or ""

        url_str = (payload.url or "").strip()
        if not url_str:
            return JSONResponse(status_code=400, content={"error": "Empty url"})

        row = pd.DataFrame({url_col: [url_str]})
        feats = _engineer_features(row, url_col, feature_cols)

        # ----- compute P(PHISH) -----
        phish_proba: float = 0.0
        meta_phish_is_positive: Optional[bool] = bundle.get("phish_is_positive", None)

        # Resolve polarity precedence: ENV > bundle flag > auto-calibration > default True
        if URL_POSITIVE_CLASS_ENV in ("PHISH", "LEGIT"):
            phish_is_positive = (URL_POSITIVE_CLASS_ENV == "PHISH")
        elif meta_phish_is_positive is not None:
            phish_is_positive = bool(meta_phish_is_positive)
        else:
            # If not yet calibrated, do it now for xgb
            global _url_phish_is_positive
            if _url_phish_is_positive is None and model_type == "xgboost_bst" and xgb is not None:
                _url_phish_is_positive = _auto_calibrate_phish_positive(bundle, feature_cols, url_col)
            phish_is_positive = _url_phish_is_positive if _url_phish_is_positive is not None else True

        backend_debug = {
            "phish_is_positive_resolved": phish_is_positive,
            "phish_is_positive_bundle": meta_phish_is_positive,
            "phish_is_positive_env": URL_POSITIVE_CLASS_ENV if URL_POSITIVE_CLASS_ENV else None,
        }

        if isinstance(model_type, str) and model_type == "xgboost_bst":
            if xgb is None:
                raise RuntimeError("xgboost is not installed but required for this model bundle.")
            dmat = xgb.DMatrix(feats)
            raw_p_class1 = float(model.predict(dmat)[0])  # P(class == 1)
            phish_proba = raw_p_class1 if phish_is_positive else (1.0 - raw_p_class1)

        elif hasattr(model, "predict_proba"):
            proba = model.predict_proba(feats)[0]
            classes = bundle.get("classes", getattr(model, "classes_", None))
            label_map = bundle.get("label_map")
            if classes is not None and len(proba) == 2:
                classes_list = list(classes)
                phish_idx = None
                if isinstance(label_map, dict):
                    for i, c in enumerate(classes_list):
                        mapped = str(label_map.get(int(c), "")).upper()
                        if mapped.startswith("PHISH"):
                            phish_idx = i
                            break
                if phish_idx is None:
                    # fall back to whichever index matches current polarity
                    # if phish_is_positive → column for class 1, else column for class 0
                    target_class = 1 if phish_is_positive else 0
                    if target_class in classes_list:
                        phish_idx = classes_list.index(target_class)
                    else:
                        phish_idx = 1 if phish_is_positive else 0
                phish_proba = float(proba[phish_idx])
            else:
                phish_proba = float(proba[1]) if len(proba) > 1 else float(np.max(proba))

        else:
            pred = model.predict(feats)[0]
            if isinstance(pred, (int, float, np.integer, np.floating)):
                label_numeric = int(pred)
                # interpret through polarity
                if label_numeric in (0, 1):
                    phish_proba = 1.0 if ((label_numeric == 1) == phish_is_positive) else 0.0
                else:
                    phish_proba = float(label_numeric)  # best-effort
            else:
                up = str(pred).strip().upper()
                phish_proba = 1.0 if up.startswith("PHISH") else 0.0

        phish_proba = float(phish_proba)
        label = "PHISH" if phish_proba >= 0.5 else "LEGIT"
        score = phish_proba if label == "PHISH" else (1.0 - phish_proba)

        return {
            "label": label,
            "score": float(score),
            "phishing_probability": float(phish_proba),
            "backend": str(model_type),
            "threshold": 0.5,
            # Debug/trace so you can see exactly what was used
            "phish_is_positive": bool(phish_is_positive),
            "phish_is_positive_bundle": meta_phish_is_positive,
            "phish_is_positive_env": URL_POSITIVE_CLASS_ENV if URL_POSITIVE_CLASS_ENV else None,
            "feature_cols": feature_cols,
            "url_col": url_col,
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
