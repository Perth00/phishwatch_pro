import os
os.environ.setdefault("HOME", "/data")
os.environ.setdefault("XDG_CACHE_HOME", "/data/.cache")
os.environ.setdefault("HF_HOME", "/data/.cache")
os.environ.setdefault("TRANSFORMERS_CACHE", "/data/.cache")
os.environ.setdefault("TORCH_HOME", "/data/.cache")

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch


MODEL_ID = os.environ.get("MODEL_ID", "Perth0603/phishing-email-mobilebert")

# Ensure writable cache directory for HF/torch inside Spaces Docker
CACHE_DIR = os.environ.get("HF_CACHE_DIR", "/data/.cache")
os.makedirs(CACHE_DIR, exist_ok=True)

app = FastAPI(title="Phishing Text Classifier", version="1.0.0")


class PredictPayload(BaseModel):
    inputs: str


# Lazy singletons for model/tokenizer
_tokenizer = None
_model = None


def _load_model():
    global _tokenizer, _model
    if _tokenizer is None or _model is None:
        _tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, cache_dir=CACHE_DIR)
        _model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID, cache_dir=CACHE_DIR)
        # Warm-up
        with torch.no_grad():
            _ = _model(**_tokenizer(["warm up"], return_tensors="pt")).logits


@app.get("/")
def root():
    return {"status": "ok", "model": MODEL_ID}


@app.post("/predict")
def predict(payload: PredictPayload):
    try:
        _load_model()
        with torch.no_grad():
            inputs = _tokenizer([payload.inputs], return_tensors="pt", truncation=True, max_length=512)
            logits = _model(**inputs).logits
            probs = torch.softmax(logits, dim=-1)[0]
            score, idx = torch.max(probs, dim=0)
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

    # Map common ids to labels (kept generic; your config also has these)
    id2label = {0: "LEGIT", 1: "PHISH"}
    label = id2label.get(int(idx), str(int(idx)))
    return {"label": label, "score": float(score)}


