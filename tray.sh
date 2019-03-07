#!/usr/bin/env bash

PIPE="/tmp/.pipe.tmp"
rm -f $PIPE
mkfifo $PIPE
exec 3<> $PIPE

yad --notification --listen <&3 &

echo "icon:camera-photo-symbolic" >&3
