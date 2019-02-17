#!/usr/bin/env bash

_CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
_CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"

nextshot() {
    sanity_check
    parse_opts "$@"
    load_config
    init_cache
    local url

    url="$(nc_share "$(cache_image | nc_upload)" | make_url)"

    echo "$url" | to_clipboard && send_notification
}

sanity_check() {
    if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
        echo "Your version of Bash is ${BASH_VERSION} but NextShot requires at least v4."
        exit 1
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
            mode="window" ;;
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
            echo "NextShot v0.6.0"
            exit 0
            ;;
        *)
            echo "NextShot: Unrecognised option '$1'"
            echo "Try 'nextshot --help' for more information."
            exit 1
    esac

    echo "Screenshot mode set to $mode"
}

has() {
    type "$1" >/dev/null 2>&1 || return 1
}

to_clipboard() {
    if is_wayland; then wl-copy
    else
        xclip -selection clipboard
    fi
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

is_wayland() {
    [ -n "${WAYLAND_DISPLAY+x}" ]
}

filter_key() {
    grep -Po "\"$1\": *\"\K[^\"]*"
}

init_cache() {
    _CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"

    [ -d "$_CACHE_DIR" ] || mkdir -p "$_CACHE_DIR"
}

load_config() {
    # shellcheck disable=SC1090
    echo "Loading config from $_CONFIG_FILE..." && . "$_CONFIG_FILE" && echo "Ready!"

    rename=${rename:-false}
    rename=${rename,,}
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
        grim -g "$(slurp -d)" "$1"
    else
        grim "$1"
    fi
}

shoot_x() {
    local args slop

    slop="slop -c ${hlColour:-1,0.4,0.7,0.4} -lb 3"

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

    curl -u "$username":"$password" "$server/remote.php/dav/files/$username/$savedir/$filename" \
        -L --post301 --upload-file "$_CACHE_DIR/$filename"

    echo "$filename"
}

nc_share() {
    curl -u "$username":"$password" -X POST --post301 -LH "OCS-APIRequest: true" \
        "$server/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" \
        -F "path=/$savedir/$1" -F "shareType=3"
}

make_url() {
    local json; read -r json

    echo "$server/s/$(echo "$json" | filter_key "token")"
}

send_notification() {
    if has notify-send; then
        notify-send -u normal -t 5000 -i insert-link NextShot \
            "<a href=\"$url\">Your link</a> is ready to paste!"
    else
        echo "Link $url copied to clipboard. Paste away!"
    fi
}

create_config() {
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

if [ ! -d "$_CONFIG_DIR" ]; then
    if ! has yad; then
        echo "Failed to detect Yad, required to display the initial configuration window."
        echo "If you don't wish to install Yad, NextShot can create a basic config for you."
        echo

        read -rn1 -p "Create config for manual editing (y/n)? " answer

        if [ "${answer,,}" = "y" ]; then
            echo
            echo -n "Creating nextshot directory... "
            mkdir -p "$_CONFIG_DIR" && echo "[DONE]"

            echo -n "Creating config template... "
            create_config && echo "[DONE]"

            echo "Opening config for editing"
            ${EDITOR:-vi} "$_CONFIG_FILE"
            echo
            echo "Config saved! If you wish to make further changes, open $_CONFIG_FILE in your favourite editor."
            echo
            echo "You may now run nextshot again to start taking screenshots."

            exit 0
        fi

        echo "Aborting. Either install Yad, or configure NextShot manually."
        exit 1
    fi

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
        "https://" "" "" "" "" true "Screenshots")

    if $response; then
        echo "Configuration aborted by user, exiting."
        exit
    fi

    IFS='|' read -r server _ username password _ rename savedir _ <<< "$response"
    rename=${rename//\'/}

    mkdir -p "$_CONFIG_DIR"

    tmpConfig="server=$server\nusername=$username\npassword=$password\nsavedir=$savedir\nrename=$rename"

    yad --title="NextShot Configuration" --borders=10 --button="gtk-save" --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --width=400 --height=175 --form --field=":TXT" "$tmpConfig" | sed 's/\\n/\n/g' > "$_CONFIG_FILE"

    echo "Config saved to $_CONFIG_FILE"
    exit 0
fi

nextshot "$@"
