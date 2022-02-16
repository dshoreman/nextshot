check_clipboard() {
    local cmd

    if is_wayland; then
        requires wl-paste
        cmd="wl-paste -l"
    else
        requires xclip
        cmd="xclip -selection clipboard -o -t TARGETS"
    fi

    $cmd | grep image > /dev/null
}

from_clipboard() {
    if is_wayland; then wl-paste -t image/png
    else
        xclip -selection clipboard -t image/png -o
    fi
}

to_clipboard() {
    local mime="text/plain"

    if [ "${1:-text}" = "image" ]; then
        is_jpeg && mime="image/jpeg" || mime="image/png"
    fi

    if is_wayland; then
        requires wl-copy
        wl-copy -t $mime
    else
        requires xclip
        if [ "${mime}" == "text/plain" ]; then
            xclip -selection clipboard
        else
            xclip -selection clipboard -t "${mime}"
        fi
    fi
}
