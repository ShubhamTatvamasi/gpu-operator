#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# NVIDIA GPU CLUSTER REPORT
# ==============================================================================

REPORT_DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HEADER_WIDTH=78

# ==============================================================================
# Colors
# ==============================================================================

if [[ "${NO_COLOR:-}" == "1" ]]; then
    RESET=''
    BOLD=''
    DIM=''
    BLUE=''
    CYAN=''
    GREEN=''
    YELLOW=''
    RED=''
else
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'

    # Light blue / bright cyan
    BLUE=$'\033[96m'
    CYAN=$'\033[96m'

    GREEN=$'\033[92m'
    YELLOW=$'\033[93m'
    RED=$'\033[91m'
fi

# ==============================================================================
# Dependency Check
# ==============================================================================

for command in kubectl jq awk; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: '$command' is required but not installed." >&2
        exit 1
    fi
done

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    local width="$HEADER_WIDTH"
    local inner=$((width - 2))

    local title="NVIDIA GPU CLUSTER REPORT"
    local subtitle="Kubernetes GPU Inventory"

    local title_len=${#title}
    local subtitle_len=${#subtitle}

    local title_left=$(( (inner - title_len) / 2 ))
    local title_right=$(( inner - title_len - title_left ))

    local subtitle_left=$(( (inner - subtitle_len) / 2 ))
    local subtitle_right=$(( inner - subtitle_len - subtitle_left ))

    printf '\n'

    printf '%b\n' \
        "${BLUE}╔$(printf '═%.0s' $(seq 1 "$inner"))╗${RESET}"

    printf '%b\n' \
        "${BLUE}║$(printf '%*s' "$title_left" '')${BOLD}${title}${RESET}${BLUE}$(printf '%*s' "$title_right" '')║${RESET}"

    printf '%b\n' \
        "${BLUE}║$(printf '%*s' "$subtitle_left" '')${DIM}${subtitle}${RESET}${BLUE}$(printf '%*s' "$subtitle_right" '')║${RESET}"

    printf '%b\n' \
        "${BLUE}╚$(printf '═%.0s' $(seq 1 "$inner"))╝${RESET}"

    printf '\n'
}

section() {
    local title="$1"

    printf '\n'

    printf '%b\n' \
        "${BLUE}┌────────────────────────────── ${title} ──────────────────────────────┐${RESET}"

    printf '\n'
}

# ==============================================================================
# Collect Kubernetes Data
# ==============================================================================

NODES_JSON="$(kubectl get nodes -l nvidia.com/gpu.present=true -o json)"
PODS_JSON="$(kubectl get pods -A -o json)"

# ==============================================================================
# Cluster Totals
# ==============================================================================

TOTAL_NODES="$(
    jq '.items | length' <<< "$NODES_JSON"
)"

TOTAL_GPUS="$(
    jq '
        [
            .items[]
            | .status.allocatable["nvidia.com/gpu"]
            | tonumber
        ]
        | add // 0
    ' <<< "$NODES_JSON"
)"

ALLOCATED_GPUS="$(
    jq '
        [
            .items[]
            | select(.spec.nodeName != null)
            | [
                .spec.containers[]
                | (.resources.limits["nvidia.com/gpu"] // 0)
                | tonumber
            ]
            | add
        ]
        | add // 0
    ' <<< "$PODS_JSON"
)"

AVAILABLE_GPUS=$((TOTAL_GPUS - ALLOCATED_GPUS))

if (( TOTAL_GPUS > 0 )); then
    ALLOCATION_PERCENT="$(
        awk "BEGIN {printf \"%.1f\", ($ALLOCATED_GPUS / $TOTAL_GPUS) * 100}"
    )"
else
    ALLOCATION_PERCENT="0.0"
fi

# ==============================================================================
# GPU Model Totals
# ==============================================================================

T4_GPUS="$(
    jq '
        [
            .items[]
            | select(.metadata.labels["nvidia.com/gpu.product"] == "Tesla-T4")
            | .status.allocatable["nvidia.com/gpu"]
            | tonumber
        ]
        | add // 0
    ' <<< "$NODES_JSON"
)"

A4500_GPUS="$(
    jq '
        [
            .items[]
            | select(.metadata.labels["nvidia.com/gpu.product"] == "NVIDIA-RTX-A4500")
            | .status.allocatable["nvidia.com/gpu"]
            | tonumber
        ]
        | add // 0
    ' <<< "$NODES_JSON"
)"

# ==============================================================================
# Header
# ==============================================================================

print_header

printf 'Generated: %s\n' "$REPORT_DATE"

