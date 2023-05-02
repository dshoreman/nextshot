[ "$(basename -- "$0")" = "_config.bash" ] && ${debug:?}

setup() {
    [ -d "$_CONFIG_DIR" ] || mkdir -p "$_CONFIG_DIR"
    [ -d "$_CACHE_DIR" ] || mkdir -p "$_CACHE_DIR"
    [ -d "$_RUNTIME_DIR" ] || mkdir -p "$_RUNTIME_DIR"

    if [ ! -f "$_CONFIG_FILE" ]; then
        if ! has yad; then
            config_cli
        else
            config_gui
        fi

        config_complete
    fi
}

load_config() {
    [ "$debug" = true ] && echo -e "\nLoading config from $_CONFIG_FILE..."
    # shellcheck disable=SC1090
    . "$_CONFIG_FILE"

    local errmsg="missing required config option."
    : "${server:?$errmsg}" "${username:?$errmsg}" "${password:?$errmsg}" "${savedir:?$errmsg}"
    [ "$debug" = true ] && echo "Uploading to /${savedir} as ${username} on Nextcloud instance ${server}"

    hlColour="$(parse_colour "${hlColour:-255,100,180}")"
    link_previews=${link_previews:-false}
    link_previews=${link_previews,,}
    pretty_urls=${pretty_urls:-true}
    pretty_urls=${pretty_urls,,}
    rename=${rename:-false}
    rename=${rename,,}
    delay=${delay:-0}

    if is_format "${cliFormat:-}"; then
        format="${cliFormat,,}"
    else
        is_format "${format}" && format="${format,,}" || format="png"
    fi

    if [ "$debug" = true ]; then
        echo -e "\nParsed config:"
        echo "  delay: ${delay}"
        echo "  format: ${format}"
        echo "  rename: ${rename}"
        echo "  hlColour: ${hlColour}"
        echo "  link_previews: ${link_previews}"
        echo -e "  pretty_urls: ${pretty_urls}\n"
    fi
}

config_cli() {
    echo "Failed to detect Yad, required to display the initial configuration window."
    echo "If you don't wish to install Yad, NextShot can create a basic config for you."
    echo

    read -rn1 -p "Create config for manual editing (y/n)? " answer
    echo

    [ "${answer,,}" = "y" ] || config_abort

    echo -n "Creating config template... "
    config_create && echo "[DONE]"

    echo "Opening config for editing"
    ${EDITOR:-vi} "$_CONFIG_FILE"
}

config_gui() {
    response=$(yad --title "NextShot Configuration" --text="<b>Welcome to NextShot\!</b>

Seems this is your first time running this thing.
Fill out the options below and you'll be taking screenshots in no time:\n" \
        --image="preferences-other" --borders=10 --fixed --quoted-output --form \
        --button="Quit!application-exit:1" --button="Continue!go-next:0" \
        --field="NextCloud Server URL" \
        --field="The root URL of your Nextcloud installation, e.g. https://nc.mydomain.com\n:LBL" \
        --field="Username" \
        --field="App Password:H" \
        --field="To generate an App Password, open your Nextcloud instance.
Under <b>Settings > Personal > Security</b>, enter <i>\"NextShot\"</i> for the App name
and click <b>Create new app password</b>.\n:LBL" \
        --field="Enable Pretty URLs:CHK" \
        --field="When disabled, 'index.php' will be added to links that need it.\n:LBL" \
        --field="Link direct to image instead of Nextcloud UI (appends '/preview'):CHK" \
        --field="Prompt to rename screenshots before upload:CHK" \
        --field="Screenshot Folder" \
        --field="This is where screenshots will be uploaded on Nextcloud, relative to your user root.\n:LBL" \
        "https://" "" "" "" "" true "" false true "Screenshots") || config_abort

    IFS='|' read -r server _ username password _ pretty_urls _ link_previews rename savedir _ <<< "$response"
    link_previews=${link_previews//\'/}
    link_previews=${link_previews,,}
    pretty_urls=${pretty_urls//\'/}
    pretty_urls=${pretty_urls,,}
    rename=${rename//\'/}
    rename=${rename,,}

    config=$(yad --title="NextShot Configuration" --borders=10 --separator='' \
        --text="Check the config below and correct any errors before saving:" --fixed\
        --button="Cancel!window-close:1" --button="Save!document-save:0" --width=400 --height=185 --form --field=":TXT" \
        "server=$server\nusername=$username\npassword=$password\npretty_urls=$pretty_urls\nsavedir=$savedir\nlink_previews=$link_previews\nrename=$rename") || config_abort

    echo -e "${config}" > "$_CONFIG_FILE"
}

config_abort() {
    if ! has yad; then
        echo "Either install Yad, or configure NextShot manually."
    fi

    echo "Configuration aborted by user, exiting." >&2
    exit 1
}

config_complete() {
    echo
    echo "Config saved! It can be found in $_CONFIG_FILE"
    echo "If you wish to make further changes, open it in your favourite text editor."
    echo
    echo "You may now run nextshot again to start taking screenshots."

    exit 0
}

config_create() {
    cat << 'EOF' > "$_CONFIG_FILE"
# Your Nextcloud domain or base URL, including http[s]:// but no trailing slash
#  e.g. 'https://nextcloud.example.com' *OR* 'https://example.com/nextcloud'
server=''

# Your Nextcloud username
username=''

# Nextcloud App Password created specifically for NextShot (Settings > Personal > Security)
password=''

# Does your server have Pretty URLs enabled?
#  Set this to false if links include 'index.php'
pretty_urls=true

# Folder on Nextcloud where screenshots will be uploaded (must already exist)
savedir=''

# When set to true, appends /preview to share links, going straight to the full-size image
link_previews=false

# Whether to prompt for a filename before uploading to Nextcloud
rename=false
EOF
}
