---
title: PhishWatch Proxy
emoji: 🛡️
sdk: docker
---

# Hugging Face Space - Phishing Text Classifier (Docker + FastAPI)

This Space exposes two endpoints so the Flutter app can call them reliably:

- `/predict` for text/email/SMS classification via Transformers. Returns `{ label, score }` where `score` is the confidence for the predicted label.
- `/predict-url` for URL classification via your URL model. Returns `{ label, score, phishing_probability, backend, threshold }` where:
  - `phishing_probability` is always the raw probability of phishing (0..1)
  - `label` is `PHISH` when `phishing_probability >= threshold`, else `LEGIT`
  - `score` is the confidence for the predicted label (for `LEGIT`, `score = 1 - phishing_probability`), which lets the app show "Safe Confidence" for legitimate URLs

## Files
- Dockerfile - builds a small FastAPI server image
 - app.py - FastAPI app that loads the model and returns normalized responses as above.
- requirements.txt - Python dependencies.

## How to deploy
1. Create a new Space on Hugging Face (type: Docker).
2. Upload the contents of this `hf_space/` folder to the Space root (including Dockerfile).
3. In Space Settings → Variables, add:
   - MODEL_ID = Perth0603/phishing-email-mobilebert
   - URL_REPO = Perth0603/Random-Forest-Model-for-PhishingDetection
   - URL_FILENAME = url_rf_model.joblib  (set to your artifact filename)
4. Wait for the Space to build and become green. Test:
   - GET `/` should return `{ status: ok, model: ... }`
   - POST `/predict` with `{ "inputs": "Win an iPhone! Click here" }`
   - POST `/predict-url` with `{ "url": "https://example.com/login" }`

## Flutter app config
Set the Space URL in your env file so the app targets the Space instead of the Hosted Inference API:

```
{"HF_SPACE_URL":"https://<your-space>.hf.space"}
```

Run the app:
```
flutter run --dart-define-from-file=hf.env.json
```
