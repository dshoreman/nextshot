[ "$(basename -- "$0")" = "_capture.bash" ] && \
    ${debug:?} && ${delay:?} && ${mode:?} && \
    ${format:?} && ${rename:?}

attempt_rename() {
    local cmd newname

    if [ "$rename" = true ] && is_interactive; then newname="$(rename_cli "$1")"
    elif [ "$rename" = true ] && has yad; then newname="$(rename_gui "$1")"
    else newname="$1"; fi

    if [ ! "$1" = "$newname" ]; then
        [ "$debug" = true ] && cmd="mv -v" || cmd="mv"
        $cmd "$_CACHE_DIR/$1" "$_CACHE_DIR/$newname" >&2
    fi

    echo "$newname"
}

cache_image() {
    if [ "$mode" = "file" ]; then
        ${file:?}

        local cmd filename
        filename="$(basename "$file")"

        [ "$debug" = true ] && cmd="cp -v" || cmd="cp"
        $cmd "$file" "$_CACHE_DIR/$filename" >&2 && echo "$filename"
    else
        take_screenshot
    fi
}

delay_capture() {
    if [ "$delay" -gt 0 ]; then
        echo "Pausing for ${delay} seconds..." >&2
        sleep "$delay"
    fi
}

is_format() {
    [[ "${1,,}" =~ ^png|jpe?g$ ]]
}
is_jpeg() {
    [[ "${format}" =~ ^jpe?g$ ]]
}

rename_cli() {
    echo "Screenshot saved!" >&2
    read -rp "Enter filename [$1]: " newname
    echo "${newname:-$1}"
}

rename_gui() {
    yad --entry --title "NextShot" --borders=10 --button="Save!document-save" --entry-text="$1" \
        --text="<b>Screenshot Saved!</b>\nEnter filename to save to NextCloud:" 2>/dev/null
}

take_screenshot() {
    local filename filepath shoot

    filename="$(date "+%Y-%m-%d %H.%M.%S").${format}"
    filepath="$_CACHE_DIR/$filename"

    if [ "$mode" = "clipboard" ]; then
        from_clipboard > "$filepath"
    else
        is_wayland && shoot="shoot_wayland" || shoot="shoot_x"

        echo "Waiting for selection..." >&2
        $shoot "$filepath"
    fi

    attempt_rename "$filename"
}

shoot_wayland() {
    local args windows

    if [ "$mode" = "selection" ]; then
        prefers slurp
        has slurp && args=(-g "$(slurp -d -c "${hlColour}ee" -s "${hlColour}66")")
    elif [ "$mode" = "monitor" ]; then
        prefers swaymsg
        has swaymsg && \
            args=(-g "$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')")
    elif [ "$mode" = "window" ]; then
        prefers slurp
        requires swaymsg
        windows="$(swaymsg -t get_tree | jq -r '.. | select(.visible? and .pid?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')"
        has slurp && args=(-g "$(slurp -d -c "${hlColour}ee" -s "${hlColour}66" <<< "${windows}")")
    fi

    is_jpeg && args+=(-t jpeg) || args+=(-t png)

    requires grim
    delay_capture
    grim "${args[@]}" "$1"
}

shoot_x() {
    local args slop

    slop="slop -c $hlColour,0.4 -lb 3"

    if [ "$mode" = "fullscreen" ]; then
        args=(-window root)
    elif [ "$mode" = "monitor" ]; then
        local mouse mouseX mouseY monitors geometry

        # Find current cursor position
        mouse="$(xdotool getmouselocation)"
        mouseX=$(echo "${mouse}" | awk -F "[: ]" '{print $2}')
        mouseY=$(echo "${mouse}" | awk -F "[: ]" '{print $4}')
        [ "$debug" = true ] && echo "Cursor position: ${mouseX}x${mouseY}" >&2

        # Grab active output positions and sizes
        monitors=$(i3-msg -t get_outputs | jq -r \
            '.[] | select(.active) | {name} + .rect | "\(.width)x\(.height)+\(.x)+\(.y)+\(.name)"')

        # Detect which output cursor x/y is in
        for monitor in ${monitors}; do
            local monW monH monX monY
            monW=$(echo "${monitor}" | awk -F "[x+]" '{print $1}')
            monH=$(echo "${monitor}" | awk -F "[x+]" '{print $2}')
            monX=$(echo "${monitor}" | awk -F "[x+]" '{print $3}')
            monY=$(echo "${monitor}" | awk -F "[x+]" '{print $4}')
            monN=$(echo "${monitor}" | awk -F "[x+]" '{print $5}')

            [ "$debug" = true ] && echo "Discovered monitor ${monN}: ${monW}x${monH}px @ ${monX}x${monY}" >&2

            if (( mouseX < monX )) || (( mouseX > monX+monW )); then
                [ "$debug" = true ] && echo "Cursor Xpos out of bounds of ${monN}!" >&2
                continue
            fi
            if (( mouseY < monY )) || (( mouseY > monY+monH )); then
                [ "$debug" = true ] && echo "Cursor Ypos out of bounds of ${monN}" >&2
                continue
            fi

            geometry="${monW}x${monH}+${monX}+${monY}"
            [ "$debug" = true ] && echo "Found active monitor: ${monN}" >&2
            break
        done

        args=(-window root -crop "$geometry")
    elif [ "$mode" = "selection" ]; then
        prefers slop
        has slop && args=(-window root -crop "$($slop -f "%g" -t 0)")
    elif [ "$mode" = "window" ]; then
        prefers slop
        has slop && args=(-window "$($slop -f "%i" -t 999999)")
    fi

    requires import
    delay_capture
    import "${args[@]}" "$1"
}
