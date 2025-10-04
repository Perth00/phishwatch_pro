import os
import csv
import re
import threading
from typing import Optional, List, Dict, Any

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
    return out[feature_cols]


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

        url_str = (payload.url or "").strip()
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
        host = (urlparse(url_str).hostname or "").lower()
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

        # Mirror inference.py exactly for probability of class 1
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


