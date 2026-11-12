# AI Inference GPU and Accelerator Landscape

**Technical reference \| Updated: 12 November 2026**

> Scope: This guide focuses on high-end and production-relevant
> accelerators for serving generative AI models: LLMs, multimodal
> models, embeddings, rerankers, image generation and video generation.
> It covers discrete GPUs first, then dedicated non-GPU accelerators
> that are often evaluated alongside GPUs. Product specifications are
> vendor-published peak values, not a promise of application-level
> throughput.

## 1. Executive summary

The most important hardware families to evaluate for large-scale AI
inference are:

-   **NVIDIA Blackwell / Blackwell Ultra:** B200 and B300 systems;
    mature CUDA ecosystem, NVLink scale-up and strong low-precision
    inference support.
-   **NVIDIA Hopper:** H100 and H200; established production platforms,
    with H200's 141 GB HBM3e particularly useful for memory-bound LLM
    serving.
-   **NVIDIA Rubin:** next-generation platform with HBM4 and very high
    memory bandwidth. Treat published values as preliminary until final
    shipping-system specifications and independent benchmarks are
    available.
-   **NVIDIA RTX PRO 6000 Blackwell Server Edition:** 96 GB GDDR7 in a
    conventional PCIe server GPU; useful where a full HGX platform is
    unnecessary.
-   **AMD Instinct MI350 family:** MI350X and MI355X; 288 GB HBM3E and 8
    TB/s bandwidth, with native microscaling formats such as
    MXFP4/MXFP6/MXFP8.
-   **AMD Instinct MI325X / MI300X:** large HBM capacity and bandwidth;
    still relevant for deployments built around ROCm.
-   **Intel Gaudi 3:** a dedicated AI accelerator, not a conventional
    GPU; worth evaluating for supported model stacks and Ethernet-based
    scale-out.
-   **Google TPU Ironwood (TPU7x):** not a GPU, but a serious cloud
    inference alternative with 192 GiB HBM per chip according to Google
    Cloud's published specifications.

For inference, **usable memory capacity, memory bandwidth, interconnect,
supported quantization formats, runtime maturity and measured
tokens/second** usually matter more than a single headline FLOPS number.

## 2. How to read accelerator specifications

### 2.1 Memory capacity

Model weights, runtime workspace, activations and the KV cache all
consume accelerator memory.

Approximate weight-only memory before runtime overhead:

  -----------------------------------------------------------------------
  Weight format   Approximate bytes           8B model          70B model
                      per parameter                    
  -------------- ------------------ ------------------ ------------------
  FP16 / BF16                   2.0              16 GB             140 GB

  FP8 / INT8                    1.0               8 GB              70 GB

  4-bit                         0.5               4 GB              35 GB
  -----------------------------------------------------------------------

These are decimal approximations. Actual checkpoints have scales,
metadata, unquantized layers and alignment overhead. KV cache can be
substantial, especially with long context, many concurrent requests, or
large numbers of attention heads. A model that fits by weight size alone
may not fit at the target concurrency.

### 2.2 Memory bandwidth

Autoregressive decoding repeatedly reads model weights. For batch-one or
low-batch decoding, token generation can be strongly
memory-bandwidth-bound. Higher bandwidth can improve token generation
rate, but actual performance also depends on quantization kernels,
batching, cache reuse, attention implementation and the model
architecture.

### 2.3 Compute throughput and precision

Compare compute only at the same precision and with the same sparsity
convention:

-   **BF16 / FP16:** common high-quality inference formats; broad
    framework support.
-   **FP8:** halves weight storage versus BF16/FP16, but format variants
    and kernels matter.
-   **FP4 / MXFP4 / NVFP4:** can reduce memory use and increase
    throughput, subject to model quantization quality and runtime
    support.
-   **INT8 / INT4:** common quantized inference formats; implementation
    quality is decisive.
-   **Sparse peak values:** may be approximately twice dense values on
    some NVIDIA specification tables. Do not compare a sparse number
    against another vendor's dense number.

### 2.4 Scale-up and scale-out

-   **Scale-up:** communication among GPUs in one server, such as
    NVLink/NVSwitch or AMD Infinity Fabric.
-   **Scale-out:** communication among servers, commonly InfiniBand or
    high-speed Ethernet/RoCE.
-   For tensor parallelism, expert parallelism and disaggregated
    prefill/decode, interconnect performance can be as important as
    per-GPU compute.

### 2.5 TDP and system design

A 700--1,400 W accelerator requires suitable server power delivery,
cooling, rack density and facility capacity. OAM/SXM accelerators are
generally deployed in qualified server platforms, not as ordinary
desktop PCIe cards. Validate the complete system rather than selecting a
GPU in isolation.

------------------------------------------------------------------------

# 3. NVIDIA data-center GPUs

NVIDIA is the broadest software ecosystem for production inference,
particularly for CUDA-based frameworks, TensorRT-LLM, vLLM, SGLang,
Triton and NVIDIA Dynamo. CUDA compute capability is useful for
identifying architecture support, but it does not alone guarantee that a
particular inference engine or kernel supports every feature.

## 3.1 NVIDIA Rubin family

