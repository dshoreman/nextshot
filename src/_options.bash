parse_opts() {
    local -r OPTS=D::htvVamwd:F:fpc
    local -r LONG=deps::,dependencies::,env:,help,tray,prune-cache,verbose,version,area,window,delay:,format:,fullscreen,monitor,paste,file:,clipboard
    local parsed

    ! parsed=$(getopt -o "$OPTS" -l "$LONG" -n "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Run 'nextshot --help' for a list of commands."
        exit 2
    fi
    eval set -- "$parsed"

    while true; do
        case "$1" in
            -D|--deps|--dependencies)
                parse_environment
                local chk=${2//=}
                case "${chk,,}" in
                    a|all)
                        chk=a ;;
                    g|global)
                        chk=g ;;
                    w|wayland)
                        chk=w ;;
                    x|x11)
                        chk=x ;;
                    *)
                        is_wayland && chk="w" || chk="x" ;;
                esac
                status_check "$chk" && exit 0 ;;
            --env)
                NEXTSHOT_ENV=${2//=}
                shift 2 ;;
            -h|--help)
                usage && exit 0 ;;
            -t|--tray)
                if ! has yad; then
                    echo "Yad is required for the NextShot tray icon."
                    echo "Please install yad or run nextshot --help for CLI options."
                    exit 1
                fi

                tray_menu && exit 0 ;;
            --prune-cache)
                prune_cache && exit 0 ;;
            -v|--verbose)
                debug=true; echo "Debug mode enabled"; shift ;;
            -V|--version)
                echo "NextShot v${_VERSION}" && exit 0 ;;
            -a|--area)
                mode="selection"; shift ;;
            -f|--fullscreen)
                mode="fullscreen"; shift ;;
            -m|--monitor)
                mode="monitor"; shift ;;
            -w|--window)
                mode="window"; shift ;;
            -d|--delay)
                delay=${2//=}; shift 2 ;;
            -F|--format)
                cliFormat=${2//=}
                if ! is_format "${cliFormat}"; then
                    echo "WARNING: Invalid image format '${cliFormat}', default will be set from config."
                fi
                shift 2 ;;
            --file)
                local mimetype

                file="$2"
                mode="file"

                # If file cannot be found here, $mimetype will be the error from `file`
                mimetype="$(file -E --mime-type -b "$file")" || (echo "$mimetype" && exit 1)

                if [ ! "${mimetype:0:6}" = "image/" ]; then
                    echo "Failed MIME check: expected image/*, got '$mimetype'."
                    exit 1
                fi
                shift 2 ;;
            -p|--paste)
                mode="clipboard"; shift ;;
            -c|--clipboard)
                output_mode="clipboard"; shift ;;
            --)
                shift; break ;;
            *)
                echo "Option '$1' should be valid but couldn't be handled."
                echo "Please submit an issue at https://github.com/dshoreman/nextshot/issues"
                exit 3 ;;
        esac
    done

    : ${mode:=selection}
    if [ $debug = true ]; then
        echo "Screenshot mode set to $mode"
        echo "Output will be sent to ${output_mode^}"
    fi
}
