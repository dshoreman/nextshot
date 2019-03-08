#!/usr/bin/env bash

set -Eeo pipefail

trap 'echo -e "\nAborted due to error" && exit 1' ERR
trap 'echo -e "\nAborted by user" && exit 1' SIGINT

readonly _CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"
readonly _CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
readonly _CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"
readonly _VERSION="0.8.2"

nextshot() {
    local image filename json url

    sanity_check && setup
    parse_opts "$@"
    load_config

    image=$(cache_image)
    filename="$(echo "$image" | nc_upload)"

    json=$(nc_share "$filename")
    url="$(echo "$json" | make_url)"

    echo "$url" | to_clipboard && send_notification
}

sanity_check() {
    if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
        echo "Your version of Bash is ${BASH_VERSION} but NextShot requires at least v4."
        exit 1
    fi
}

setup() {
    [ -d "$_CONFIG_DIR" ] || mkdir -p "$_CONFIG_DIR"
    [ -d "$_CACHE_DIR" ] || mkdir -p "$_CACHE_DIR"

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
    case "${1:---selection}" in
        --file)
            local mimetype

            if [ -z ${2+x} ]; then
                echo "--file option requires a filename"
                exit 1
            elif [ ! -f "$PWD/$2" ]; then
                echo "File $2 could not be found!"
                exit 1
            fi

            mode="file"
            file="$2"

            mimetype="$(file --mime-type -b "$file")"
            if [ ! "${mimetype:0:6}" = "image/" ]; then
                echo "Failed MIME check: expected image/*, got '$mimetype'."
                exit 1
            fi
            ;;
        --fullscreen)
            mode="fullscreen" ;;
        --paste)
            if ! check_clipboard; then
                echo "Clipboard does not contain an image, aborting."
                exit 1
            fi

            mode="clipboard"
            ;;
        --selection)
            mode="selection" ;;
        --window)
            mode="window"
            ;;
        --help)
            echo "Usage:"
            echo "  nextshot [OPTION]"
            echo
            echo "General Options:"
            echo "  --help        Display this help and exit"
            echo "  --version     Output version information and exit"
            echo
            echo "Screenshot Modes:"
            echo
            echo " Use these options to take a new screenshot and have"
            echo " NextShot automatically upload it to Nextcloud."
            echo
            echo "  --fullscreen  Capture the entire X/Wayland display"
            echo "  --selection   Capture only the selected area"
            echo "  --window      Capture a single window"
            echo
            echo "Upload Modes:"
            echo
            echo " Use these options when you have an existing image"
            echo " that you want to upload to Nextcloud."
            echo
            echo "  --file FILE   Upload from the local filesystem"
            echo "  --paste       Upload from the system clipboard"
            echo
            exit 0
            ;;
        --version)
            echo "NextShot v${_VERSION}"
            exit 0
            ;;
        *)
            echo "NextShot: Unrecognised option '$1'"
            echo "Try 'nextshot --help' for more information."
            exit 1
    esac

    echo "Screenshot mode set to $mode"
}

filter_key() {
    grep -Po "\"$1\": *\"\K[^\"]*"
}

has() {
    type "$1" >/dev/null 2>&1 || return 1
}

is_wayland() {
    [ -n "${WAYLAND_DISPLAY+x}" ]
}

int2dec() {
    printf '%.2f' "$(echo "$1 / 255" | bc -l)"
}

int2hex() {
    printf '%02x\n' "$1"
}

make_url() {
    local json; read -r json

    echo "$server/s/$(echo "$json" | filter_key "token")"
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
    if is_wayland; then wl-copy
    else
        xclip -selection clipboard
    fi
}

load_config() {
    # shellcheck disable=SC1090
    echo "Loading config from $_CONFIG_FILE..." && . "$_CONFIG_FILE"

    local errmsg="missing required config option."
    : "${server:?$errmsg}" "${username:?$errmsg}" "${password:?$errmsg}" "${savedir:?$errmsg}"

    rename=${rename:-false}
    rename=${rename,,}

    parse_colour && echo "Config loaded!"
}

