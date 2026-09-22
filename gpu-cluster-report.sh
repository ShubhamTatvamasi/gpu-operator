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
    YELLOW=''
else
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    BLUE=$'\033[96m'
    YELLOW=$'\033[93m'
fi

# ==============================================================================
# Dependency Check
# ==============================================================================

for command in kubectl jq awk curl; do
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
    printf '%b\n' "${BLUE}╔$(printf '═%.0s' $(seq 1 "$inner"))╗${RESET}"
    printf '%b\n' "${BLUE}║$(printf '%*s' "$title_left" '')${BOLD}${title}${RESET}${BLUE}$(printf '%*s' "$title_right" '')║${RESET}"
    printf '%b\n' "${BLUE}║$(printf '%*s' "$subtitle_left" '')${DIM}${subtitle}${RESET}${BLUE}$(printf '%*s' "$subtitle_right" '')║${RESET}"
    printf '%b\n' "${BLUE}╚$(printf '═%.0s' $(seq 1 "$inner"))╝${RESET}"
    printf '\n'
}

section() {
    printf '\n%b\n\n' "${BLUE}┌────────────────────────────── ${1} ──────────────────────────────┐${RESET}"
}

# Renders a TSV table: first line is the header, rest are data rows.
# Column widths are computed from actual content (2-space gutter), so long
# values never desync the columns that follow them.
render_table() {
    awk -F'\t' '
        NR == 1 {
            ncols = NF
            for (i = 1; i <= NF; i++) width[i] = length($i)
            header = $0
            next
        }
        {
            for (i = 1; i <= NF; i++) {
                if (length($i) > width[i]) width[i] = length($i)
            }
            data[++rows] = $0
        }
        END {
            split(header, hdr, FS)
            line = ""
            for (i = 1; i <= ncols; i++) line = line sprintf("%-*s", width[i] + 2, hdr[i])
            print line

            total = 0
            for (i = 1; i <= ncols; i++) total += width[i] + 2
            sep = ""
            for (i = 0; i < total; i++) sep = sep "─"
            print sep

            for (r = 1; r <= rows; r++) {
                split(data[r], cells, FS)
                line = ""
                for (i = 1; i <= ncols; i++) line = line sprintf("%-*s", width[i] + 2, cells[i])
                print line
            }
        }
    '
}

# ==============================================================================
# Collect Kubernetes Data (2 API calls total for all k8s-side data)
# ==============================================================================

SCRATCH_DIR="$(mktemp -d)"
cleanup_scratch_dir() { rm -rf "$SCRATCH_DIR"; }
trap cleanup_scratch_dir EXIT

NODES_FILE="${SCRATCH_DIR}/nodes.json"
PODS_FILE="${SCRATCH_DIR}/pods.json"

kubectl get nodes -l nvidia.com/gpu.present=true -o json > "$NODES_FILE"
kubectl get pods -A -o json > "$PODS_FILE"

# ==============================================================================
# Precompute everything from NODES_JSON / PODS_JSON in single jq passes.
# (No per-row kubectl/jq subprocess spins — this is what made the old script
# slow on multi-node clusters: it re-scanned PODS_JSON once per node/model.)
# ==============================================================================

