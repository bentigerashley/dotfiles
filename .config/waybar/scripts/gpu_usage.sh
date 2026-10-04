#!/usr/bin/env bash

# Prefer the NVIDIA driver query when an NVIDIA GPU is available.  Keep the
# bar alive on systems without one rather than failing on a machine-specific
# nvtop/jq pipeline.
if command -v nvidia-smi >/dev/null 2>&1; then
    utilization="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)"
    if [[ "$utilization" =~ ^[0-9]+$ ]]; then
        printf '%s%%\n' "$utilization"
        exit 0
    fi
fi

printf 'N/A\n'