### Rubin GPU

**Positioning:** Next-generation, high-end inference and AI-factory
accelerator.

  Attribute                      Published individual-GPU value
  -------------------- ----------------------------------------
  Architecture                                     NVIDIA Rubin
  Memory                                            288 GB HBM4
  Memory bandwidth                                      22 TB/s
  NVLink                                         6th generation
  NVLink bandwidth                                     3.6 TB/s
  NVFP4 inference        Up to 50 PFLOPS (sparse specification)
  FP8 / FP6 training                          Up to 17.5 PFLOPS
  FP16 / BF16                                    Up to 4 PFLOPS
  FP32                                               130 TFLOPS

**Inference implications**

-   288 GB of HBM4 on one GPU gives substantial model-weight and
    KV-cache headroom.
-   22 TB/s memory bandwidth is designed for high-throughput,
    memory-intensive inference.
-   NVFP4 is a key part of the performance proposition. It is not enough
    for a model merely to be quantized to 4-bit; the serving stack must
    support the corresponding format and kernels.
-   Sixth-generation NVLink targets very high-bandwidth multi-GPU
    serving.

**Best-fit workloads**

-   Frontier-scale LLMs and MoE models.
-   High-concurrency, low-latency serving.
-   Large-context inference and high-throughput decode.
-   Large multi-GPU inference deployments.

**Caveats**

Published Rubin figures are preliminary and subject to change. Validate
final product configuration, supported memory capacity, power, cooling,
software versions and independent workload benchmarks before
procurement.

## 3.2 NVIDIA Blackwell Ultra: B300

**Positioning:** Top-tier Blackwell Ultra accelerator for very large
inference deployments.

  Attribute                                                         B300 SXM
  ------------------------ -------------------------------------------------
  Architecture                                               Blackwell Ultra
  Memory                                                        288 GB HBM3e
  Memory bandwidth                                              Up to 8 TB/s
  HGX configuration                                                   8 GPUs
  Total HBM in 8-GPU HGX                                       About 2.30 TB
  GPU-to-GPU fabric                                    5th-generation NVLink
  NVLink bandwidth           Up to 1.8 TB/s per GPU (platform specification)
  HGX scale-up fabric                                          NVLink Switch

**Inference implications**

-   288 GB per GPU enables larger models, larger KV caches or more
    concurrent sequences without immediately sharding weights.
-   8 TB/s memory bandwidth supports high-throughput decode.
-   Blackwell Ultra supports low-precision inference paths, including
    FP4-class formats. Confirm exact model quantization and
    serving-engine support.
-   HGX B300 is a system-level product: eight GPUs, NVLink switching,
    high-speed NICs, power and liquid-cooling considerations must be
    evaluated together.

**Best-fit workloads**

-   Very large dense and MoE models.
-   High-throughput enterprise inference.
-   Large context windows and high concurrency.
-   Large-scale prefill/decode disaggregation and multi-GPU serving.

**Caveats**

Do not treat the 8-GPU HGX's aggregate memory as one automatically
pooled memory space. The model-serving framework must explicitly shard
or distribute weights and cache across GPUs.

## 3.3 NVIDIA Blackwell: B200

**Positioning:** High-end general-purpose AI data-center GPU and a major
platform for LLM inference.

  Attribute                                                         B200 SXM
  ------------------------ -------------------------------------------------
  Architecture                                                     Blackwell
  Memory                                                        180 GB HBM3e
  Memory bandwidth                                              Up to 8 TB/s
  HGX configuration                                                   8 GPUs
  Total HBM in 8-GPU HGX                                             1.44 TB
  GPU-to-GPU fabric                                    5th-generation NVLink
  NVLink bandwidth           Up to 1.8 TB/s per GPU (platform specification)

**Inference implications**

-   180 GB HBM3e is a large per-device memory pool for model weights and
    KV cache.
-   High memory bandwidth benefits decode-heavy LLM serving.
-   FP4 support creates opportunities to serve larger models or increase
    concurrency, if model quality and kernels are validated.
-   Eight-GPU HGX systems provide high-bandwidth scale-up for tensor and
    expert parallel workloads.

**Best-fit workloads**

-   70B-class and larger models, depending on precision and context.
-   MoE models and high-concurrency serving.
-   Large multimodal models.
-   Enterprise inference clusters.

**B200 vs B300**

B300 increases per-GPU HBM capacity from 180 GB to 288 GB. Both are
high-bandwidth Blackwell-family systems; compare full server
availability, power, price, cooling and real application benchmarks
before deciding.

## 3.4 NVIDIA Hopper: H200

**Positioning:** Memory-rich, mature data-center GPU for production LLM
inference.

  -----------------------------------------------------------------------
  Attribute                                                H200 SXM / NVL
  ------------------------------ ----------------------------------------
  Architecture                                                     Hopper

  Memory                                                     141 GB HBM3e

  Memory bandwidth                                               4.8 TB/s

  FP8 Tensor Core peak                  Up to 3.958 PFLOPS (SXM, sparsity
                                                      convention applies)

  BF16 / FP16 Tensor Core peak          Up to 1.979 PFLOPS (SXM, sparsity
                                                      convention applies)

  SXM TDP                                       Up to 700 W, configurable

  MIG                            Supported; configuration depends on form
                                                                   factor

  Interconnect                           NVLink; PCIe Gen5 also available
  -----------------------------------------------------------------------

