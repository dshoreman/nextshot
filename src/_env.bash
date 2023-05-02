[ "$(basename -- "$0")" = "_env.bash" ] && ${debug:?}

check_bash_version() {
    ! getopt -T > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo "Enhanced getopt is not available. Aborting."
        exit 1
    fi

    if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
        echo "Your version of Bash is ${BASH_VERSION} but NextShot requires at least v4."
        exit 1
    fi
}

parse_environment() {
    local method="manually"
    case "${NEXTSHOT_ENV,,}" in
        w|wl|way|wayland)
            NEXTSHOT_ENV=wayland ;;
        x|x11)
            NEXTSHOT_ENV=x11 ;;
        auto|"")
            method="automatically"
            NEXTSHOT_ENV="$(is_wayland_detected && echo "wayland" || echo "x11")" ;;
        *)
            echo "Invalid environment '${NEXTSHOT_ENV}'. Valid options include 'auto', 'wayland' or 'x11'."
            exit 1 ;;
    esac
    if [ "$debug" = true ]; then
        echo "Environment $method set to ${NEXTSHOT_ENV}"
    fi
}

is_wayland() {
    [ "$NEXTSHOT_ENV" = "wayland" ]
}

is_wayland_detected() {
    [ -n "${WAYLAND_DISPLAY+x}" ]
}
