#!/usr/bin/env bash


CONFIG="$1/config.json"



wallpaper_path=$(jq -r '.wallpaper_path' "$CONFIG")
cache_path=$(jq -r '.cache_path' "$CONFIG")
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

mkdir -p "$cache_path"

echo "Wallpaper path: $wallpaper_path"
echo "Cache path: $cache_path"

cache_failed=0

while IFS= read -r -d '' img; do
    filename=$(basename "$img")
    out="$cache_path/$filename"

    if [[ -f "$out" && ! "$img" -nt "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"

    extension="${out##*.}"
    temporary="${out%.*}.tmp.$$.${RANDOM}.${extension}"
    (
        if convert "$img" -thumbnail x500 -strip -quality 85 "$temporary" &&
            mv -f -- "$temporary" "$out"; then
            :
        else
            rm -f -- "$temporary"
            exit 1
        fi
    ) &

    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            if ! wait -n; then
                cache_failed=1
            fi
        done
    fi
done < <(find "$wallpaper_path" -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" \
\) -print0)

for pid in $(jobs -rp); do
    if ! wait "$pid"; then
        cache_failed=1
    fi
done

if (( cache_failed )); then
    echo "One or more thumbnails could not be generated." >&2
    exit 1
fi

echo "Thumbnail generation complete."