**Inference implications**

-   HBM3e capacity and bandwidth are the main advantages over H100.
-   Larger models can fit on fewer GPUs, reducing tensor-parallel
    communication.
-   H200 is a strong option for long-context serving and large KV-cache
    workloads.
-   Mature CUDA and inference-engine support make it a lower-risk option
    than a newly introduced architecture in environments already
    standardized on Hopper.

**Best-fit workloads**

-   70B-class models at reduced precision, subject to runtime overhead
    and KV cache.
-   Long-context inference.
-   Multi-tenant serving and high-throughput production systems.
-   Workloads already validated on Hopper.

## 3.5 NVIDIA Hopper: H100

**Positioning:** Established high-end inference and training GPU.

  -----------------------------------------------------------------------
  Attribute                                                      H100 SXM
  ------------------------------ ----------------------------------------
  Architecture                                                     Hopper

  Memory                                                       80 GB HBM3

  Memory bandwidth                                              3.35 TB/s

  FP8 Tensor Core peak            Up to 3.958 PFLOPS (sparsity convention
                                                                 applies)

  BF16 / FP16 Tensor Core peak    Up to 1.979 PFLOPS (sparsity convention
                                                                 applies)

  Interconnect                                                     NVLink

  MIG                                                           Supported
  -----------------------------------------------------------------------

**Inference implications**

-   Strong general-purpose LLM inference performance and mature software
    support.
-   80 GB capacity is more restrictive than H200 for large weights and
    KV cache.
-   H100 remains relevant where deployed capacity, pricing and
    availability are favorable.
-   For memory-bound decoding, H200's extra capacity and bandwidth can
    be valuable; benchmark the actual model and batch profile.

**Best-fit workloads**

-   Production LLM inference.
-   Embedding and reranking services.
-   Multimodal model serving.
-   Multi-GPU inference with tensor parallelism.

## 3.6 NVIDIA RTX PRO 6000 Blackwell Server Edition

**Positioning:** High-end PCIe server GPU with large GDDR7 memory,
suited to enterprise inference without requiring an HGX platform.

  Attribute                            RTX PRO 6000 Blackwell Server Edition
  ------------------------- ------------------------------------------------
  Architecture                                                     Blackwell
  Memory                                                96 GB GDDR7 with ECC
  Memory bandwidth                                                1,597 GB/s
  FP4 Tensor Core                                             Up to 4 PFLOPS
  FP8 Tensor Core                                             Up to 2 PFLOPS
  FP16 / BF16 Tensor Core                                      Up to 1 PFLOP
  FP32                                                            120 TFLOPS
  Power                                            Up to 600 W, configurable
  Form factor                 Dual-slot, full-height/full-length server card

**Inference implications**

-   96 GB is a useful middle ground between 48 GB
    workstation/data-center cards and HBM-based accelerators.
-   GDDR7 bandwidth is lower than HBM3e/HBM4 flagship devices, but
    capacity and FP4 compute make it attractive for many inference
    deployments.
-   PCIe deployment can simplify integration into conventional GPU
    servers.
-   Evaluate multi-GPU peer-to-peer behavior and topology for tensor
    parallelism; do not assume NVLink is available.

**Best-fit workloads**

-   Enterprise LLM serving.
-   8B--70B class models depending on quantization and context.
-   Image and video generation.
-   GPU pools where PCIe density, server flexibility and per-GPU cost
    matter.

## 3.7 NVIDIA L40S

**Positioning:** Versatile 48 GB PCIe GPU for enterprise inference,
graphics and generative AI.

  -----------------------------------------------------------------------
  Attribute                                                          L40S
  ------------------------------ ----------------------------------------
  Architecture                                               Ada Lovelace

  Memory                                                  48 GB GDDR6 ECC

  Memory bandwidth                                               864 GB/s

  FP8 Tensor Core                 Up to 1.466 PFLOPS (sparsity convention
                                                                 applies)

  FP16 / BF16 Tensor Core           Up to 733 TFLOPS (sparsity convention
                                                                 applies)

  Power                                                             350 W

  Form factor                                              Dual-slot PCIe

  MIG                                                       Not supported

  NVLink                                                    Not supported
  -----------------------------------------------------------------------

**Inference implications**

-   48 GB makes it useful for quantized LLMs, embeddings, rerankers and
    image-generation models.
-   GDDR6 bandwidth is substantially lower than HBM accelerators, so
    decode throughput may be more constrained.
-   Strong fit for mixed workloads that include graphics, video and AI.
-   Lack of MIG and NVLink should be considered when designing
    multi-tenant or multi-GPU systems.

**Best-fit workloads**

-   7B--30B-class quantized LLMs, depending on context and concurrency.
-   Embeddings and reranking.
-   Diffusion/image generation.
-   General-purpose inference nodes.

## 3.8 NVIDIA L4

