#!/usr/bin/env bash

PIPE="/tmp/.pipe.tmp"
rm -f $PIPE
mkfifo $PIPE
exec 3<> $PIPE

yad --notification --listen --no-middle <&3 &

echo "menu:\
Capture area        ! nextshot --selection   |\
Capture window      ! nextshot --window      |\
Capture full screen ! nextshot --fullscreen  ||\
Quit Nextshot       ! quit" >&3

echo "icon:camera-photo-symbolic" >&3
echo "tooltip:Nextshot" >&3
