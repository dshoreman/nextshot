#!/usr/bin/env bash

_CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
_CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"
_CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"

function has {
    type "$1" >/dev/null 2>&1 || return 1
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

if [ ! -d "$_CACHE_DIR" ]; then
    mkdir -p "$_CACHE_DIR"
fi

echo "Loading config from $_CONFIG_FILE..." && . "$_CONFIG_FILE" && echo "Ready!"

rename=${rename,,}

TMP_NAME="$(date "+%Y-%m-%d %H.%M.%S").png"
TMP_PATH="$_CACHE_DIR/$TMP_NAME"
REAL_NAME="$TMP_NAME"

import "$TMP_PATH"

if [ "$rename" = true ] && has yad; then
    REAL_NAME=$(yad --entry --title "NextShot" --borders=10 --button="gtk-save" --entry-text="$TMP_NAME" \
        --text="<b>Screenshot Saved!</b>\nEnter filename to save to NextCloud:" 2>/dev/null)
fi

echo "Uploading screenshot to $server/$savedir/$REAL_NAME..."
curl -u "$username":"$password" "$server/remote.php/dav/files/$username/$savedir/$REAL_NAME" --upload-file "$TMP_PATH"

FILE_TOKEN=$(curl -u "$username":"$password" -X POST -H "OCS-APIRequest: true" \
    -F "path=/$savedir/$REAL_NAME" -F "shareType=3" \
    "$server/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" | jq -r '.ocs.data.token')

SHARE_URL="$server/s/$FILE_TOKEN"

echo "Success! Your file has been uploaded to:"
echo "$SHARE_URL"
echo "$SHARE_URL" | \xclip -selection clipboard && \
    echo "Link copied to clipboard. Paste away!"