**Positioning:** Low-power, high-density inference accelerator.

  -----------------------------------------------------------------------
  Attribute                                                            L4
  ------------------------------ ----------------------------------------
  Architecture                                               Ada Lovelace

  Memory                                                      24 GB GDDR6

  Memory bandwidth                                               300 GB/s

  FP8 Tensor Core                   Up to 485 TFLOPS (sparsity convention
                                                                 applies)

  FP16 / BF16 Tensor Core           Up to 242 TFLOPS (sparsity convention
                                                                 applies)

  Power                                                              72 W

  Form factor                               Single-slot, low-profile PCIe

  MIG                                                       Not supported
  -----------------------------------------------------------------------

**Inference implications**

-   Excellent power efficiency for smaller inference services.
-   Low-profile, single-slot design supports dense server
    configurations.
-   24 GB limits large model weights and long-context KV cache.
-   Particularly attractive for embeddings, rerankers, vision, speech
    and smaller quantized language models.

**Best-fit workloads**

-   Embedding and reranking.
-   Computer vision and speech.
-   Small LLMs and low-concurrency serving.
-   Cost- and power-sensitive inference.

## 3.9 NVIDIA A100 (still deployed, previous generation)

**Positioning:** Mature Ampere accelerator commonly found in existing
clusters.

  Attribute                    A100 80 GB SXM
  ------------------ ------------------------
  Architecture                         Ampere
  Memory                          80 GB HBM2e
  Memory bandwidth             About 2.0 TB/s
  Precision            FP16, BF16, TF32, INT8
  MIG                               Supported
  Interconnect                         NVLink

A100 remains useful for inference when already owned or available at
attractive rates. It lacks the newer FP8/FP4 acceleration capabilities
of later generations. It should generally be evaluated on total cost per
generated token rather than peak compute alone.

------------------------------------------------------------------------

# 4. AMD Instinct GPUs

AMD's data-center AI portfolio is based on the CDNA architecture and
ROCm software. MI300 and MI350 devices offer large HBM pools, high
memory bandwidth and an increasingly capable inference ecosystem.

## 4.1 AMD Instinct MI355X

**Positioning:** AMD's flagship MI350-series accelerator for large-scale
AI inference.

  Attribute                               MI355X
  --------------------- ------------------------
  Architecture                            CDNA 4
  Compute units                              256
  Matrix cores                             1,024
  Memory                            288 GB HBM3E
  Memory bandwidth                        8 TB/s
  FP16 / BF16 peak        About 2.5 PFLOPS dense
  FP8 peak                About 5.0 PFLOPS dense
  MXFP4 / MXFP6 peak           Up to 10.1 PFLOPS
  Form factor                                OAM
  Maximum board power              Up to 1,400 W

**Inference implications**

-   288 GB HBM3E is well suited to large models and large KV caches.
-   8 TB/s bandwidth is competitive with leading HBM-based inference
    accelerators.
-   Native MXFP4, MXFP6 and MXFP8 support is a major CDNA 4 feature.
-   The change from the MI300 family's FP8 FNUZ variant to the MI350
    family's OCP FP8 variant matters for quantized checkpoint
    compatibility.
-   AMD documents partitioning modes (SPX, DPX, QPX and CPX) that expose
    different portions of the GPU for workload placement.

**Best-fit workloads**

-   Large dense and MoE LLM inference.
-   High-concurrency serving.
-   Long-context inference.
-   Large-scale inference with ROCm, vLLM, SGLang or AMD ATOM.

**Operational notes**

-   Validate ROCm version, PyTorch build, model kernels, attention
    backend and RCCL topology.
-   Confirm the model's FP8 variant and quantization format.
-   Benchmark the exact serving engine. Peak accelerator numbers do not
    predict end-to-end tokens/sec.

## 4.2 AMD Instinct MI350X

**Positioning:** High-end MI350-series accelerator with the same 288 GB
HBM3E capacity and 8 TB/s bandwidth class as MI355X.

  Attribute                               MI350X
  --------------------- ------------------------
  Architecture                            CDNA 4
  Compute units                              256
  Memory                            288 GB HBM3E
  Memory bandwidth                        8 TB/s
  FP16 / BF16 peak        About 2.3 PFLOPS dense
  FP8 peak                About 4.6 PFLOPS dense
  MXFP4 / MXFP6 peak            Up to 9.2 PFLOPS
  Form factor                                OAM
  Maximum board power              Up to 1,000 W

**Inference implications**

MI350X offers the same memory capacity and bandwidth class as MI355X,
with lower peak compute and power. It is relevant when system cost,
power envelope and available server configurations make it a better fit.

## 4.3 AMD Instinct MI325X

**Positioning:** Memory-capacity upgrade within the MI300/CDNA 3 family.

  Attribute                               MI325X
  --------------------- ------------------------
  Architecture                            CDNA 3
  Compute units                              304
  Memory                            256 GB HBM3E
  Memory bandwidth                        6 TB/s
  FP16 / BF16 peak        About 1.3 PFLOPS dense
  FP8 peak                About 2.6 PFLOPS dense
  Form factor                                OAM
  Maximum board power              Up to 1,000 W

**Inference implications**

