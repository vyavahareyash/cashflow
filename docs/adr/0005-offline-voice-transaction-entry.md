# 5. On-Device Sherpa-ONNX (Moonshine) STT and GBNF-Constrained SmolLM2 via llama.cpp for Voice Transaction Journaling

## Status
Accepted

## Context
Manual transaction journaling introduces user friction and reduces engagement. To simplify logging while preserving Cashflow's core offline-first privacy guarantee, we evaluated edge voice-to-JSON architectures. Cloud AI violates offline privacy, while native OS STT and deterministic parsers lack semantic flexibility for multi-transaction monologues. Furthermore, Whisper-tiny imposes a 30-second zero-padding compute penalty, causing 1.2s–2.5s latency on typical 3-second voice logs.

## Decision
We implement fully embedded, on-device AI inference with variable-length STT and grammar-constrained SLM:
1. Audio transcription uses **`sherpa_onnx` with Moonshine Tiny INT8 (~30MB)**. Variable-length RoPE attention eliminates zero-padding, reducing compute by 5x (~250ms latency on short clips). Whisper-tiny remains a supported alternative.
2. Semantic entity extraction uses **SmolLM2-360M-Instruct (Q4_K_M, ~230MB)** via **`llama_cpp_dart`** in a background Dart isolate (`LlamaParent`). Provides high IFEval accuracy (41.0%) with low memory footprint (~350MB RAM). Qwen2.5-0.5B-Instruct (~350MB) serves as multilingual alternative.
3. Structured output strictly adheres to `TransactionModel` fields using GBNF (GGML BNF) grammar-constrained sampling.
4. Model weights are excluded from the base APK and downloaded once via explicit user initiation in Settings over Wi-Fi with SHA-256 integrity checks. No user data, telemetry, or audio ever leaves the device.
5. Parsed entries are staged in memory as ephemeral `Draft Transaction` objects in `Voice Transaction Staging` before atomic commit to SQLite.
6. Audio is recorded as 16kHz mono 16-bit PCM WAV via `record: ^5.2.0`; WAV files are deleted immediately upon STT completion.
7. Model weights are loaded into RAM on-demand when opening voice journaling and deallocated on exit.
8. System prompt receives current date anchor (`today: YYYY-MM-DD (DayOfWeek)`) and active SQLite accounts/categories for direct entity mapping.
9. Staging UI provides interactive inline chips for quick field corrections; valid drafts commit atomically, while flagged/invalid drafts remain for correction.

## Considered Options
- **`whisper.cpp` (`ggml-tiny.bin`)**: Standard baseline, but mandates 30s zero-padded audio windows causing 5x redundant compute and higher latency on 2–5s mobile utterances; lacks an officially maintained Flutter plugin.
- **SenseVoice-Small (`sherpa_onnx`)**: Extremely fast non-autoregressive decoding, but INT8 model bundle is ~228MB (compressed ~500MB), exceeding Cashflow's STT weight budget.
- **MediaPipe GenAI (LiteRT) / ExecuTorch**: Mobile runtimes, but lack token-level GBNF grammar sampling in Dart, risking malformed JSON on sub-billion models.
- **SmolLM2-135M**: Smallest download (~90MB), but fails relative date calculations and multi-transaction parsing.
- **Llama-3.2-1B**: Excellent reasoning, but consumes >1.4GB RAM, triggering Android Low Memory Killer (LMK) eviction on 3GB/4GB RAM phones.

## Consequences
- Requires exempting one-time static model weight file downloads from the zero-network invariant (strictly bounded to static binary downloads, never user telemetry or data).
- Eliminates cloud hosting costs and latency while ensuring zero data leakage.
- Guaranteed valid JSON syntax via GBNF grammar without hallucinated schema keys.
- Requires microphone hardware permissions and ~350MB RAM during active voice inference sessions (freed immediately on exit).
- Zero audio persistence: raw audio is purged as soon as text is extracted.
