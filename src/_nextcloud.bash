[ "$(basename -- "$0")" = "_nextcloud.bash" ] && ${debug:?} && \
    ${link_previews:?} && ${pretty_urls:?} && ${savedir:?} && \
    ${server:?} && ${username:?} && ${password:?}

_curl() {
    local curl_status=0 err http_status url \
        options=(-u "$username":"$password" -Lw '%{http_code}')
    : "${expected:=200}"

    case "$1" in
        shares) url="ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" ;;
        *) url="${1/dav:/remote.php/dav/files/${username}/${savedir}/}"
    esac; shift; url="$(make_url "$url")"

    http_status="$(curl "${options[@]}" "$@" "$url")" || curl_status=$?

    [[ $http_status = 000 || ,${expected}, = *",${http_status},"* ]] ||\
        err=", got ${http_status} response but expected ${expected//,//}"
    [[ $curl_status = 0 ]] || err+=" (curl ${curl_status})"
    [[ -z $err ]] || echo "Request failed${err}" >&2

    echo "$http_status"
    return $curl_status
}

make_share_url() {
    local json suffix; read -r json

    if $link_previews; then
        suffix=/preview
    fi
    make_url "/s/$(echo "${json}" | jq -r '.ocs.data.token')${suffix}"
}

make_url() {
    local path="$*";
    if ! [ "${path:0:1}" = "/" ]; then
        echo "${server}/${path}"
        return
    fi

    $pretty_urls && echo "${server}${*}" \
        || echo "${server}/index.php${*}"
}

nc_overwrite_check() {
    local expected=207,404 line1 line2 newname proceed status

    echo "Checking for file on Nextcloud..." >&2
    status="$(_curl dav:"${1// /%20}" -sX PROPFIND -o /dev/null)"

    if [ "$status" = 404 ]; then
        echo "$1" && return
    elif is_interactive; then
        echo "File '$1' already exists!" >&2

        while true; do case "$proceed" in
            a|A)
                break ;; #noop
            r|R)
                while [ -z "$newname" ]; do
                    echo -n "  New filename: " >&2 && read -r newname
                done

                nc_overwrite_check "$newname" && return ;;
            o|O)
                echo "$1" && return ;;
            *)
                echo -n "  Press 'a' to abort, 'r' to rename, or 'o' to overwrite: " >&2
                read -rn1 proceed && echo >&2 ;;
        esac; done
    elif has yad; then
        line1="The file <b>$1</b> already exists on NextCloud!"
        line2="How would you like to proceed?"

        if yad --title "NextCloud File Conflict" --text "\n${line1}\n\n${line2}\n" \
            --button="Rename!document-edit:0" --button="Abort!dialog-cancel:1" \
            --button="Overwrite!document-replace:2" --borders=10
        then
            while [ -z "$newname" ]; do
                newname="$(yad --entry --title "Rename File" --button="Save!document-save" \
                    --entry-text="$1" --text="\nEnter new filename:" --borders=10 2>/dev/null)"
            done

            nc_overwrite_check "$newname" && return
        else
            case "$?" in
                2) echo "$1" && return ;;
                1|70|252) ;; #noop
            esac
        fi
    fi

    echo "Upload cancelled!" >&2 && exit 1
}

nc_upload() {
    local expected=201,204 filename output proceed respCode url

    read -r filename
    echo -e "\nUploading screenshot..." >&2

    [ "$debug" = true ] && output="$_CACHE_DIR/curlout" || output=/dev/null

    respCode="$(_curl dav:"${1// /%20}" -# --post301 --upload-file "$_CACHE_DIR/$filename" -o "$output")"

    if [ "$respCode" = 204 ]; then
        echo "File already exists and was overwritten" >&2
    elif [ "$respCode" -ne 201 ]; then
        echo >&2
        [ "$debug" = true ] && cat "$_CACHE_DIR/curlout" >&2
        echo "Upload failed" >&2 && exit 1
    fi

    url="$(make_url "/apps/gallery/#${savedir}/${1}")"
    echo "Screenshot uploaded to ${url// /%20}" >&2
    echo "$filename"
}

nc_share() {
    local json respCode

    [ "$debug" = true ] && echo -e "\nApplying share settings to $savedir/$1..." >&2

    respCode="$(_curl shares -sSX POST --post301 -o "$_CACHE_DIR/share.json" \
        -H "OCS-APIRequest: true" -F "path=/$savedir/$1" -F "shareType=3")"

    json="$(<"$_CACHE_DIR/share.json")"
    [ "$debug" = true ] && echo -e "Nextcloud response:\n${json}\n" >&2

    if [ "$respCode" -ne 200 ]; then
        echo "Sharing failed" >&2 && exit 1
    fi

    echo "$json"
}