-   256 GB HBM3E provides substantial model and KV-cache capacity.
-   6 TB/s bandwidth supports memory-bound decode workloads.
-   CDNA 3 does not provide the native MXFP4/MXFP6/MXFP8 support
    introduced in CDNA 4.
-   It can be attractive for large models where capacity is more
    important than having the newest low-precision compute features.

## 4.4 AMD Instinct MI300X

**Positioning:** Established high-memory accelerator for generative AI.

  Attribute                                              MI300X
  --------------------- ---------------------------------------
  Architecture                                           CDNA 3
  Compute units                                             304
  Memory                                            192 GB HBM3
  Memory bandwidth                                     5.3 TB/s
  FP16 / BF16 peak                       About 1.3 PFLOPS dense
  FP8 peak                               About 2.6 PFLOPS dense
  Form factor                                               OAM
  Maximum board power     Platform-dependent; up to about 750 W

**Inference implications**

-   192 GB HBM3 was designed to run large LLMs with fewer devices.
-   Good candidate for large models and high-context inference when ROCm
    support is validated.
-   MI300X uses the FNUZ FP8 variant; checkpoint and kernel
    compatibility must be checked.
-   Existing MI300X clusters can remain useful for production inference,
    especially when already amortized.

## 4.5 AMD Instinct comparison

  ------------------------------------------------------------------------------
  GPU          Architecture             Memory        Bandwidth Key inference
                                                                differentiator
  ------------ -------------- ---------------- ---------------- ----------------
  MI300X       CDNA 3              192 GB HBM3         5.3 TB/s Large memory
                                                                pool

  MI325X       CDNA 3             256 GB HBM3E         6.0 TB/s Higher capacity

  MI350X       CDNA 4             288 GB HBM3E         8.0 TB/s MX formats and
                                                                bandwidth

  MI355X       CDNA 4             288 GB HBM3E         8.0 TB/s Highest
                                                                MI350-series
                                                                compute
  ------------------------------------------------------------------------------

------------------------------------------------------------------------

# 5. Intel Gaudi accelerators

## 5.1 Intel Gaudi 3

Gaudi 3 is an AI accelerator/HPU rather than a conventional GPU. It
belongs in an inference platform comparison because it targets
deep-learning training and serving.

**Key characteristics**

-   128 GB HBM2e memory per accelerator.
-   Approximately 3.7 TB/s memory bandwidth.
-   Dedicated matrix engines and AI compute.
-   Integrated high-speed Ethernet networking for scale-out.
-   Software ecosystem built around Intel Gaudi software, SynapseAI and
    Optimum Habana.

**Inference implications**

-   Can serve supported LLMs and transformer models.
-   Intel publishes measured model throughput for specific
    configurations, including Llama 3.1 8B and 70B.
-   Ethernet-based scale-out is an architectural differentiator.
-   Software and model coverage should be checked carefully before
    standardizing a cluster.

**Best-fit workloads**

-   Supported LLM inference workloads.
-   Organizations evaluating alternatives to CUDA-based infrastructure.
-   Scale-out systems where Ethernet integration is attractive.

**Caveat:** Do not compare Gaudi's HPU numbers directly with GPU FLOPS.
Compare end-to-end model performance, software support, system price and
operational maturity.

------------------------------------------------------------------------

# 6. Cloud-native non-GPU inference accelerators

These are not discrete GPUs, but they compete for the same AI inference
workloads. They should be tracked separately in a hardware inventory
because their programming models, runtimes and deployment options
differ.

## 6.1 Google TPU7x (Ironwood)

  Attribute                                           TPU7x chip
  ----------------------------------- --------------------------
  Product                                Google TPU7x / Ironwood
  Peak BF16 compute                                 2,307 TFLOPS
  Peak FP8 compute                                  4,614 TFLOPS
  HBM                                                    192 GiB
  HBM bandwidth                                       7,380 GB/s
  Inter-chip interconnect bandwidth     1,200 GB/s bidirectional
  Cloud deployment                       Google Cloud TPU slices

**Inference implications**

-   Google positions Ironwood as an inference-focused TPU generation.
-   Large HBM capacity and high bandwidth are suitable for large model
    serving.
-   TPU slices use a high-speed inter-chip topology for scale-up.
-   Workloads use the Google TPU software ecosystem rather than CUDA.

**Best-fit workloads**

-   Cloud-hosted LLM inference.
-   Large-scale serving on supported frameworks.
-   Organizations already using JAX, XLA or Google Cloud TPU
    infrastructure.

## 6.2 AWS Trainium

AWS Trainium is a purpose-built cloud AI accelerator, not a
general-purpose PCIe GPU. It is accessed through AWS instance families
and the Neuron SDK.

When comparing Trainium generations, evaluate:

-   HBM capacity and bandwidth per chip.
-   Neuron compiler and runtime support for the target model.
-   Supported data types and quantization.
-   Interconnect and multi-chip scaling.
-   Availability of the required EC2 instance family and regional
    capacity.
-   Cost per million generated tokens under the actual request profile.

Treat Trainium as a cloud-specific accelerator category, not as a GPU
model that can be installed into a Kubernetes node in the same way as a
PCIe GPU.

