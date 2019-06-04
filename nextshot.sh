#!/usr/bin/env bash
#
# Nextshot - A simple screenshot utility for Linux
# Copyright (C) 2019  Dave Shoreman <aur+nextshot at dsdev dot io>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

set -Eeo pipefail

trap 'echo -e "\nAborted due to error" && exit 1' ERR
trap 'echo -e "\nAborted by user" && exit 1' SIGINT

readonly _CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"
readonly _CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
readonly _RUNTIME_DIR="${XDG_RUNTIME_DIR:-"/tmp"}/nextshot"
readonly _CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"
readonly _TRAY_FIFO="$_RUNTIME_DIR/traymenu"
readonly _VERSION="1.1.0"

usage() {
    echo "Usage:"
    echo "  nextshot [OPTION]"
    echo
    echo "General Options:"
    echo "  -D, --deps[=TYPE] List dependency statuses and exit"
    echo "  --env=ENV         Override environment detection"
    echo "  -h, --help        Display this help and exit"
    echo "  -t, --tray        Start the NextShot tray menu"
    echo "  -v, --verbose     Enable verbose output for debugging"
    echo "  -V, --version     Output version information and exit"
    echo
    echo "Screenshot Modes:"
    echo
    echo " Use these options to take a new screenshot and have"
    echo " NextShot automatically upload it to Nextcloud."
    echo
    echo "  -a, --area        Capture only the selected area"
    echo "  -f, --fullscreen  Capture the entire X/Wayland display"
    echo "  -w, --window      Capture a single window"
    echo "  -d, --delay=NUM   Pause for NUM seconds before capture"
    echo
    echo "Upload Modes:"
    echo
    echo " Use these options when you have an existing image"
    echo " that you want to upload to Nextcloud."
    echo
    echo "  --file FILE       Upload from the local filesystem"
    echo "  -p, --paste       Upload from the system clipboard"
    echo
    echo "Output Modes:"
    echo
    echo " These options can be used in addition to one of the"
    echo " aforementioned Screenshot or Upload Modes. If none"
    echo " are used, the default is to upload to Nextcloud."
    echo
    echo "  -c, --clipboard   Copy the captured image to clipboard"
    echo; echo
    echo "The TYPE argument of -D, --deps can be one of 'g' or 'global,"
    echo "'w' or 'wayland', 'x' or 'x11', 'a' or 'all', or omitted for"
    echo "auto. When TYPE is set to 'global', it will only list the"
    echo "global dependencies. Setting it to 'wayland' or 'x11' will"
    echo "list both the global dependencies and those of the respective"
    echo "environment, whereas 'all' will list global, Wayland *and* X11"
    echo "dependencies. When omitted, dependencies are listed based on"
    echo "the currently active environment as detected by Nextshot."
    echo "Note that TYPE is case-insensitive. -DA is the same as -Da."
    echo; echo
    echo "The --env flag affects the tools used to take screenshots."
    echo "ENV can be one of 'w', 'wl' or 'wayland' to force Wayland"
    echo "mode; 'x' or 'x11' to force X11; 'auto' or left blank to"
    echo "use the builtin automatic environment detection."
    echo
}

nextshot() {
    local debug=false image filename json url
    output_mode="nextcloud"

    sanity_check && setup
    parse_opts "$@"
    parse_environment
    load_config

    image=$(cache_image)

    if [ "$output_mode" = "clipboard" ]; then
        echo "Copying image to clipboard..."
        to_clipboard image < "$_CACHE_DIR/$image" && \
            send_notification "Your image is ready to paste!"
    else
        filename="$(echo "$image" | nc_upload)"

        json=$(nc_share "$filename")
        url="$(echo "$json" | make_url)"

        echo "$url" | to_clipboard && send_notification
    fi
}

