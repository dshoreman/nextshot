#!/bin/bash

NC_URL=""
NC_DIR=""
NC_USERNAME=""
NC_PASSWORD=""

TMP_NAME="/tmp/nextshot.png"

import $TMP_NAME
NC_FILENAME=$(zenity --entry --title "NextShot" --text="Enter Filename" --ok-label="Upload" 2>/dev/null)

echo "Uploading screenshot to $NC_URL/$NC_DIR/$NC_FILENAME..."
curl -u $NC_USERNAME:$NC_PASSWORD $NC_URL/remote.php/dav/files/$NC_USERNAME/$NC_DIR/$NC_FILENAME --upload-file $TMP_NAME