------------------------------------------------------------------------

# 7. Quick comparison matrix

The following table is a compact shortlist of high-end and commonly
deployed inference accelerators. Values are approximate vendor-published
specifications and vary by SKU/form factor.

  ---------------------------------------------------------------------------
  Accelerator                   Memory     Memory bandwidth Main strength
  --------------- -------------------- -------------------- -----------------
  NVIDIA Rubin             288 GB HBM4              22 TB/s Next-generation
                                                            frontier
                                                            inference

  NVIDIA B300             288 GB HBM3e         Up to 8 TB/s Blackwell Ultra
                                                            capacity

  NVIDIA B200             180 GB HBM3e         Up to 8 TB/s High-throughput
                                                            Blackwell
                                                            inference

  NVIDIA H200             141 GB HBM3e             4.8 TB/s Mature
                                                            large-model
                                                            serving

  NVIDIA H100               80 GB HBM3            3.35 TB/s Mature CUDA
                                                            platform

  NVIDIA RTX PRO           96 GB GDDR7           1.597 TB/s Flexible PCIe
  6000 Blackwell                                            inference
  Server                                                    

  NVIDIA L40S              48 GB GDDR6             864 GB/s Mixed enterprise
                                                            inference

  NVIDIA L4                24 GB GDDR6             300 GB/s Low-power
                                                            inference

  AMD MI355X              288 GB HBM3E               8 TB/s Large-memory CDNA
                                                            4 inference

  AMD MI350X              288 GB HBM3E               8 TB/s CDNA 4 capacity
                                                            and bandwidth

  AMD MI325X              256 GB HBM3E               6 TB/s Large-memory CDNA
                                                            3

  AMD MI300X               192 GB HBM3             5.3 TB/s Established ROCm
                                                            inference

  Intel Gaudi 3           128 GB HBM2e           \~3.7 TB/s Dedicated AI
                                                            accelerator

  Google TPU7x             192 GiB HBM            7.38 TB/s Cloud TPU
                                                            inference
  ---------------------------------------------------------------------------

**Important:** Do not use this table as a benchmark ranking.
Architectures, precision, sparsity, kernel support, interconnect and
power differ. For procurement, compare measured throughput and latency
on the exact model.

------------------------------------------------------------------------

# 8. Which GPU is best for each inference workload?

  -----------------------------------------------------------------------
  Workload                Hardware                Example accelerators
                          characteristics to      
                          prioritize              
  ----------------------- ----------------------- -----------------------
  Small LLMs (1B--8B)     Cost, power, 16--24 GB  L4, RTX 4090/5090, RTX
                          VRAM                    A4500

  Medium LLMs (8B--32B)   24--48+ GB, bandwidth   L40S, RTX PRO 6000, L4
                                                  multi-GPU

  70B-class LLMs          80 GB+ or quantization  H100, H200, B200,
                          and multi-GPU           MI300X

  Very large dense LLMs   141--288 GB HBM per     H200, B200, B300,
                          device, fast fabric     MI355X

  MoE models              HBM capacity,           B200/B300, MI350/MI355,
                          expert-parallel         H200
                          bandwidth, fast fabric  

  Long-context serving    Memory capacity,        H200, B200, B300,
                          bandwidth, KV-cache     MI325X/MI355X
                          management              

  High-throughput batch   Tensor compute, memory  B200/B300, MI355X, H200
  inference               bandwidth, batching     

  Embeddings / reranking  Cost per request,       L4, L40S, A10, RTX PRO
                          memory, batching        

  Image generation        Compute, memory,        L40S, RTX PRO 6000,
                          supported kernels       B200

  Video generation        High memory, compute,   RTX PRO 6000,
                          bandwidth               B200/B300, MI355X

  Low-power edge          Power efficiency and    L4, Jetson family, edge
  inference               compact form factor     accelerators
  -----------------------------------------------------------------------

The model-size bands are planning heuristics, not strict compatibility
guarantees.

------------------------------------------------------------------------

# 9. Inference performance: what should actually be benchmarked?

For an inference platform, GPU specifications are only the starting
point. Benchmark each GPU with the same model, precision, serving engine
and request distribution.

## 9.1 Core metrics

  -----------------------------------------------------------------------
  Metric                  Meaning                 Why it matters
  ----------------------- ----------------------- -----------------------
  TTFT                    Time to first token     User-perceived
                                                  responsiveness

  TPOT                    Time per output token   Streaming generation
                                                  speed

  Tokens/sec              Output token throughput Serving capacity

  Requests/sec            Completed requests per  Application throughput
                          second                  

  p50 / p95 / p99 latency Latency distribution    Tail latency and SLOs

  Prefill throughput      Input tokens processed  Prompt-heavy workloads
                          per second              

  Decode throughput       Output tokens generated Generation-heavy
                          per second              workloads

  GPU memory utilization  Memory consumed         Capacity and headroom

  SM / compute            Compute engine activity Compute saturation
  utilization                                     

  HBM bandwidth           Memory traffic          Memory bottlenecks
  utilization                                     

  Power / energy per      Energy consumed per     Efficiency and
  token                   output                  operating cost
  -----------------------------------------------------------------------

