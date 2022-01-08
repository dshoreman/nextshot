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
    local pruned=0 copied=0 image

    [ -d "${NC_IMAGE_DIR}" ] || err "Nextcloud image directory does not exist.\nTried: ${NC_IMAGE_DIR}"
    pushd "${NS_CACHE_DIR}" >/dev/null || err "Nextshot cache directory does not exist.\nTried: ${NS_CACHE_DIR}"

    for image in *.{jpg,png}; do
        process_image
    done

    echo "Pruned ${pruned} and copied ${copied} files."
    popd>/dev/null || exit
}

process_image() {
    if [[ -f "${NC_IMAGE_DIR}/$(basename "$image")" ]]; then
        prune "$image"
    else
        relocate "$image"
    fi
}

prune() {
    debug "$1 - Synced! - Pruning..."
    [ -z $DRYRUN ] && rm "${NC_IMAGE_DIR}/$1"
    pruned=$((pruned+1))
}

relocate() {
    debug "$1 - MISSING - Copying into Nextcloud screenshots dir..."
    [ -z $DRYRUN ] && cp "${NS_CACHE_DIR}/$1" "${NC_IMAGE_DIR}/$1"
    copied=$((copied+1))
}

main
