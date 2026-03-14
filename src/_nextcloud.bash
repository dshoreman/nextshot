[ "$(basename -- "$0")" = "_nextcloud.bash" ] && ${debug:?} && ${step:?} && \
    ${link_previews:?} && ${pretty_urls:?} && ${savedir:?} && \
    ${server:?} && ${username:?} && ${password:?}

_curl() {
    [[ ${http_status-x} != x ]] || local http_status echo_body=y
    local body curl_status=0 err msg url \
        options=(-u "$username":"$password" -Lw '\n%{errormsg}%{http_code}')
    : "${expected:=200}"

    case "$1" in
        shares) url="ocs/v2.php/apps/files_sharing/api/v1/shares?format=json" ;;
        *) url="${1/dav:/remote.php/dav/files/${username}/${savedir}/}"
    esac; shift; url="$(make_url "$url")"

    if [[ $* != *" -#"* ]]; then
        [ "$debug" = true ] && options+=(-sS) || options+=(-s)
    fi
    [[ $* == *" -#"* || $* == *" -X POST "* ]] && options+=(--post301)

    body="$(curl "${options[@]}" "$@" "$url")" || curl_status=$?
    http_status=${body: -3}
    body=${body::-3}
    detail=${body##*$'\n'}
    body=${body%$'\n'*}

    [[ $debug = true && -n "$body" ]] && echo -e "\nServer response:\n${body}\n" >&2
    [[ $http_status = 000 || ,${expected}, = *",${http_status},"* ]] ||\
        err=", got ${http_status} response but expected ${expected//,//}"
    [[ $curl_status = 0 ]] || err+=" (curl ${curl_status})"

    if [[ $err ]]; then
        err="${req:-Request} failed${err}"
        if has notify-send && ! is_interactive; then
            msg=$err; [ -z "$detail" ] || msg+="\n\n${detail}"
            notify-send -u critical -t 20000 \
                "Couldn't ${step} screenshot" "$msg"
        fi
        echo "$err" >&2 && exit 1
    fi

    [[ $echo_body ]] && echo "$body"
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
    local req="Overwrite check" expected=207,404 http_status='' \
        line1 line2 newname proceed

    echo "Checking for file on Nextcloud..." >&2
    _curl dav:"${1// /%20}" -X PROPFIND

    if [ "$http_status" = 404 ]; then
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
    local req=Upload expected=201,204 filename proceed url http_status=

    read -r filename
    echo -e "\nUploading screenshot..." >&2

    _curl dav:"${1// /%20}" -# --upload-file "$_CACHE_DIR/$filename"

    case "$http_status" in
        201) echo -n "Screenshot uploaded to " >&2 ;;
        204) echo -n "Overwritten screenshot at " >&2 ;;
    esac; make_url "/apps/gallery/#${savedir}/${1// /%20}" >&2

    echo "$filename"
}

nc_share() {
    local filename="$1"

    if [ "$debug" = true ]; then
        echo -e "\nApplying share settings to ${savedir}/${filename}..." >&2
    fi

    _curl shares -X POST -H "OCS-APIRequest: true" \
        -F "path=/${savedir}/${filename}" -F "shareType=3"
}