## 9.2 Benchmark dimensions

Run a matrix across:

1.  Model: dense and MoE models, multiple parameter sizes.
2.  Precision: BF16, FP16, FP8, FP4/INT4 where supported.
3.  Input length: short, medium and long prompts.
4.  Output length: short and long generations.
5.  Concurrency: 1, 4, 16, 64 and higher where relevant.
6.  Batch policy: continuous batching and static batching.
7.  Parallelism: single GPU, tensor parallel, pipeline parallel and
    expert parallel.
8.  KV cache: standard cache, prefix caching and quantized cache where
    supported.
9.  Serving stack: vLLM, SGLang, TensorRT-LLM, Triton, ROCm-compatible
    engines or vendor-specific runtime.
10. Power: performance per watt and energy per million output tokens.

Keep the exact software versions, driver, firmware, container image,
model revision and benchmark settings with every result.

------------------------------------------------------------------------

# 10. Software ecosystem and inference compatibility

  -----------------------------------------------------------------------
  Hardware family         Main software stack     Inference engines /
                                                  ecosystem to validate
  ----------------------- ----------------------- -----------------------
  NVIDIA                  CUDA, cuDNN, TensorRT,  vLLM, SGLang,
                          NCCL                    TensorRT-LLM, Triton,
                                                  Dynamo

  AMD Instinct            ROCm, HIP, RCCL         vLLM, SGLang, ATOM,
                                                  MIGraphX

  Intel Gaudi             SynapseAI, Habana,      Gaudi-supported Hugging
                          Optimum Habana          Face and serving paths

  Google TPU              XLA, JAX, TensorFlow,   TPU-compatible serving
                          PyTorch/XLA             frameworks

  AWS Trainium            Neuron SDK              Neuron-supported model
                                                  serving
  -----------------------------------------------------------------------

Compatibility changes quickly. Confirm the exact GPU SKU, architecture
target, driver/runtime, framework build, attention kernels, quantization
format and distributed communication backend. A framework listing a
vendor as supported does not imply that every model or feature is
supported on every accelerator.

------------------------------------------------------------------------

# 11. Kubernetes and multi-tenant GPU infrastructure considerations

For a Kubernetes-based inference platform, expose hardware capability
and scheduling data separately from simple GPU inventory.

## 11.1 Resource allocation models

-   **Exclusive GPU allocation:** assign an entire GPU to one workload;
    simplest performance isolation.
-   **MIG:** hardware partitioning available on supported NVIDIA GPUs;
    exposes isolated GPU instances with defined memory and compute
    resources.
-   **Time-slicing:** shares a physical GPU across workloads; improves
    utilization but does not provide the same memory and fault isolation
    as MIG.
-   **vGPU:** virtualized GPU profiles, subject to hardware and
    licensing support.
-   **AMD partitioning:** supported MI300/MI350 partition modes expose
    subsets of GPU compute and memory; confirm runtime and orchestration
    support.
-   **DRA:** Kubernetes Dynamic Resource Allocation can express richer
    device claims and allocation workflows. Actual GPU support depends
    on the vendor driver and DRA integration.
-   **Queue-based scheduling:** KAI Scheduler or another batch scheduler
    can queue jobs instead of reserving scarce GPUs while workloads
    wait.

## 11.2 Scheduling signals

A smart scheduler should consider:

-   Required model-weight memory.
-   Estimated KV-cache memory at requested context and concurrency.
-   Supported precision and quantization kernels.
-   Available memory after system and runtime overhead.
-   GPU architecture and compute capability.
-   HBM bandwidth and interconnect topology.
-   Existing GPU utilization and memory fragmentation.
-   Required MIG / partition profile.
-   Node affinity, NUMA and NIC topology.
-   Power and thermal limits.
-   SLO and workload priority.

Do not schedule from VRAM capacity alone. A model may fit but fail to
achieve its latency target, or may fit only at an impractically low
concurrency.

------------------------------------------------------------------------

# 12. Recommendations for an AI inference platform

For a platform such as Portainer AI, I would model hardware in the
following hierarchy:

### A. Vendor

NVIDIA, AMD, Intel, Google, AWS and other accelerator providers.

### B. Product family

Examples: Blackwell, Hopper, Instinct MI350, Instinct MI300, Gaudi, TPU.

### C. Device model

Examples: B300, B200, H200, H100, MI355X, MI325X, L40S, L4.

### D. Device capability profile

-   Memory capacity and type.
-   Memory bandwidth.
-   Architecture / compute capability.
-   Supported precision formats.
-   Dense compute throughput by precision.
-   Interconnect type and bandwidth.
-   Power and thermal envelope.
-   Partitioning / virtualization capabilities.
-   Supported runtime and driver versions.

### E. Workload compatibility profile

-   Model architecture and parameter count.
-   Model precision / quantization.
-   Minimum and recommended memory.
-   Context length and KV-cache estimate.
-   Serving-engine compatibility.
-   Benchmark results for the target workload.

### F. Live operational metrics

