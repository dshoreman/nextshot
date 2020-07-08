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
# ---
# shellcheck disable=SC2251
# The '!'s in getopt commands are intended to bypass errexit when
# it fails, otherwise we can't check for invalid args afterwards.

set -Eeo pipefail

trap 'echo -e "\nAborted due to error" && exit 1' ERR
trap 'echo -e "\nAborted by user" && exit 1' SIGINT

readonly _CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"
readonly _CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
readonly _RUNTIME_DIR="${XDG_RUNTIME_DIR:-"/tmp"}/nextshot"
readonly _CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"
readonly _TRAY_FIFO="$_RUNTIME_DIR/traymenu"
readonly _VERSION="1.3.2"

usage() {
    echo "Usage:"
    echo "  nextshot [OPTION]"
    echo
    echo "General Options:"
    echo "  -D, --deps[=TYPE] List dependency statuses and exit"
    echo "  --env=ENV         Override environment detection"
    echo "  -h, --help        Display this help and exit"
    echo "  -t, --tray        Start the NextShot tray menu"
    echo "  --prune-cache     Clean up the screenshot cache"
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
    echo "  -F, --format=FMT  Save image as FMT instead of the default"
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
        url="$(echo "$json" | make_share_url)"

        echo "$url" | to_clipboard && send_notification
    fi
}

tray_menu() {
    if [ -f "$_TRAY_FIFO.pid" ] && ps -p "$(<"$_TRAY_FIFO.pid")" > /dev/null 2>&1
    then
        echo "NextShot tray menu is already running!" >&2
        exit 1
    fi

    load_config
    echo "Starting Nextshot tray menu..." >&2
    rm -f "$_TRAY_FIFO"; mkfifo "$_TRAY_FIFO" && exec 3<> "$_TRAY_FIFO"

    yad --notification --listen --no-middle --command="nextshot -a" <&3 &
    local files_url traypid=$!
    echo $traypid > "$_RUNTIME_DIR/traymenu.pid"
    files_url="$(make_url "/apps/files/?dir=/${savedir}")"

    echo "menu:\
Open Nextcloud      ! xdg-open $files_url !emblem-web||\
Capture area        ! nextshot -a         !window-maximize-symbolic|\
Capture window      ! nextshot -w         !window-new|\
Capture full screen ! nextshot -f         !view-fullscreen-symbolic||\
Paste from Clipboard! nextshot -p         !edit-paste-symbolic||\
Quit Nextshot       ! kill $traypid       !application-exit" >&3

    echo "icon:nextshot-16x16" >&3
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
    local -r OPTS=D::htvVawd:F:fpc
    local -r LONG=deps::,dependencies::,env:,help,tray,prune-cache,verbose,version,area,window,delay:,format:,fullscreen,paste,file:,clipboard
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
            --prune-cache)
                prune_cache && exit 0 ;;
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
            -F|--format)
                cliFormat=${2//=}
                if ! is_format "${cliFormat}"; then
                    echo "WARNING: Invalid image format '${cliFormat}', default will be set from config."
                fi
                shift 2 ;;
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
    if [ $debug = true ]; then
        echo "Screenshot mode set to $mode"
        echo "Output will be sent to ${output_mode^}"
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
    if [ $debug = true ]; then
        echo "Environment $method set to ${NEXTSHOT_ENV}"
    fi
}

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