parse_colour() {
    local red green blue parts

    hlColour="${hlColour:-255,100,180}"
    IFS="," read -ra parts <<< "$hlColour"

    red="${parts[0]}"
    green="${parts[1]}"
    blue="${parts[2]}"

    if is_wayland; then
        hlColour="#$(int2hex "$red")$(int2hex "$green")$(int2hex "$blue")"
    else
        hlColour="$(int2dec "$red"),$(int2dec "$green"),$(int2dec "$blue")"
    fi
}

cache_image() {
    if [ "$mode" = "file" ]; then
        cp "$PWD/$file" "$_CACHE_DIR/$file" && echo "$file"
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
    if [ "$mode" = "selection" ]; then
        grim -g "$(slurp -d -c "${hlColour}ee" -s "${hlColour}66")" "$1"
    elif [ "$mode" = "window" ]; then
        local windows window choice num max size offset geometries title titles

        windows=$(swaymsg -t get_tree | jq -r '.. | (.nodes? // empty)[] | select(.visible and .pid) | {name} + .rect | "\(.x),\(.y) \(.width)x\(.height) \(.name)"')
        geometries=()
        titles=()

        echo "Found the following visible windows:" >&2
        num=0
        while read -r window; do
            read -r offset size title <<< "$window"
            geometries+=("$offset $size")
            titles+=("$title")

            echo "[$num] $title" >&2
            ((num+=1))
        done <<< "$windows"

        ((max="$num-1"))
        choice=-1

        while [ $choice -lt 0 ] || [ $choice -gt $max ]; do
            read -r -p "Which window to capture [0-$max]? " choice

            if [ -z "$choice" ] || ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                echo "Invalid selection. Enter a number between 0 and $max" >&2
                choice=-1
            fi
        done

        echo "Selected window $choice: ${titles[$choice]}" >&2

        grim -g "${geometries[$choice]}" "$1"
    else
        grim "$1"
    fi
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

    import "${args[@]}" "$1"
}

attempt_rename() {
    local newname

    if [ ! "$rename" = true ] || ! has yad; then echo "$1"
    else
        newname=$(yad --entry --title "NextShot" --borders=10 --button="gtk-save" --entry-text="$1" \
            --text="<b>Screenshot Saved!</b>\nEnter filename to save to NextCloud:" 2>/dev/null)

        if [ ! "$1" = "$newname" ]; then
            mv "$_CACHE_DIR/$1" "$_CACHE_DIR/$newname"
        fi

        echo "$newname"
    fi
}

nc_upload() {
    local filename; read -r filename

    echo "Uploading screenshot..." >&2

    respCode=$(curl -u "$username":"$password" "$server/remote.php/dav/files/$username/$savedir/$filename" \
        -L --post301 --upload-file "$_CACHE_DIR/$filename" -#o /dev/null -w "%{http_code}")

    if [ "$respCode" -ne 201 ]; then
        echo "Upload failed. Expected 201 but server returned a $respCode response" >&2 && exit 1
    fi

    echo "$filename"
}

nc_share() {
    curl -u "$username":"$password" -X POST --post301 -sSLH "OCS-APIRequest: true" \
        "$server/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" \
        -F "path=/$savedir/$1" -F "shareType=3"
}

send_notification() {
    if has notify-send; then
        notify-send -u normal -t 5000 -i insert-link NextShot \
            "<a href=\"$url\">Your link</a> is ready to paste!"
    else
        echo "Link $url copied to clipboard. Paste away!"
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
        --field="Prompt to rename screenshots before upload:CHK" \
        --field="Screenshot Folder" \
        --field="This is where screenshots will be uploaded on Nextcloud, relative to your user root.\n:LBL" \
        "https://" "" "" "" "" true "Screenshots") || config_abort

    IFS='|' read -r server _ username password _ rename savedir _ <<< "$response"
    rename=${rename//\'/}

    config=$(yad --title="NextShot Configuration" --borders=10 --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --button="gtk-cancel:1" --button="gtk-save:0" --width=400 --height=175 --form --field=":TXT" \
        "server=$server\nusername=$username\npassword=$password\nsavedir=$savedir\nrename=$rename") || config_abort

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

# Whether to prompt for a filename before uploading to Nextcloud
rename=false
EOF
}

nextshot "$@"
