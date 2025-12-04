# Project Status - Paused

**Last Updated:** 2024-12-04
**Last Release:** v1.1.4
**Reason for Pause:** PyTorch MPS bug on macOS Tahoe 26.2

---

## Current State

The training pipeline is functional but blocked by a PyTorch MPS (Metal Performance Shaders) compatibility issue on macOS Tahoe 26.2.

### What Works
- Dataset selection and listing from backend
- Model selection for training
- Training configuration UI (epochs, batch size, learning rate, LoRA settings)
- Device toggle (MPS/CPU) added in v1.1.4
- API communication with backend at `/training/start`

### The Problem
PyTorch's MPS backend has a bug on macOS Tahoe 26.2 that causes training to fail. The frontend now sends `"device": "cpu"` or `"device": "mps"` to allow testing, but CPU training is very slow.

---

## Quick Resume Guide

### Backend Endpoint
```
POST /training/start
```

### Request Payload
```json
{
  "dataset_id": 3,
  "model_id": 7,
  "epochs": 3,
  "batch_size": 32,
  "learning_rate": 0.0001,
  "use_lora": true,
  "device": "mps"  // or "cpu"
}
```

### Key Files
- `Sources/Views/TrainingTab.swift` - Training UI and ViewModel
- `Sources/Models/Job.swift` - API request/response models
- `Sources/Services/APIClient.swift` - Backend communication

### To Test When PyTorch is Fixed
1. Enable MPS toggle in Training tab
2. Start training and verify no MPS errors in backend logs
3. If working, MPS should be significantly faster than CPU

---

## References
- PyTorch MPS Backend: https://pytorch.org/docs/stable/notes/mps.html
- Check PyTorch releases for Tahoe/macOS 26 fixes

---

## Git Status at Pause
- Branch: `main`
- Commit: `e4c3a39`
- Release: `v1.1.4`
- All changes committed and pushed
