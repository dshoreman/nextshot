prune_cache() {
    local files response count=0 size

    echo "Checking for cached screenshots more than 30 days old..."
    files="$(find "$_CACHE_DIR" -maxdepth 1 -iname '20*-*-* *.*.*.png' -mtime +30)"

    if [[ "${files}" == "" ]]; then
        echo "[32;1mLooks like the cache is clean![0m"
        echo "Nothing to do, exiting."
        exit
    fi

    count=$(echo "${files}" | wc -l)
    size=$(echo "${files}" | xargs -d '\n' du -ch | grep total$ | cut -f1)

    echo "[33;1mFound ${count} cached images to delete, totalling ${size}![0m"

    read -rp "Continue? [yN] " response
    echo

    if [[ ! "${response,,}" =~ ^(y|yes)$ ]]; then
        echo "Cleanup aborted." && exit 1
    fi

    echo -e "PRUNING! Please wait...\n"
    echo "${files}" | xargs -d '\n' rm -v \
        && echo "[32;1mCache pruning complete![0m" \
        || echo "[31;1mCould not remove some files. Try again?[0m"
}
