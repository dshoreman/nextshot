int2dec() {
    LC_NUMERIC=C printf '%.2f' "$(echo "$1 / 255" | bc -l)"
}

int2hex() {
    LC_NUMERIC=C printf '%02x\n' "$1"
}

parse_colour() {
    local red green blue parts
    IFS="," read -ra parts <<< "$1"

    red="${parts[0]}"
    green="${parts[1]}"
    blue="${parts[2]}"

    if is_wayland; then
        echo "#$(int2hex "$red")$(int2hex "$green")$(int2hex "$blue")"
    elif has bc; then
        echo "$(int2dec "$red"),$(int2dec "$green"),$(int2dec "$blue")"
    else
        prefers bc
        echo -e "\nColour conversion unavailable, falling back to default.\n" >&2
        echo "1,0.39,0.71"
    fi
}
