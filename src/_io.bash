# shellcheck disable=SC2009
is_interactive() {
    ps -o stat= -p $$ | grep -q '+'
}

send_notification() {
    if has notify-send; then
        notify-send -u normal -t 5000 -i insert-link NextShot \
            "${1:-"<a href=\"$url\">Your link</a> is ready to paste!"}"
    fi
    echo "${1:-"Copied $url to clipboard. Paste away!"}"
}