-   Allocated vs free capacity.
-   Actual memory utilization.
-   Compute utilization.
-   Memory bandwidth utilization.
-   Power consumption.
-   Temperature and throttling.
-   Active models and workloads.
-   Tokens/sec, TTFT, TPOT and request latency.

### Suggested platform features

1.  **GPU Catalog:** searchable hardware database across vendors.
2.  **GPU Capability Matrix:** filter by VRAM, bandwidth, precision and
    architecture.
3.  **Model Fit Estimator:** estimate whether a model fits at a target
    context and concurrency.
4.  **Benchmarking:** run AIperF or GuideLLM-style serving benchmarks
    and retain reproducible configurations.
5.  **Performance Comparison:** compare the same model across hardware
    and precision.
6.  **GPU Utilization and Reclamation:** identify idle allocations and
    reclaim capacity safely.
7.  **Intelligent Placement:** select hardware based on model
    compatibility, SLO, cost and availability.
8.  **Queue-based Workloads:** schedule batch inference and offline jobs
    without permanently reserving a GPU.
9.  **Multi-vendor Support:** treat CUDA, ROCm, Gaudi, TPU and
    cloud-specific accelerators as distinct backends rather than
    assuming a single GPU interface.

------------------------------------------------------------------------

# 13. Procurement and selection checklist

Before buying or renting a GPU, verify:

-   [ ] Exact board / module SKU and form factor.
-   [ ] Usable HBM or GDDR capacity (not just family-level advertised
    capacity).
-   [ ] Memory bandwidth and precision-specific dense compute.
-   [ ] FP8 / FP4 / MX format compatibility with the model checkpoint.
-   [ ] Single-GPU model fit at target context and concurrency.
-   [ ] Multi-GPU interconnect and topology.
-   [ ] Server CPU, PCIe lanes, NICs, memory and storage.
-   [ ] Power delivery, rack density and cooling.
-   [ ] Driver, firmware and runtime support.
-   [ ] Serving-engine and model-kernel support.
-   [ ] Measured TTFT, TPOT, throughput and p99 latency.
-   [ ] Cost per million input and output tokens.
-   [ ] Availability, support lifecycle and replacement lead time.

## 14. Sources and further reading

### NVIDIA

-   [NVIDIA CUDA GPU Compute
    Capability](https://developer.nvidia.com/cuda/gpus)
-   [NVIDIA H200
    specifications](https://www.nvidia.com/en-in/data-center/h200/)
-   [NVIDIA L40S
    specifications](https://www.nvidia.com/en-in/data-center/l40s/)
-   [NVIDIA L4
    specifications](https://www.nvidia.com/en-in/data-center/l4/)
-   [NVIDIA RTX PRO 6000 Blackwell Server
    Edition](https://www.nvidia.com/en-gb/data-center/rtx-pro-6000-blackwell-server-edition/)
-   [NVIDIA HGX platform](https://www.nvidia.com/en-in/data-center/hgx/)
-   [NVIDIA Vera Rubin
    NVL72](https://www.nvidia.com/en-in/data-center/vera-rubin-nvl72/)
-   [NVIDIA HGX system architecture
    documentation](https://docs.nvidia.com/enterprise-reference-architectures/hgx-ai-factory/latest/components.html)

### AMD

-   [AMD Instinct accelerator
    specifications](https://www.amd.com/en/products/specifications/accelerators.html)
-   [AMD Instinct MI300
    series](https://www.amd.com/en/products/accelerators/instinct/mi300.html)
-   [AMD Instinct MI350
    series](https://www.amd.com/en/products/accelerators/instinct/mi350.html)
-   [AMD Instinct MI355X
    specifications](https://www.amd.com/en/products/accelerators/instinct/mi350/mi355x.html)
-   [ROCm MI300 / MI350 inference workload
    optimization](https://rocm.docs.amd.com/en/docs-7.2.4/how-to/rocm-for-ai/inference-optimization/workload.html)
-   [AMD ROCm AI
    ecosystem](https://rocm.docs.amd.com/en/develop/ai-ecosystem.html)

### Intel and Google

-   [Intel Gaudi 3 inference performance
    data](https://www.intel.com/content/www/us/en/developer/platform/gaudi/model-performance.html)
-   [Google Cloud TPU machine
    specifications](https://docs.cloud.google.com/compute/docs/tpus/tpu-machines)

------------------------------------------------------------------------

## 15. Important notes on interpreting the data

1.  Specifications are vendor-published peak values and can change by
    board, module, server configuration or firmware.
2.  NVIDIA performance values may include sparsity. Always distinguish
    dense from sparse figures.
3.  The Rubin values above are preliminary platform/product information
    and should be revalidated against final shipping specifications.
4.  AMD's MI300 and MI350 generations differ in FP8 encoding and
    low-precision format support. Check checkpoint compatibility.
5.  GPU memory capacity is not equal to the amount available to model
    weights; runtime, CUDA/ROCm allocations, activations and KV cache
    need headroom.
6.  Google TPU and AWS Trainium are accelerators, not discrete GPUs.
    They are included as alternatives for inference infrastructure
    planning.
7.  No single specification predicts tokens/sec. Benchmark the exact
    model, engine, precision, context, concurrency and hardware
    topology.
