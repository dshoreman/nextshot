#!/usr/bin/env bash

[[ "$1" == "-d" ]] || [[ "$2" == "-d" ]] && DRYRUN=1
[[ "$1" == "-v" ]] || [[ "$2" == "-v" ]] && DEBUG=1

NC_ROOT=${NC_ROOT:-$HOME/nextcloud}
NC_IMAGE_DIR=$NC_ROOT/${NC_IMAGE_DIR:-Screenshots}
NS_CACHE_DIR=${XDG_CACHE_DIR:-$HOME/.cache}/nextshot

debug() {
    [ -z $DEBUG ] || echo "[DEBUG] $*"
}

err() {
    echo -e "[ERROR] $*" && exit 1
}

main() {
    local copied=0 skipped=0 pruned=0 image

    [ -d "${NC_IMAGE_DIR}" ] || err "Nextcloud image directory does not exist.\nTried: ${NC_IMAGE_DIR}"
    pushd "${NS_CACHE_DIR}" >/dev/null || err "Nextshot cache directory does not exist.\nTried: ${NS_CACHE_DIR}"

    for image in *.{jpg,png}; do
        process_image
    done

    summarise && popd>/dev/null || exit
}

process_image() {
    if [[ -f "${NC_IMAGE_DIR}/$(basename "$image")" ]]; then
        prune "$image"
    else
        relocate "$image"
    fi
}

prune() {
    if diff "${NS_CACHE_DIR}/$1" "${NC_IMAGE_DIR}/$1" >/dev/null; then
        debug "$1 - Synced! - Pruning..."
        [ -z $DRYRUN ] && rm "${NC_IMAGE_DIR}/$1"
        pruned=$((pruned+1))
    else
        debug "$1 - SKIPPED - Nextcloud copy exists but does not match."
        skipped=$((skipped+1))
    fi
}

relocate() {
    debug "$1 - MISSING - Copying into Nextcloud screenshots dir..."
    [ -z $DRYRUN ] && cp "${NS_CACHE_DIR}/$1" "${NC_IMAGE_DIR}/$1"
    copied=$((copied+1))
}

summarise() {
    cat << EOF

    Cache sync complete!

    In all, there were:
        ${pruned} images removed that already exist in Nextcloud
        ${copied} images copied that were previously missing
        ${skipped} images skipped due to conflicts

    Run this script again to remove any lingering images once
    you've confirmed the newly-copied files have been synced.

EOF
}

main