tray_menu() {
    if [ -f "$_TRAY_FIFO.pid" ] && ps -p "$(<"$_TRAY_FIFO.pid")" > /dev/null 2>&1
    then
        echo "NextShot tray menu is already running!" >&2
        exit 1
    fi

    load_config && local files_url="$server/apps/files/?dir=/$savedir"

    echo "Starting Nextshot tray menu..." >&2
    rm -f "$_TRAY_FIFO"; mkfifo "$_TRAY_FIFO" && exec 3<> "$_TRAY_FIFO"

    yad --notification --listen --no-middle --command="nextshot -a" <&3 &
    local traypid=$!
    echo $traypid > "$_RUNTIME_DIR/traymenu.pid"

    echo "menu:\
Open Nextcloud      ! xdg-open $files_url !emblem-web||\
Capture area        ! nextshot -a         !window-maximize-symbolic|\
Capture window      ! nextshot -w         !window-new|\
Capture full screen ! nextshot -f         !view-fullscreen-symbolic||\
Paste from Clipboard! nextshot -p         !edit-paste-symbolic||\
Quit Nextshot       ! kill $traypid       !gtk-quit" >&3

    echo "icon:camera-photo-symbolic" >&3
    echo "tooltip:Nextshot" >&3
}

sanity_check() {
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

setup() {
    [ -d "$_CONFIG_DIR" ] || mkdir -p "$_CONFIG_DIR"
    [ -d "$_CACHE_DIR" ] || mkdir -p "$_CACHE_DIR"
    [ -d "$_RUNTIME_DIR" ] || mkdir -p "$_RUNTIME_DIR"

    if [ ! -f "$_CONFIG_FILE" ]; then
        if ! has yad; then
            config_cli
        else
            config_gui
        fi

        config_complete
    fi
}

parse_opts() {
    local -r OPTS=D::htvVawd:fpc
    local -r LONG=deps::,dependencies::,env:,help,tray,verbose,version,area,window,delay:,fullscreen,paste,file:,clipboard
    local parsed

    ! parsed=$(getopt -o "$OPTS" -l "$LONG" -n "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Run 'nextshot --help' for a list of commands."
        exit 2
    fi
    eval set -- "$parsed"

    while true; do
        case "$1" in
            -D|--deps|--dependencies)
                parse_environment
                local chk=${2//=}
                case "${chk,,}" in
                    a|all)
                        chk=a ;;
                    g|global)
                        chk=g ;;
                    w|wayland)
                        chk=w ;;
                    x|x11)
                        chk=x ;;
                    *)
                        is_wayland && chk="w" || chk="x" ;;
                esac
                status_check "$chk" && exit 0 ;;
            --env)
                NEXTSHOT_ENV=${2//=}
                shift 2 ;;
            -h|--help)
                usage && exit 0 ;;
            -t|--tray)
                if ! has yad; then
                    echo "Yad is required for the NextShot tray icon."
                    echo "Please install yad or run nextshot --help for CLI options."
                    exit 1
                fi

                tray_menu && exit 0 ;;
            -v|--verbose)
                debug=true; echo "Debug mode enabled"; shift ;;
            -V|--version)
                echo "NextShot v${_VERSION}" && exit 0 ;;
            -a|--area)
                mode="selection"; shift ;;
            -f|--fullscreen)
                mode="fullscreen"; shift ;;
            -w|--window)
                mode="window"; shift ;;
            -d|--delay)
                delay=${2//=}; shift 2 ;;
            --file)
                local mimetype

                file="$2"
                mode="file"

                # If file cannot be found here, $mimetype will be the error from `file`
                mimetype="$(file -E --mime-type -b "$file")" || (echo "$mimetype" && exit 1)

                if [ ! "${mimetype:0:6}" = "image/" ]; then
                    echo "Failed MIME check: expected image/*, got '$mimetype'."
                    exit 1
                fi
                shift 2 ;;
            -p|--paste)
                if ! check_clipboard; then
                    echo "Clipboard does not contain an image, aborting."
                    exit 1
                fi
                mode="clipboard"; shift ;;
            -c|--clipboard)
                output_mode="clipboard"; shift ;;
            --)
                shift; break ;;
            *)
                echo "Option '$1' should be valid but couldn't be handled."
                echo "Please submit an issue at https://github.com/dshoreman/nextshot/issues"
                exit 3 ;;
        esac
    done

    : ${mode:=selection}
    echo "Screenshot mode set to $mode"
    echo "Output will be sent to ${output_mode^}"
}

