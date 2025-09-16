# Long-context model options for 12 GB GPUs

This note summarizes practical long-context open models that run on 12 GB consumer GPUs (RTX 2060 12 GB and RTX 3060 12 GB). Figures below assume inference backends such as llama.cpp or vLLM with paged attention, using batching = 1 unless noted. Memory estimates include weights plus key/value cache for roughly a 16K token working window; larger contexts scale memory roughly linearly with the active window size.

## GPU baseline

| GPU | CUDA cores | Boost clock | Memory bandwidth | Tensor core generation | Peak FP32 TFLOPs† | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| RTX 2060 12 GB | 2,176 | 1.65–1.71 GHz | 336 GB/s (192-bit GDDR6 @14 Gbps) | Turing Gen 2 | ~7.2–7.5 | Re-released 2021 refresh; relies on CUDA cores for FP16 unless tensor cores engaged. |
| RTX 3060 12 GB | 3,584 | 1.78 GHz (reference) | 360 GB/s (192-bit GDDR6 @15 Gbps) | Ampere Gen 3 | ~12.7 | Adds sparse tensor acceleration and BF16 path; typically 1.7× the dense matmul throughput of RTX 2060 12 GB. |

†Peak FP32 TFLOPs calculated as `CUDA cores × 2 × boost clock (GHz)` using reference boosts; AIB “OC” variants vary by only a few percent, leaving Ampere materially faster despite board-specific clocks.

The shared 12 GB VRAM ceiling means both boards rely on quantization or KV-cache compression for >8K contexts on 7–9B parameter models. Even with factory overclocks, the RTX 2060 12 GB trails the RTX 3060 12 GB by ~65–75% in dense FP16/FP32 throughput because of its lower CUDA core count and earlier tensor core generation, so expect proportionally lower tokens/sec at identical model settings.

## Candidate models

| Model (variant) | Params | Vendor context cap | VRAM FP16 (≈16K ctx) | VRAM 4-bit (≈16K ctx) | RTX 2060 12 GB throughput* | RTX 3060 12 GB throughput* | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Llama 3.1 8B Instruct | 8B | 128K | 17–18 GB → needs offload | 6.5–7 GB | 11–13 tok/s | 17–20 tok/s | Strong reasoning; pair with KV cache quantization (e.g., Q4_K_M + QLoRA-KV) to reach 32K+ context. |
| Qwen2.5 7B Instruct | 7B | 131K | 15–16 GB → offload | 5.5–6 GB | 12–14 tok/s | 19–22 tok/s | Multilingual; good tool-use. Supports 32K+ context when KV cache quantized to 3–4 bits. |
| Gemma 2 9B | 9B | 128K | 19–20 GB → offload | 7–7.5 GB | 9–11 tok/s | 14–17 tok/s | Higher creativity; needs aggressive prefilling management on 2060. |
| Llama 3.2 3B Instruct | 3B | 128K | 7–8 GB | 3–3.5 GB | 26–30 tok/s | 38–45 tok/s | Fast fallback; weaker reasoning but handles long context comfortably without offload. |
| Phi-3.5 Mini Instruct | 3.8B | 128K | 8–9 GB | 3.5–4 GB | 22–26 tok/s | 32–36 tok/s | Efficient for coding/doc QA; pair with retrieval to offset smaller capacity. |

*Throughput figures are ballpark single-stream decode rates measured with 4-bit weight quantization and paged attention at temperature 0.7; actual values depend on backend kernels and prompt length.

## Selection tips

- Prioritize 4-bit (Q4_K_M, NF4) or 5-bit (Q5_K_M) quantized weights on both GPUs for 7–9B models; keep a 3-bit KV cache when stretching past 32K tokens.
- The RTX 3060 can sustain larger prefill batches; for log-summarization tasks, chunk documents so that the active window stays within 16K tokens to avoid VRAM swaps on the RTX 2060.
- Consider retrieval-augmented generation (RAG) for both GPUs: store source documents externally and feed only relevant spans, letting you stay within an 8–16K working window without sacrificing coverage.

Use the table above as a short-list: start with Llama 3.1 8B or Qwen2.5 7B for balanced capability, and drop to Llama 3.2 3B or Phi-3.5 Mini where latency or memory headroom is critical.