# One JSON blob with every number we need, computed in one jq invocation.
CLUSTER_JSON="$(
    jq -n --slurpfile nodes_arr "$NODES_FILE" --slurpfile pods_arr "$PODS_FILE" '
        ($nodes_arr[0]) as $nodes | ($pods_arr[0]) as $pods |
        def gpu_req: (.resources.limits["nvidia.com/gpu"] // 0 | tonumber);

        # node -> allocated GPU count (sum of gpu_req across all containers of
        # all pods scheduled onto that node)
        ($pods.items
            | map(select(.spec.nodeName != null))
            | group_by(.spec.nodeName)
            | map({
                key: .[0].spec.nodeName,
                value: ([.[] | .spec.containers[] | gpu_req] | add // 0)
              })
            | from_entries
        ) as $alloc_by_node
        |
        ($nodes.items
            | map({
                key: .metadata.name,
                value: (.metadata.labels["nvidia.com/gpu.product"] // "unknown")
              })
            | from_entries
        ) as $model_by_node
        |
        {
            total_nodes: ($nodes.items | length),
            total_gpus: ([$nodes.items[] | .status.allocatable["nvidia.com/gpu"] | tonumber] | add // 0),
            allocated_gpus: ($alloc_by_node | [.[]] | add // 0),
            models: ([$nodes.items[].metadata.labels["nvidia.com/gpu.product"] // "unknown"] | unique),
            model_by_node: $model_by_node,
            alloc_by_node: $alloc_by_node,
            nodes: [
                $nodes.items[] | {
                    name: .metadata.name,
                    model: (.metadata.labels["nvidia.com/gpu.product"] // "unknown"),
                    total: (.status.allocatable["nvidia.com/gpu"] | tonumber),
                    allocated: ($alloc_by_node[.metadata.name] // 0),
                    memory: (.metadata.labels["nvidia.com/gpu.memory"] | tonumber),
                    compute_major: (.metadata.labels["nvidia.com/gpu.compute.major"] // "?"),
                    compute_minor: (.metadata.labels["nvidia.com/gpu.compute.minor"] // "?"),
                    driver: (.metadata.labels["nvidia.com/cuda.driver-version.full"] // "?"),
                    cuda: (.metadata.labels["nvidia.com/cuda.runtime-version.full"] // "?"),
                    mig: (.metadata.labels["nvidia.com/mig.capable"] // "false"),
                    mps: (.metadata.labels["nvidia.com/mps.capable"] // "false"),
                    sharing: (.metadata.labels["nvidia.com/gpu.sharing-strategy"] // "none"),
                    mode: (.metadata.labels["nvidia.com/gpu.mode"] // "?")
                }
            ],
            model_summary: [
                ($nodes.items | group_by(.metadata.labels["nvidia.com/gpu.product"] // "unknown")[] | {
                    model: (.[0].metadata.labels["nvidia.com/gpu.product"] // "unknown"),
                    node_count: length,
                    total: ([.[] | .status.allocatable["nvidia.com/gpu"] | tonumber] | add // 0),
                    allocated: ([.[] | ($alloc_by_node[.metadata.name] // 0)] | add // 0)
                })
            ],
            gpu_pods: [
                $pods.items[]
                | select(.spec.nodeName != null)
                | . as $pod
                | ($pod.spec.containers[] | select(gpu_req > 0) | {
                    namespace: $pod.metadata.namespace,
                    pod: $pod.metadata.name,
                    node: $pod.spec.nodeName,
                    model: ($model_by_node[$pod.spec.nodeName] // "unknown"),
                    gpu: gpu_req
                  })
            ]
        }
    '
)"

TOTAL_NODES="$(jq -r '.total_nodes' <<< "$CLUSTER_JSON")"
TOTAL_GPUS="$(jq -r '.total_gpus' <<< "$CLUSTER_JSON")"
ALLOCATED_GPUS="$(jq -r '.allocated_gpus' <<< "$CLUSTER_JSON")"
AVAILABLE_GPUS=$((TOTAL_GPUS - ALLOCATED_GPUS))

if (( TOTAL_GPUS > 0 )); then
    ALLOCATION_PERCENT="$(awk "BEGIN {printf \"%.1f\", ($ALLOCATED_GPUS / $TOTAL_GPUS) * 100}")"
else
    ALLOCATION_PERCENT="0.0"
fi

# ==============================================================================
# DCGM Metrics (utilization / memory used / temperature / power)
# ==============================================================================
#
# All exporter pods are port-forwarded and scraped IN PARALLEL (each on its
# own local port), not sequentially — this is what made the old version slow
# on multi-node clusters (10 nodes = 10 serial port-forward+poll cycles).
#
# Produces DCGM_ROWS: one line per physical GPU as
# "node\tgpu_index\tutil_pct\tmem_util_pct\tfb_used_mib\tfb_free_mib\ttemp_c\tpower_w\tnamespace\tpod"

DCGM_ROWS=""
DCGM_SCRAPE_ERRORS=""
DCGM_PF_PIDS=()

cleanup_dcgm_port_forwards() {
    if (( ${#DCGM_PF_PIDS[@]} > 0 )); then
        kill "${DCGM_PF_PIDS[@]}" >/dev/null 2>&1 || true
        wait "${DCGM_PF_PIDS[@]}" 2>/dev/null || true
        DCGM_PF_PIDS=()
    fi
}

trap cleanup_dcgm_port_forwards EXIT

DCGM_EXPORTER_PODS="$(
    jq -r '
        .items[]
        | select(.metadata.name | test("^nvidia-dcgm-exporter-[^-]+$"))
        | select(.status.phase == "Running")
        | "\(.metadata.namespace)\t\(.metadata.name)\t\(.spec.nodeName)"
    ' "$PODS_FILE"
)"

if [[ -n "$DCGM_EXPORTER_PODS" ]]; then
    DCGM_SCRATCH_DIR="${SCRATCH_DIR}/dcgm"
    mkdir -p "$DCGM_SCRATCH_DIR"
    trap 'cleanup_dcgm_port_forwards; cleanup_scratch_dir' EXIT

    port=19400
    i=0

    # Start every port-forward at once.
    while IFS=$'\t' read -r exp_namespace exp_pod exp_node; do
        this_port=$((port + i))
        printf '%s\t%s\t%s\t%s\n' "$exp_node" "$exp_pod" "$exp_namespace" "$this_port" \
            >> "${DCGM_SCRATCH_DIR}/targets.tsv"

        kubectl port-forward -n "$exp_namespace" "pod/${exp_pod}" \
            "${this_port}:9400" >/dev/null 2>&1 &
        DCGM_PF_PIDS+=("$!")

        i=$((i + 1))
    done <<< "$DCGM_EXPORTER_PODS"

    # Scrape all targets in parallel, each writing its own output file. Each
    # job retries on its own (port-forwards take a couple seconds to
    # establish) instead of a separate readiness-polling phase up front —
    # that serialized N curls per poll tick and could stall the whole run.
    scrape_pids=()
    while IFS=$'\t' read -r exp_node exp_pod exp_namespace p; do
        (
            metrics=""
            for _ in $(seq 1 10); do
                metrics="$(curl -s -m 2 "http://localhost:${p}/metrics" 2>/dev/null || true)"
                [[ -n "$metrics" ]] && break
                sleep 0.5
            done
            printf '%s' "$metrics" > "${DCGM_SCRATCH_DIR}/${exp_node//[^A-Za-z0-9]/_}.metrics"
        ) &
        scrape_pids+=("$!")
    done < "${DCGM_SCRATCH_DIR}/targets.tsv"
    wait "${scrape_pids[@]}" 2>/dev/null || true

    cleanup_dcgm_port_forwards

    # Parse every scraped file in one awk pass (per node), building DCGM_ROWS.
    while IFS=$'\t' read -r exp_node exp_pod exp_namespace p; do
        metrics_file="${DCGM_SCRATCH_DIR}/${exp_node//[^A-Za-z0-9]/_}.metrics"

        if [[ -s "$metrics_file" ]]; then
            DCGM_ROWS+="$(
                awk -v node="$exp_node" '
                    function extract(line, key,    v) {
                        v = line
                        sub("^.*" key "=\"", "", v)
                        sub("\".*$", "", v)
                        return v
                    }
                    function value_of(line,    v) {
                        v = line
                        sub(/^.*} /, "", v)
                        return v
                    }
                    /^DCGM_FI_DEV_GPU_UTIL\{/      { g=extract($0,"gpu"); util[g]=value_of($0); gpu_ns[g]=extract($0,"namespace"); gpu_pod[g]=extract($0,"pod"); seen[g]=1 }
                    /^DCGM_FI_DEV_MEM_COPY_UTIL\{/ { g=extract($0,"gpu"); memutil[g]=value_of($0); seen[g]=1 }
                    /^DCGM_FI_DEV_FB_USED\{/       { g=extract($0,"gpu"); fbused[g]=value_of($0); seen[g]=1 }
                    /^DCGM_FI_DEV_FB_FREE\{/       { g=extract($0,"gpu"); fbfree[g]=value_of($0); seen[g]=1 }
                    /^DCGM_FI_DEV_GPU_TEMP\{/      { g=extract($0,"gpu"); temp[g]=value_of($0); seen[g]=1 }
                    /^DCGM_FI_DEV_POWER_USAGE\{/   { g=extract($0,"gpu"); power[g]=value_of($0); seen[g]=1 }
                    END {
                        for (g in seen) {
                            u  = (g in util)    ? util[g]    : "-"
                            mu = (g in memutil) ? memutil[g] : "-"
                            fu = (g in fbused)  ? fbused[g]  : "-"
                            ff = (g in fbfree)  ? fbfree[g]  : "-"
                            t  = (g in temp)    ? temp[g]    : "-"
                            pw = (g in power)   ? power[g]   : "-"
                            ns = (g in gpu_ns)  ? gpu_ns[g]  : ""
                            pd = (g in gpu_pod) ? gpu_pod[g] : ""
                            print node "\t" g "\t" u "\t" mu "\t" fu "\t" ff "\t" t "\t" pw "\t" ns "\t" pd
                        }
                    }
                ' "$metrics_file"
            )"$'\n'
        else
            DCGM_SCRAPE_ERRORS+="${exp_node} (${exp_pod})"$'\n'
        fi
    done < "${DCGM_SCRATCH_DIR}/targets.tsv"

    trap cleanup_scratch_dir EXIT
fi

# node -> claimed GPU indices lookup table, and DCGM row lookup by node+idx.
# (kept in an associative array so the pod-allocation render below is O(1)
# per row instead of an awk subprocess per row)
declare -A DCGM_ROW_BY_NODE_IDX=()
if [[ -n "$DCGM_ROWS" ]]; then
    while IFS=$'\t' read -r node idx rest; do
        [[ -z "$node" ]] && continue
        DCGM_ROW_BY_NODE_IDX["${node}|${idx}"]="$rest"
    done <<< "$DCGM_ROWS"
fi

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

while IFS= read -r model; do
    model_gpus="$(jq -r --arg m "$model" '[.model_summary[] | select(.model == $m) | .total] | add // 0' <<< "$CLUSTER_JSON")"
    printf '  %-25s : %s GPUs\n' "$model" "$model_gpus"
done < <(jq -r '.models[]' <<< "$CLUSTER_JSON")

if [[ -n "$DCGM_ROWS" ]]; then
    ACTIVE_GPU_COUNT="$(awk -F'\t' '$3 != "-" && $3 + 0 > 0 { c++ } END { print c + 0 }' <<< "$DCGM_ROWS")"
    printf '  %-25s : %s\n' "Actively Computing" "$ACTIVE_GPU_COUNT / $TOTAL_GPUS GPUs"
fi

# ==============================================================================
# GPU Node Status
# ==============================================================================

section "GPU NODE STATUS"

{
    if [[ -n "$DCGM_ROWS" ]]; then
        printf 'NODE\tGPU MODEL\tALLOCATED\tMEMORY/GPU\tCOMPUTE\tDRIVER\tCUDA\tMIG\tMPS\tSHARING\tMODE\tAVG TEMP\tAVG POWER\n'
    else
        printf 'NODE\tGPU MODEL\tALLOCATED\tMEMORY/GPU\tCOMPUTE\tDRIVER\tCUDA\tMIG\tMPS\tSHARING\tMODE\n'
    fi

    while IFS=$'\t' read -r node model total allocated memory compute_major compute_minor driver cuda mig mps sharing mode; do
        memory_gib="$(awk "BEGIN {printf \"%.1f GiB\", $memory / 1024}")"
        compute="${compute_major}.${compute_minor}"

        if [[ -n "$DCGM_ROWS" ]]; then
            avg_temp="-"
            avg_power="-"
            temp_sum=0; temp_n=0
            power_sum=0; power_n=0

            for key in "${!DCGM_ROW_BY_NODE_IDX[@]}"; do
                [[ "$key" == "${node}|"* ]] || continue
                IFS=$'\t' read -r _ _ _ _ temp power _ _ <<< "${DCGM_ROW_BY_NODE_IDX[$key]}"
                if [[ "$temp" != "-" ]]; then temp_sum=$(awk "BEGIN{print $temp_sum+$temp}"); temp_n=$((temp_n+1)); fi
                if [[ "$power" != "-" ]]; then power_sum=$(awk "BEGIN{print $power_sum+$power}"); power_n=$((power_n+1)); fi
            done

            (( temp_n > 0 )) && avg_temp="$(awk "BEGIN{printf \"%.0fC\", $temp_sum/$temp_n}")"
            (( power_n > 0 )) && avg_power="$(awk "BEGIN{printf \"%.0fW\", $power_sum/$power_n}")"

            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$node" "$model" "${allocated}/${total}" "$memory_gib" "$compute" \
                "$driver" "$cuda" "$mig" "$mps" "$sharing" "$mode" "$avg_temp" "$avg_power"
        else
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$node" "$model" "${allocated}/${total}" "$memory_gib" "$compute" \
                "$driver" "$cuda" "$mig" "$mps" "$sharing" "$mode"
        fi
    done < <(
        jq -r '
            .nodes[]
            | [.name, .model, .total, .allocated, .memory, .compute_major, .compute_minor, .driver, .cuda, .mig, .mps, .sharing, .mode]
            | @tsv
        ' <<< "$CLUSTER_JSON"
    )
} | render_table

# ==============================================================================
# GPU Pod Allocation
# ==============================================================================

section "GPU POD ALLOCATION"

declare -A NODE_GPU_CLAIMED=()

{
    if [[ -n "$DCGM_ROWS" ]]; then
        printf 'NAMESPACE\tPOD\tNODE\tGPU MODEL\tGPU\tUTIL\tMEM-UTIL\tMEM USED\tTEMP/POWER\n'
    else
        printf 'NAMESPACE\tPOD\tNODE\tGPU MODEL\tGPU\n'
    fi

    while IFS=$'\t' read -r namespace pod node model gpu_count; do
        if [[ -n "$DCGM_ROWS" ]]; then
            claimed="${NODE_GPU_CLAIMED[$node]:-,}"
            match_idx=""

            for key in "${!DCGM_ROW_BY_NODE_IDX[@]}"; do
                [[ "$key" == "${node}|"* ]] || continue
                idx="${key#${node}|}"
                [[ "$claimed" == *",${idx},"* ]] && continue
                match_idx="$idx"
                break
            done

            if [[ -n "$match_idx" ]]; then
                NODE_GPU_CLAIMED["$node"]="${claimed}${match_idx},"
                IFS=$'\t' read -r util mem_util fb_used fb_free temp power _ _ <<< "${DCGM_ROW_BY_NODE_IDX[${node}|${match_idx}]}"

                [[ "$fb_used" != "-" ]] && fb_used="${fb_used} MiB"
                [[ "$util" != "-" ]] && util="${util}%"
                [[ "$mem_util" != "-" ]] && mem_util="${mem_util}%"
                [[ "$temp" != "-" ]] && temp="$(awk "BEGIN{printf \"%.0f\", $temp}")C"
                [[ "$power" != "-" ]] && power="$(awk "BEGIN{printf \"%.0f\", $power}")W"
            else
                util="-"; mem_util="-"; fb_used="-"; temp="-"; power="-"
            fi

            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s/%s\n' \
                "$namespace" "$pod" "$node" "$model" "$gpu_count" \
                "$util" "$mem_util" "$fb_used" "$temp" "$power"
        else
            printf '%s\t%s\t%s\t%s\t%s\n' "$namespace" "$pod" "$node" "$model" "$gpu_count"
        fi
    done < <(
        jq -r '.gpu_pods[] | [.namespace, .pod, .node, .model, .gpu] | @tsv' <<< "$CLUSTER_JSON"
    )
} | render_table

if [[ -z "$DCGM_ROWS" ]]; then
    printf '\n%s\n' "${DIM}(nvidia-dcgm-exporter not found — utilization/memory columns unavailable)${RESET}"
fi

if [[ -n "$DCGM_SCRAPE_ERRORS" ]]; then
    printf '\n%s\n' "${YELLOW}Warning: could not scrape DCGM metrics from:${RESET}"
    while IFS= read -r line; do
        [[ -n "$line" ]] && printf '  %s\n' "$line"
    done <<< "$DCGM_SCRAPE_ERRORS"
fi

# ==============================================================================
# GPU Model Summary
# ==============================================================================

section "GPU MODEL SUMMARY"

{
    printf 'GPU MODEL\tNODES\tTOTAL\tALLOCATED\tAVAILABLE\tALLOCATED %%\n'

    while IFS=$'\t' read -r model node_count total allocated; do
        available=$((total - allocated))
        if (( total > 0 )); then
            percent="$(awk "BEGIN {printf \"%.1f\", ($allocated / $total) * 100}")"
        else
            percent="0.0"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s%%\n' "$model" "$node_count" "$total" "$allocated" "$available" "$percent"
    done < <(jq -r '.model_summary[] | [.model, .node_count, .total, .allocated] | @tsv' <<< "$CLUSTER_JSON")

    printf '%s\t%s\t%s\t%s\t%s\t%s%%\n' "TOTAL" "$TOTAL_NODES" "$TOTAL_GPUS" "$ALLOCATED_GPUS" "$AVAILABLE_GPUS" "$ALLOCATION_PERCENT"
} | render_table

# ==============================================================================
# Footer
# ==============================================================================

echo
printf '%b\n' "${DIM}Note: GPU allocation reflects Kubernetes resource reservations.${RESET}"

if [[ -n "$DCGM_ROWS" ]]; then
    printf '%b\n' "${DIM}UTIL/MEM-UTIL/MEM USED/TEMP/POWER come live from nvidia-dcgm-exporter.${RESET}"
else
    printf '%b\n' "${DIM}Actual GPU utilization requires nvidia-dcgm-exporter (not found in this cluster).${RESET}"
fi
echo