# ==============================================================================
# Cluster Summary
# ==============================================================================

section "CLUSTER SUMMARY"

printf '  %-25s : %s\n' "GPU Nodes" "$TOTAL_NODES"
printf '  %-25s : %s\n' "Total GPUs" "$TOTAL_GPUS"
printf '  %-25s : %s\n' "Allocated GPUs" "$ALLOCATED_GPUS"
printf '  %-25s : %s\n' "Available GPUs" "$AVAILABLE_GPUS"
printf '  %-25s : %s%%\n' "GPU Allocation" "$ALLOCATION_PERCENT"
printf '  %-25s : %s GPUs\n' "Tesla T4" "$T4_GPUS"
printf '  %-25s : %s GPUs\n' "NVIDIA RTX A4500" "$A4500_GPUS"

# ==============================================================================
# GPU Node Status
# ==============================================================================

section "GPU NODE STATUS"

printf '%-32s %-20s %-12s %-12s %-8s %-10s %-10s %-6s %-6s %-10s %-8s\n' \
    "NODE" \
    "GPU MODEL" \
    "ALLOCATED" \
    "MEMORY/GPU" \
    "COMPUTE" \
    "DRIVER" \
    "CUDA" \
    "MIG" \
    "MPS" \
    "SHARING" \
    "MODE"

printf '%s\n' \
    '────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────'

while IFS=$'\t' read -r \
    node \
    model \
    total \
    memory \
    compute_major \
    compute_minor \
    driver \
    cuda \
    mig \
    mps \
    sharing \
    mode; do

    allocated="$(
        jq --arg node "$node" '
            [
                .items[]
                | select(.spec.nodeName == $node)
                | [
                    .spec.containers[]
                    | (.resources.limits["nvidia.com/gpu"] // 0)
                    | tonumber
                ]
                | add
            ]
            | add // 0
        ' <<< "$PODS_JSON"
    )"

    memory_gib="$(
        awk "BEGIN {printf \"%.1f GiB\", $memory / 1024}"
    )"

    compute="${compute_major}.${compute_minor}"

    printf '%-32s %-20s %-12s %-12s %-8s %-10s %-10s %-6s %-6s %-10s %-8s\n' \
        "$node" \
        "$model" \
        "${allocated}/${total}" \
        "$memory_gib" \
        "$compute" \
        "$driver" \
        "$cuda" \
        "$mig" \
        "$mps" \
        "$sharing" \
        "$mode"

