#!/usr/bin/env bash

CACHE="${XDG_CACHE_DIR:-$HOME/.cache}/nextshot"
pruned=0
skipped=0

for img in ~/nextcloud/apitest/*.{png,jpg}; do
    filename=$(basename "$img")

    if [[ -f "${CACHE}/${filename}" ]]; then
        [[ "$1" == "-v" ]] && echo "Pruning ${filename}"
        pruned=$((pruned+1))
    else
        [[ "$1" == "-v" ]] && echo "Skipped ${filename}"
        skipped=$((skipped+1))
    fi
done

echo "Pruned ${pruned} and skipped ${skipped} files."
