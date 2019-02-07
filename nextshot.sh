#!/usr/bin/env bash

_CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
_CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"

function nextshot {
    load_config
    init_cache

    local url="$(nc_share "$(take_screenshot | nc_upload)" | make_url)"

    echo "$url" | clipboard && \
        echo "Link $url copied to clipboard. Paste away!"
}

function has {
    type "$1" >/dev/null 2>&1 || return 1
}

function clipboard {
    is_wayland && wl-copy || xclip -selection clipboard
}

function is_wayland {
    [ -z ${WAYLAND_DISPLAY+x} ] && return 1
}

function filter_key {
    grep -Po "\"$1\": *\"\K[^\"]*"
}

function init_cache {
    _CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"

    [ -d "$_CACHE_DIR" ] || mkdir -p "$_CACHE_DIR"
}

function load_config {
    echo "Loading config from $_CONFIG_FILE..." && . "$_CONFIG_FILE" && echo "Ready!"

    rename=${rename,,}
}

function take_screenshot {
    local filename="$(date "+%Y-%m-%d %H.%M.%S").png"

    import "$_CACHE_DIR/$filename"

    attempt_rename "$filename"
}

function attempt_rename {
    if [ ! "$rename" = true ] || ! has yad; then echo $1
    else
        local newname=$(yad --entry --title "NextShot" --borders=10 --button="gtk-save" --entry-text="$1" \
            --text="<b>Screenshot Saved!</b>\nEnter filename to save to NextCloud:" 2>/dev/null)

        if [ ! "$1" = "$newname" ]; then
            mv "$_CACHE_DIR/$1" "$_CACHE_DIR/$newname"
        fi

        echo $newname
    fi
}

function nc_upload {
    local filename; read filename

    curl -u "$username":"$password" "$server/remote.php/dav/files/$username/$savedir/$filename" \
        --upload-file "$_CACHE_DIR/$filename"

    echo $filename
}

function nc_share {
    curl -u "$username":"$password" -X POST -H "OCS-APIRequest: true" \
        "$server/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" \
        -F "path=/$savedir/$1" -F "shareType=3"
}

function make_url {
    local json; read json

    echo "$server/s/$(echo $json | filter_key "token")"
}

if [ ! -d "$_CONFIG_DIR" ]; then
    if ! has yad; then
        echo "Yad is required to display for initial configuration of NextShot."
        echo "Either install Yad, or configure NextShot manually."
        exit 1
    fi

    response=$(yad --title "NextShot Configuration" --text="<b>Welcome to NextShot</b>\!

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

    IFS='|' read -r server junk username password junk rename savedir junk <<< "$response"
    rename=${rename//\'/}

    mkdir -p "$_CONFIG_DIR"

    tmpConfig="server=$server\nusername=$username\npassword=$password\nsavedir=$savedir\nrename=$rename"

    echo $(yad --title="NextShot Configuration" --borders=10 --button="gtk-save" --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --width=400 --height=175 --form --field=":TXT" "$tmpConfig") | sed 's/\\n/\n/g' > "$_CONFIG_FILE"

    echo "Config saved to $_CONFIG_FILE"
    exit 0
fi

nextshot
