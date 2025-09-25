---
title: PhishWatch Proxy
emoji: 🛡️
sdk: docker
---

# Hugging Face Space - Phishing Text Classifier (Docker + FastAPI)

This Space exposes a minimal `/predict` endpoint for your MobileBERT phishing model so the Flutter app can call it reliably.

## Files
- Dockerfile - builds a small FastAPI server image
- app.py - FastAPI app that loads the model and returns `{ label, score }`.
- requirements.txt - Python dependencies.

## How to deploy
1. Create a new Space on Hugging Face (type: Docker).
2. Upload the contents of this `hf_space/` folder to the Space root (including Dockerfile).
3. In Space Settings → Variables, add:
   - MODEL_ID = Perth0603/phishing-email-mobilebert
4. Wait for the Space to build and become green. Test:
   - GET `/` should return `{ status: ok, model: ... }`
   - POST `/predict` with `{ "inputs": "Win an iPhone! Click here" }`

## Flutter app config
Set the Space URL in your env file so the app targets the Space instead of the Hosted Inference API:

```
{"HF_SPACE_URL":"https://<your-space>.hf.space"}
```

Run the app:
```
flutter run --dart-define-from-file=hf.env.json
```
