# 6. Platform-Native On-Device Speech Recognition (Android SpeechRecognizer & iOS SFSpeechRecognizer)

## Status
Accepted (Supercedes the custom STT engine section of ADR-0005)

## Context
In ADR-0005, Moonshine Tiny INT8 via `sherpa_onnx` was selected as the speech-to-text (STT) inference engine to run alongside SmolLM2 for offline voice journaling. Real-world testing identified significant friction points:
1. **Model Download Burden**: Bundling or downloading custom ONNX STT weights adds ~30–50MB of initial network transfer, conflicting with low-bandwidth environments.
2. **Acoustic Diversity & Energy Thresholding**: Custom ONNX models lack platform-tuned acoustic frontends and noise suppression across diverse mobile microphones, triggering false-positive silence errors (`SttSilentAudioException`) or degraded recognition on accented/soft speech.
3. **RAM & Compute Pressure**: Concurrently hosting Moonshine in RAM alongside SmolLM2 on 3GB/4GB Android devices increases memory pressure and latency.
4. **Native OS Capabilities**: Modern mobile platforms (Android 12+ Speech Services with on-device speech packs, iOS `SFSpeechRecognizer` with offline support) already provide hardware-accelerated, privacy-preserving, on-device speech recognition without external weight downloads.

## Decision
We replace the bundled `sherpa_onnx` Moonshine STT engine with platform-native on-device speech recognition (e.g. via `speech_to_text` with forced on-device offline mode):
1. **Platform Native Recognition**: Transcribe voice in real time using the device's native speech framework (`SpeechRecognizer` on Android, `SFSpeechRecognizer` on iOS) configured for strictly offline / on-device processing (`requiresOnDeviceRecognition: true`, `EXTRA_PREFER_OFFLINE: true`).
2. **Preserve Semantic SLM & GBNF Parsing**: The downstream semantic extraction pipeline (SmolLM2-360M with ChatML + GBNF grammar or deterministic fallback) is preserved unchanged. It receives the high-accuracy text transcript emitted by the native speech engine.
3. **Model Pack Size Reduction**: Remove Moonshine model weights (`preprocess.onnx`, `encode.int8.onnx`, `uncached_decode.int8.onnx`, `cached_decode.int8.onnx`, `tokens.txt`) from `AiModelPackManifest`. The offline model download is reduced exclusively to the SmolLM2 GGUF binary (~230MB).
4. **Clean Abstraction & Invariants**: Update `SpeechToTextService` to wrap the native platform plugin behind the existing `SttEngine` interface. Headless tests continue using `MockSttEngine` with zero native binary dependencies. Zero-telemetry, zero-cloud, and zero-persistence invariants remain strictly enforced.

## Consequences
- **Eliminates STT Download**: Users do not need to download custom STT models before speaking.
- **Superior Voice Accuracy**: Takes full advantage of device-specific microphone arrays, OS beamforming, and localized speech models (including Indian English and regional accents).
- **Reduced Memory & Latency**: Frees ~50MB of RAM during voice capture and avoids ONNX runtime initialization overhead.
- **Seamless Migration**: `VoicePipelineCoordinator`, `VoiceRecordingModal`, and `VoiceTransactionStagingSheet` remain intact, transitioning smoothly to native speech recognition.
