#!/usr/bin/env bash

_CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
_CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"

if [ ! -d $_CONFIG_DIR ]; then
    echo "Loading first-run config window..."

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
        --field="Screenshot Folder" \
        --field="This is where screenshots will be uploaded on Nextcloud, relative to your user root.\n:LBL" \
        "https://" "" "" "" "" "Screenshots")

    if [[ $? -gt 0 ]]; then
        echo "Configuration aborted by user, exiting."
        exit
    fi

    IFS='|' read -r server junk username password junk savedir junk <<< "$response"

    mkdir -p "$_CONFIG_DIR"

    tmpConfig="server=$server\nusername=$username\npassword=$password\nsavedir=$savedir"

    echo $(yad --title="NextShot Configuration" --borders=10 --button="gtk-save" --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --width=400 --height=175 --form --field=":TXT" "$tmpConfig") | sed 's/\\n/\n/g' > $_CONFIG_FILE

    echo "Config saved to $_CONFIG_FILE"
fi

echo "Loading config from $_CONFIG_FILE..." && . $_CONFIG_FILE && echo "Ready!"

TMP_NAME="/tmp/nextshot.png"

import $TMP_NAME
NC_FILENAME=$(zenity --entry --title "NextShot" --text="Enter Filename" --ok-label="Upload" 2>/dev/null)

echo "Uploading screenshot to $server/$savedir/$NC_FILENAME..."
curl -u $username:$password $server/remote.php/dav/files/$username/$savedir/$NC_FILENAME --upload-file $TMP_NAME

FILE_TOKEN=$(curl -u $username:$password -X POST -H "OCS-APIRequest: true" \
    -F "path=/$savedir/$NC_FILENAME" -F "shareType=3" \
    $server/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json | jq -r '.ocs.data.token')

SHARE_URL="$server/s/$FILE_TOKEN"

echo "Success! Your file has been uploaded to:"
echo $SHARE_URL
echo $SHARE_URL | \xclip -selection clipboard && \
    echo "Link copied to clipboard. Paste away!"
