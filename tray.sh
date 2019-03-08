#!/usr/bin/env bash

PIPE="/tmp/.pipe.tmp"
rm -f $PIPE
mkfifo $PIPE
exec 3<> $PIPE

# shellcheck disable=SC1090
source "$HOME/.config/nextshot/nextshot.conf"
# shellcheck disable=SC2154
files_url="$server/apps/files/?dir=/$savedir"

yad --notification --listen --no-middle <&3 &

echo "menu:\
Open Nextcloud      ! xdg-open $files_url    ||\
Capture area        ! nextshot --selection   |\
Capture window      ! nextshot --window      |\
Capture full screen ! nextshot --fullscreen  ||\
Quit Nextshot       ! quit" >&3

echo "icon:camera-photo-symbolic" >&3
echo "tooltip:Nextshot" >&3
echo "action:menu" >&3