done < <(
    jq -r '
        .items[]
        | [
            .metadata.name,
            .metadata.labels["nvidia.com/gpu.product"],
            (.status.allocatable["nvidia.com/gpu"] | tonumber),
            (.metadata.labels["nvidia.com/gpu.memory"] | tonumber),
            .metadata.labels["nvidia.com/gpu.compute.major"],
            .metadata.labels["nvidia.com/gpu.compute.minor"],
            .metadata.labels["nvidia.com/cuda.driver-version.full"],
            .metadata.labels["nvidia.com/cuda.runtime-version.full"],
            (.metadata.labels["nvidia.com/mig.capable"] // "false"),
            (.metadata.labels["nvidia.com/mps.capable"] // "false"),
            (.metadata.labels["nvidia.com/gpu.sharing-strategy"] // "none"),
            .metadata.labels["nvidia.com/gpu.mode"]
        ]
        | @tsv
    ' <<< "$NODES_JSON"
)

# ==============================================================================
# GPU Pod Allocation
# ==============================================================================

section "GPU POD ALLOCATION"

printf '%-30s %-45s %-28s %-20s %-5s\n' \
    "NAMESPACE" \
    "POD" \
    "NODE" \
    "GPU MODEL" \
    "GPU"

printf '%s\n' \
    '────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────'

NODE_GPU_MODELS_JSON="$(
    jq '
        [
            .items[]
            | {
                key: .metadata.name,
                value: (.metadata.labels["nvidia.com/gpu.product"] // "unknown")
            }
        ]
        | from_entries
    ' <<< "$NODES_JSON"
)"

jq -r '
    .items[]
    | select(.spec.nodeName != null)
    | [
        .metadata.namespace,
        .metadata.name,
        .spec.nodeName,
        (
            [
                .spec.containers[]
                | (.resources.limits["nvidia.com/gpu"] // 0)
                | tonumber
            ]
            | add
        )
    ]
    | select(.[3] > 0)
    | @tsv
' <<< "$PODS_JSON" |
while IFS=$'\t' read -r namespace pod node gpu; do

    if (( ${#pod} > 45 )); then
        pod="${pod:0:42}..."
    fi

    gpu_model="$(
        jq -r --arg node "$node" '.[$node] // "unknown"' <<< "$NODE_GPU_MODELS_JSON"
    )"

    printf '%-30s %-45s %-28s %-20s %-5s\n' \
        "$namespace" \
        "$pod" \
        "$node" \
        "$gpu_model" \
        "$gpu"

done

# ==============================================================================
# GPU Model Summary
# ==============================================================================

section "GPU MODEL SUMMARY"

printf '%-25s %-10s %-10s %-12s %-12s %-12s\n' \
    "GPU MODEL" \
    "NODES" \
    "TOTAL" \
    "ALLOCATED" \
    "AVAILABLE" \
    "ALLOCATED %"

printf '%s\n' \
    '────────────────────────────────────────────────────────────────────────────────────'

calculate_model_allocation() {
    local model="$1"
    local total=0

    while read -r node; do

        local allocated

        allocated="$(
            jq --arg node "$node" '
                [
                    .items[]
                    | select(.spec.nodeName == $node)
                    | [
                        .spec.containers[]
                        | (.resources.limits["nvidia.com/gpu"] // 0)
                        | tonumber
                    ]
                    | add
                ]
                | add // 0
            ' <<< "$PODS_JSON"
        )"

        total=$((total + allocated))

    done < <(
        jq -r --arg model "$model" '
            .items[]
            | select(.metadata.labels["nvidia.com/gpu.product"] == $model)
            | .metadata.name
        ' <<< "$NODES_JSON"
    )

    echo "$total"
}

# ------------------------------------------------------------------------------
# Tesla T4
# ------------------------------------------------------------------------------

T4_NODES="$(
    jq '
        [
            .items[]
            | select(.metadata.labels["nvidia.com/gpu.product"] == "Tesla-T4")
        ]
        | length
    ' <<< "$NODES_JSON"
)"

T4_ALLOCATED="$(calculate_model_allocation "Tesla-T4")"
T4_AVAILABLE=$((T4_GPUS - T4_ALLOCATED))

if (( T4_GPUS > 0 )); then
    T4_PERCENT="$(
        awk "BEGIN {printf \"%.1f\", ($T4_ALLOCATED / $T4_GPUS) * 100}"
    )"
else
    T4_PERCENT="0.0"
fi

printf '%-25s %-10s %-10s %-12s %-12s %-12s\n' \
    "Tesla T4" \
    "$T4_NODES" \
    "$T4_GPUS" \
    "$T4_ALLOCATED" \
    "$T4_AVAILABLE" \
    "${T4_PERCENT}%"

# ------------------------------------------------------------------------------
# RTX A4500
# ------------------------------------------------------------------------------

A4500_NODES="$(
    jq '
        [
            .items[]
            | select(.metadata.labels["nvidia.com/gpu.product"] == "NVIDIA-RTX-A4500")
        ]
        | length
    ' <<< "$NODES_JSON"
)"

A4500_ALLOCATED="$(calculate_model_allocation "NVIDIA-RTX-A4500")"
A4500_AVAILABLE=$((A4500_GPUS - A4500_ALLOCATED))

if (( A4500_GPUS > 0 )); then
    A4500_PERCENT="$(
        awk "BEGIN {printf \"%.1f\", ($A4500_ALLOCATED / $A4500_GPUS) * 100}"
    )"
else
    A4500_PERCENT="0.0"
fi

printf '%-25s %-10s %-10s %-12s %-12s %-12s\n' \
    "RTX A4500" \
    "$A4500_NODES" \
    "$A4500_GPUS" \
    "$A4500_ALLOCATED" \
    "$A4500_AVAILABLE" \
    "${A4500_PERCENT}%"

printf '%s\n' \
    '────────────────────────────────────────────────────────────────────────────────────'

# ------------------------------------------------------------------------------
# Total
# ------------------------------------------------------------------------------

printf '%-25s %-10s %-10s %-12s %-12s %-12s\n' \
    "TOTAL" \
    "$TOTAL_NODES" \
    "$TOTAL_GPUS" \
    "$ALLOCATED_GPUS" \
    "$AVAILABLE_GPUS" \
    "${ALLOCATION_PERCENT}%"

# ==============================================================================
# Footer
# ==============================================================================

echo

printf '%b\n' \
    "${DIM}Note: GPU allocation reflects Kubernetes resource reservations.${RESET}"

printf '%b\n' \
    "${DIM}Actual GPU utilization requires NVIDIA SMI or DCGM metrics.${RESET}"

echo
