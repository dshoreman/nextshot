has() {
    type "$1" >/dev/null 2>&1 || return 1
}

prefers() {
    has "$1" || {
        echo "WARNING: $1 is missing. Some features will not work as expected."
        echo "Run nextshot -D to check for dependencies."
        sleep 1
    } >&2
}

requires() {
    has "$1" || {
        echo -e "ERROR: $1 is required to continue."
        echo "Run nextshot -D to check for dependencies."
        exit 1
    } >&2
}

status_check() {
    local reqG=(
        "curl curl to interact with Nextcloud"
        "jq   jq   to get share links, and (on Wayland) list visible windows"
        "yad  yad  for the tray icon and to display config and rename windows"
    )
    local reqW=(
        "grim           grim         to take screenshots"
        "slurp          slurp        for area selection"
        "wl-copy        wl-clipboard to interact with the clipboard"
    )
    local reqX=(
        "import imagemagick to take screenshots"
        "slop   slop        for window and area selection"
        "xclip  xclip       to interact with the clipboard"
        "bc     bc          for colour conversions in config"
    )

    echo
    echo "Current version: Nextshot v${_VERSION}"
    echo -n "Detected environment: "
    is_wayland_detected && echo "Wayland" || echo "X11"
    echo "Active environment: ${NEXTSHOT_ENV^}"
    echo

    echo "Global dependencies"; check_deps "${reqG[@]}"; echo
    [ "$1" = "g" ] && exit 0

    if [ "$1" = "a" ] || [ "$1" = "w" ]; then
        echo "Wayland dependencies"; check_deps "${reqW[@]}"; echo
    fi

    if [ "$1" = "a" ] || [ "$1" = "x" ]; then
        echo "X11 dependencies"; check_deps "${reqX[@]}"; echo
    fi
}

check_deps() {
    local dep

    for dep in "$@"; do
        read -ra dep <<<"$dep"
        check_dep "${dep[@]}"
    done
}

check_dep() {
    local cmd="$1" pkg="$2"; shift 2

    has "$cmd" && echo -n " ✔ $pkg" || echo -n " ✘ $pkg"
    echo " -- $*"
}