parse_environment() {
    case "${NEXTSHOT_ENV,,}" in
        w|wl|way|wayland)
            NEXTSHOT_ENV=wayland ;;
        x|x11)
            NEXTSHOT_ENV=x11 ;;
        auto|"")
            NEXTSHOT_ENV="$(is_wayland_detected && echo "wayland" || echo "x11")" ;;
        *)
            echo "Invalid environment '${NEXTSHOT_ENV}'. Valid options include 'auto', 'wayland' or 'x11'."
            exit 1 ;;
    esac
}

delay_capture() {
    if [ "$delay" -gt 0 ]; then
        echo "Waiting for ${delay} seconds..." >&2
        sleep "$delay"
    fi
}

has() {
    type "$1" >/dev/null 2>&1 || return 1
}

# shellcheck disable=SC2009
is_interactive() {
    ps -o stat= -p $$ | grep -q '+'
}

is_wayland() {
    [ "$NEXTSHOT_ENV" = "wayland" ]
}

is_wayland_detected() {
    [ -n "${WAYLAND_DISPLAY+x}" ]
}

int2dec() {
    printf '%.2f' "$(echo "$1 / 255" | bc -l)"
}

int2hex() {
    printf '%02x\n' "$1"
}

make_url() {
    local json suffix; read -r json

    if $link_previews; then
        suffix=/preview
    fi

    echo "$server/s/$(echo "$json" | jq -r '.ocs.data.token')${suffix}"
}

