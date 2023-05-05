[ "$(basename -- "$0")" = "_tray.bash" ] && ${savedir:?}

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
Capture monitor     ! nextshot -m         !display|\
Capture full screen ! nextshot -f         !view-fullscreen-symbolic||\
Paste from Clipboard! nextshot -p         !edit-paste-symbolic||\
Quit Nextshot       ! kill $traypid       !application-exit" >&3

    echo "icon:nextshot-16x16" >&3
    echo "tooltip:Nextshot" >&3

    for (( i=1; i < 8; i++ )); do
        echo "icon:nextshot-16x16" >&3
        sleep 0.5s
    done
}