delay_capture() {
    if [ "$delay" -gt 0 ]; then
        echo "Pausing for ${delay} seconds..." >&2
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

is_format() {
    [[ "${1,,}" =~ ^png|jpe?g$ ]]
}

is_jpeg() {
    [[ "${format}" =~ ^jpe?g$ ]]
}

is_wayland() {
    [ "$NEXTSHOT_ENV" = "wayland" ]
}

is_wayland_detected() {
    [ -n "${WAYLAND_DISPLAY+x}" ]
}

int2dec() {
    LC_NUMERIC=C printf '%.2f' "$(echo "$1 / 255" | bc -l)"
}

int2hex() {
    LC_NUMERIC=C printf '%02x\n' "$1"
}

make_share_url() {
    local json suffix; read -r json

    if $link_previews; then
        suffix=/preview
    fi
    make_url "/s/$(echo "${json}" | jq -r '.ocs.data.token')${suffix}"
}

make_url() {
    if [ "${*:0:1}" = "/" ] && ! $pretty_urls; then
        echo "${server}/index.php${*}"
    else
        echo "${server}/${*}"
    fi
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
    local cmd="$1" pkg="$2"; shift 2

    has "$cmd" && echo -n " ✔ $pkg" || echo -n " ✘ $pkg"
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

    [ "${1:-text}" = "image" ] && (
        is_jpeg && mime="image/jpeg" || mime="image/png"
    ) || mime="text/plain"

    if is_wayland; then wl-copy -t $mime
    elif [ "${mime}" == "text/plain" ]; then
        xclip -selection clipboard
    else
        xclip -selection clipboard -t $mime
    fi
}

load_config() {
    [ $debug = true ] && echo -e "\nLoading config from $_CONFIG_FILE..."
    # shellcheck disable=SC1090
    . "$_CONFIG_FILE"

    local errmsg="missing required config option."
    : "${server:?$errmsg}" "${username:?$errmsg}" "${password:?$errmsg}" "${savedir:?$errmsg}"
    [ $debug = true ] && echo "Uploading to /${savedir} as ${username} on Nextcloud instance ${server}"

    hlColour="$(parse_colour "${hlColour:-255,100,180}")"
    link_previews=${link_previews:-false}
    link_previews=${link_previews,,}
    pretty_urls=${pretty_urls:-true}
    pretty_urls=${pretty_urls,,}
    rename=${rename:-false}
    rename=${rename,,}
    delay=${delay:-0}

    if is_format "${cliFormat}"; then
        format="${cliFormat,,}"
    else
        is_format "${format}" && format="${format,,}" || format="png"
    fi

    if [ $debug = true ]; then
        echo -e "\nParsed config:"
        echo "  delay: ${delay}"
        echo "  format: ${format}"
        echo "  rename: ${rename}"
        echo "  hlColour: ${hlColour}"
        echo "  link_previews: ${link_previews}"
        echo -e "  pretty_urls: ${pretty_urls}\n"
    fi
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
        local cmd filename
        filename="$(basename "$file")"

        [ $debug = true ] && cmd="cp -v" || cmd="cp"
        $cmd "$file" "$_CACHE_DIR/$filename" >&2 && echo "$filename"
    else
        take_screenshot
    fi
}

take_screenshot() {
    local filename filepath shoot

    filename="$(date "+%Y-%m-%d %H.%M.%S").${format}"
    filepath="$_CACHE_DIR/$filename"

    if [ "$mode" = "clipboard" ]; then
        from_clipboard > "$filepath"
    else
        is_wayland && shoot="shoot_wayland" || shoot="shoot_x"

        echo "Waiting for selection..." >&2
        $shoot "$filepath"
    fi

    attempt_rename "$filename"
}

shoot_wayland() {
    local args windows

    if [ "$mode" = "selection" ]; then
        args=(-g "$(slurp -d -c "${hlColour}ee" -s "${hlColour}66")")
    elif [ "$mode" = "window" ]; then
        windows="$(swaymsg -t get_tree | jq -r '.. | select(.visible? and .pid?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')"
        args=(-g "$(slurp -d -c "${hlColour}ee" -s "${hlColour}66" <<< "${windows}")")
    fi

    is_jpeg && args+=(-t jpeg) || args+=(-t png)

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
    local cmd newname

    if [ "$rename" = true ] && is_interactive; then newname="$(rename_cli "$1")"
    elif [ "$rename" = true ] && has yad; then newname="$(rename_gui "$1")"
    else newname="$1"; fi

    if [ ! "$1" = "$newname" ]; then
        [ $debug = true ] && cmd="mv -v" || cmd="mv"
        $cmd "$_CACHE_DIR/$1" "$_CACHE_DIR/$newname" >&2
    fi

    echo "$newname"
}

rename_cli() {
    echo "Screenshot saved!" >&2
    read -rp "Enter filename [$1]: " newname
    echo "${newname:-$1}"
}

rename_gui() {
    yad --entry --title "NextShot" --borders=10 --button="Save!document-save" --entry-text="$1" \
        --text="<b>Screenshot Saved!</b>\nEnter filename to save to NextCloud:" 2>/dev/null
}

nc_upload() {
    local filename output respCode reqUrl url; read -r filename

    echo -e "\nUploading screenshot..." >&2

    reqUrl="$(make_url "remote.php/dav/files/${username}/${savedir}/${filename// /%20}")"
    [ $debug = true ] && output="$_CACHE_DIR/curlout" || output=/dev/null
    [ $debug = true ] && echo "Sending request to ${reqUrl}..." >&2

    respCode=$(curl -u "$username":"$password" "$reqUrl" \
        -L --post301 --upload-file "$_CACHE_DIR/$filename" -#o $output -w "%{http_code}")

    if [ "$respCode" = 204 ]; then
        [ $debug = true ] && echo "Expected 201 but server returned a 204 response" >&2
        echo "File already exists and was overwritten" >&2
    elif [ "$respCode" -ne 201 ]; then
        echo >&2
        [ $debug = true ] && cat "$_CACHE_DIR/curlout" >&2
        echo "Upload failed. Expected 201 but server returned a $respCode response" >&2 && exit 1
    fi

    url="$(make_url "/apps/gallery/#${savedir}/${filename}")"
    echo "Screenshot uploaded to ${url// /%20}" >&2
    echo "$filename"
}

nc_share() {
    local json respCode
    [ $debug = true ] && echo -e "\nApplying share settings to $savedir/$1..." >&2

    respCode=$(curl -u "$username":"$password" -X POST --post301 -sSLH "OCS-APIRequest: true" \
        "$(make_url "ocs/v2.php/apps/files_sharing/api/v1/shares?format=json")" \
        -F "path=/$savedir/$1" -F "shareType=3" -o "$_CACHE_DIR/share.json" -w "%{http_code}")

    json="$(<"$_CACHE_DIR/share.json")"
    [ $debug = true ] && echo -e "Nextcloud response:\n${json}\n" >&2

    if [ "$respCode" -ne 200 ]; then
        echo "Sharing failed. Expected 200 but server returned a $respCode response" >&2 && exit 1
    fi

    echo "$json"
}

send_notification() {
    if has notify-send; then
        notify-send -u normal -t 5000 -i insert-link NextShot \
            "${1:-"<a href=\"$url\">Your link</a> is ready to paste!"}"
    fi
    echo "${1:-"Copied $url to clipboard. Paste away!"}"
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
        --button="Quit!application-exit:1" --button="Continue!go-next:0" \
        --field="NextCloud Server URL" \
        --field="The root URL of your Nextcloud installation, e.g. https://nc.mydomain.com\n:LBL" \
        --field="Username" \
        --field="App Password:H" \
        --field="To generate an App Password, open your Nextcloud instance.
Under <b>Settings > Personal > Security</b>, enter <i>\"NextShot\"</i> for the App name
and click <b>Create new app password</b>.\n:LBL" \
        --field="Enable Pretty URLs:CHK" \
        --field="When disabled, 'index.php' will be added to links that need it.\n:LBL" \
        --field="Link direct to image instead of Nextcloud UI (appends '/preview'):CHK" \
        --field="Prompt to rename screenshots before upload:CHK" \
        --field="Screenshot Folder" \
        --field="This is where screenshots will be uploaded on Nextcloud, relative to your user root.\n:LBL" \
        "https://" "" "" "" "" true "" false true "Screenshots") || config_abort

    IFS='|' read -r server _ username password _ pretty_urls _ link_previews rename savedir _ <<< "$response"
    link_previews=${link_previews//\'/}
    link_previews=${link_previews,,}
    pretty_urls=${pretty_urls//\'/}
    pretty_urls=${pretty_urls,,}
    rename=${rename//\'/}
    rename=${rename,,}

    config=$(yad --title="NextShot Configuration" --borders=10 --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --button="Cancel!window-close:1" --button="Save!document-save:0" --width=400 --height=185 --form --field=":TXT" \
        "server=$server\nusername=$username\npassword=$password\npretty_urls=$pretty_urls\nsavedir=$savedir\nlink_previews=$link_previews\nrename=$rename") || config_abort

    echo -e "${config}" > "$_CONFIG_FILE"
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

# Does your server have Pretty URLs enabled?
#  Set this to false if links include 'index.php'
pretty_urls=true

# Folder on Nextcloud where screenshots will be uploaded (must already exist)
savedir=''

# When set to true, appends /preview to share links, going straight to the full-size image
link_previews=false

# Whether to prompt for a filename before uploading to Nextcloud
rename=false
EOF
}

nextshot "$@"