status_check() {
    local reqG=(
        "curl curl to interact with Nextcloud"
        "yad  yad  for the tray icon and to display config and rename windows"
    )
    local reqW=(
        "grim           grim         to take screenshots"
        "jq             jq           to list visible windows"
        "slurp          slurp        for area selection"
        "wl-clipboard   wl-clipboard to interact with the clipboard"
    )
    local reqX=(
        "slop   slop        for window and area selection"
        "import imagemagick to take screenshots"
        "xclip  xclip       to interact with the clipboard"
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
    local pkg="$2"; shift 2

    has "$dep" && echo -n " ✔ $pkg" || echo -n " ✘ $pkg"
    echo " -- $*"
}

check_clipboard() {
    local cmd

    if is_wayland; then cmd="wl-paste -l"
    else
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
    local mime

    [ "${1:-text}" = "image" ] && mime="image/png" || mime="text/plain"

    if is_wayland; then wl-copy -t $mime
    else
        xclip -selection clipboard -t $mime
    fi
}

load_config() {
    # shellcheck disable=SC1090
    echo "Loading config from $_CONFIG_FILE..." && . "$_CONFIG_FILE"

    local errmsg="missing required config option."
    : "${server:?$errmsg}" "${username:?$errmsg}" "${password:?$errmsg}" "${savedir:?$errmsg}"

    hlColour="$(parse_colour "${hlColour:-255,100,180}")"
    link_previews=${link_previews:-false}
    link_previews=${link_previews,,}
    rename=${rename:-false}
    rename=${rename,,}
    delay=${delay:-0}

    echo "Config loaded!"
}

parse_colour() {
    local red green blue parts
    IFS="," read -ra parts <<< "$1"

    red="${parts[0]}"
    green="${parts[1]}"
    blue="${parts[2]}"

    if is_wayland; then
        echo "#$(int2hex "$red")$(int2hex "$green")$(int2hex "$blue")"
    else
        echo "$(int2dec "$red"),$(int2dec "$green"),$(int2dec "$blue")"
    fi
}

cache_image() {
    if [ "$mode" = "file" ]; then
        local filename
        filename="$(basename "$file")"

        cp "$file" "$_CACHE_DIR/$filename" && echo "$filename"
    else
        take_screenshot
    fi
}

take_screenshot() {
    local filename filepath

    filename="$(date "+%Y-%m-%d %H.%M.%S").png"
    filepath="$_CACHE_DIR/$filename"

    if [ "$mode" = "clipboard" ]; then
        from_clipboard > "$filepath"
    elif is_wayland; then
        shoot_wayland "$filepath"
    else
        shoot_x "$filepath"
    fi

    attempt_rename "$filename"
}

shoot_wayland() {
    local args

    if [ "$mode" = "selection" ]; then
        args=(-g "$(slurp -d -c "${hlColour}ee" -s "${hlColour}66")")
    elif [ "$mode" = "window" ]; then
        args=(-g "$(select_window)")
    fi

    delay_capture
    grim "${args[@]}" "$1"
}

shoot_x() {
    local args slop

    slop="slop -c $hlColour,0.4 -lb 3"

    if [ "$mode" = "fullscreen" ]; then
        args=(-window root)
    elif [ "$mode" = "selection" ]; then
        args=(-window root -crop "$($slop -f "%g" -t 0)")
    elif [ "$mode" = "window" ]; then
        args=(-window "$($slop -f "%i" -t 999999)")
    fi

    delay_capture
    import "${args[@]}" "$1"
}

attempt_rename() {
    local newname

    if [ "$rename" = true ] && is_interactive; then newname="$(rename_cli "$1")"
    elif [ "$rename" = true ] && has yad; then newname="$(rename_gui "$1")"
    else newname="$1"; fi

    if [ ! "$1" = "$newname" ]; then
        mv "$_CACHE_DIR/$1" "$_CACHE_DIR/$newname"
    fi

    echo "$newname"
}

rename_cli() {
    read -rp "Screenshot saved!\nEnter filename [$1]: " newname
    echo "${newname:-$1}"
}

rename_gui() {
    yad --entry --title "NextShot" --borders=10 --button="gtk-save" --entry-text="$1" \
        --text="<b>Screenshot Saved!</b>\nEnter filename to save to NextCloud:" 2>/dev/null
}

nc_upload() {
    local filename output; read -r filename

    echo "Uploading screenshot..." >&2

    [ $debug = true ] && output="$_CACHE_DIR/curlout" || output=/dev/null
    respCode=$(curl -u "$username":"$password" "$server/remote.php/dav/files/$username/$savedir/$filename" \
        -L --post301 --upload-file "$_CACHE_DIR/$filename" -#o $output -w "%{http_code}")

    if [ "$respCode" -ne 201 ]; then
        echo >&2
        [ $debug = true ] && cat "$_CACHE_DIR/curlout" >&2
        echo "Upload failed. Expected 201 but server returned a $respCode response" >&2 && exit 1
    fi

    echo "$filename"
}

nc_share() {
    curl -u "$username":"$password" -X POST --post301 -sSLH "OCS-APIRequest: true" \
        "$server/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" \
        -F "path=/$savedir/$1" -F "shareType=3"
}

select_window() {
    local windows window choice num max size offset geometries title titles yadlist

    windows=$(swaymsg -t get_tree | jq -r '.. | (.nodes? // empty)[] | select(.visible and .pid) | {name} + .rect | "\(.x),\(.y) \(.width)x\(.height) \(.name)"')
    geometries=()
    yadlist=()
    titles=()

    echo "Found the following visible windows:" >&2
    num=0
    while read -r window; do
        read -r offset size title <<< "$window"
        geometries+=("$offset $size")
        titles+=("$title")

        if is_interactive; then
            echo "[$num] $title" >&2
        else
            yadlist+=("$num" "$title" "$size")
        fi
        ((num+=1))
    done <<< "$windows"

    if is_interactive; then
        select_window_cli
    elif has yad; then
        select_window_gui
    else
        echo "Unable to display window selection. Install Yad or run 'nextshot -w' in a terminal." >&2
        exit 1
    fi

    echo "Selected window $choice: ${titles[$choice]}" >&2
    echo "${geometries[$choice]}"
}

select_window_cli() {
    ((max="$num-1"))
    choice=-1

    while [ $choice -lt 0 ] || [ $choice -gt $max ]; do
        read -r -p "Which window to capture [0-$max]? " choice

        if [ -z "$choice" ] || ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo "Invalid selection. Enter a number between 0 and $max" >&2
            choice=-1
        fi
    done
}

select_window_gui() {
    choice=$(yad --list --print-column=1 --hide-column=1 --column="#:NUM" \
        --width=550 --height=400 --title"NextShot: Select window to capture" \
        --column="Window Title" --column="Dimensions" "${yadlist[@]}") || \
        (echo "Window selection cancelled by user." >&2; exit 1)
    choice=${choice//|}
}

send_notification() {
    if has notify-send; then
        notify-send -u normal -t 5000 -i insert-link NextShot \
            "${1:-"<a href=\"$url\">Your link</a> is ready to paste!"}"
    else
        echo "${1:-"Link $url copied to clipboard. Paste away!"}"
    fi
}

config_cli() {
    echo "Failed to detect Yad, required to display the initial configuration window."
    echo "If you don't wish to install Yad, NextShot can create a basic config for you."
    echo

    read -rn1 -p "Create config for manual editing (y/n)? " answer
    echo

    [ "${answer,,}" = "y" ] || config_abort

    echo -n "Creating config template... "
    config_create && echo "[DONE]"

    echo "Opening config for editing"
    ${EDITOR:-vi} "$_CONFIG_FILE"
}

config_gui() {
    response=$(yad --title "NextShot Configuration" --text="<b>Welcome to NextShot\!</b>

Seems this is your first time running this thing.
Fill out the options below and you'll be taking screenshots in no time:\n" \
        --image="preferences-other" --borders=10 --fixed --quoted-output --form \
        --button="gtk-quit:1" --button="gtk-ok:0" \
        --field="NextCloud Server URL" \
        --field="The root URL of your Nextcloud installation, e.g. https://nc.mydomain.com\n:LBL" \
        --field="Username" \
        --field="App Password:H" \
        --field="To generate an App Password, open your Nextcloud instance.
Under <b>Settings > Personal > Security</b>, enter <i>\"NextShot\"</i> for the App name
and click <b>Create new app password</b>.\n:LBL" \
        --field="Link direct to image instead of Nextcloud UI (appends '/preview'):CHK" \
        --field="Prompt to rename screenshots before upload:CHK" \
        --field="Screenshot Folder" \
        --field="This is where screenshots will be uploaded on Nextcloud, relative to your user root.\n:LBL" \
        "https://" "" "" "" "" false true "Screenshots") || config_abort

    IFS='|' read -r server _ username password _ link_previews rename savedir _ <<< "$response"
    link_previews=${link_previews//\'/}
    link_previews=${link_previews,,}
    rename=${rename//\'/}
    rename=${rename,,}

    config=$(yad --title="NextShot Configuration" --borders=10 --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --button="gtk-cancel:1" --button="gtk-save:0" --width=400 --height=175 --form --field=":TXT" \
        "server=$server\nusername=$username\npassword=$password\nsavedir=$savedir\nlink_previews=$link_previews\nrename=$rename") || config_abort

    sed 's/\\n/\n/g' <<< "$config" > "$_CONFIG_FILE"
}

config_abort() {
    if ! has yad; then
        echo "Either install Yad, or configure NextShot manually."
    fi

    echo "Configuration aborted by user, exiting." >&2
    exit 1
}

config_complete() {
    echo
    echo "Config saved! It can be found in $_CONFIG_FILE"
    echo "If you wish to make further changes, open it in your favourite text editor."
    echo
    echo "You may now run nextshot again to start taking screenshots."

    exit 0
}

config_create() {
    cat << 'EOF' > "$_CONFIG_FILE"
# Your Nextcloud domain or base URL, including http[s]:// but no trailing slash
#  e.g. 'https://nextcloud.example.com' *OR* 'https://example.com/nextcloud'
server=''

# Your Nextcloud username
username=''

# Nextcloud App Password created specifically for NextShot (Settings > Personal > Security)
password=''

# Folder on Nextcloud where screenshots will be uploaded (must already exist)
savedir=''

# When set to true, appends /preview to share links, going straight to the full-size image
link_previews=false

# Whether to prompt for a filename before uploading to Nextcloud
rename=false
EOF
}

nextshot "$@"
