#!/usr/bin/env bash
#
# Nextshot - A simple screenshot utility for Linux
# Copyright (C) 2019  Dave Shoreman <aur+nextshot at dsdev dot io>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# ---
# shellcheck disable=SC2251
# The '!'s in getopt commands are intended to bypass errexit when
# it fails, otherwise we can't check for invalid args afterwards.

set -Eeo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"

trap 'echo -e "\nAborted due to error" && exit 1' ERR
trap 'echo -e "\nAborted by user" && exit 1' SIGINT

readonly _CACHE_DIR="${XDG_CACHE_HOME:-"$HOME/.cache"}/nextshot"
readonly _CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/nextshot"
readonly _RUNTIME_DIR="${XDG_RUNTIME_DIR:-"/tmp"}/nextshot"
readonly _CONFIG_FILE="$_CONFIG_DIR/nextshot.conf"
readonly _TRAY_FIFO="$_RUNTIME_DIR/traymenu"
readonly _VERSION="1.4.5"

source "${SCRIPT_ROOT}/_cache.bash"
source "${SCRIPT_ROOT}/_capture.bash"
source "${SCRIPT_ROOT}/_clipboard.bash"
source "${SCRIPT_ROOT}/_colours.bash"
source "${SCRIPT_ROOT}/__config.bash"
source "${SCRIPT_ROOT}/_dependencies.bash"
source "${SCRIPT_ROOT}/_env.bash"
source "${SCRIPT_ROOT}/_io.bash"
source "${SCRIPT_ROOT}/_nextcloud.bash"
source "${SCRIPT_ROOT}/_options.bash"
source "${SCRIPT_ROOT}/_tray.bash"

usage() {
    echo "Usage:"
    echo "  nextshot [OPTION]"
    echo
    echo "General Options:"
    echo "  -D, --deps[=TYPE] List dependency statuses and exit"
    echo "  --env=ENV         Override environment detection"
    echo "  -h, --help        Display this help and exit"
    echo "  -t, --tray        Start the NextShot tray menu"
    echo "  --prune-cache     Clean up the screenshot cache"
    echo "  -v, --verbose     Enable verbose output for debugging"
    echo "  -V, --version     Output version information and exit"
    echo
    echo "Screenshot Modes:"
    echo
    echo " Use these options to take a new screenshot and have"
    echo " NextShot automatically upload it to Nextcloud."
    echo
    echo "  -a, --area        Capture only the selected area"
    echo "  -m, --monitor     Capture only the active monitor"
    echo "  -f, --fullscreen  Capture the entire X/Wayland display"
    echo "  -w, --window      Capture a single window"
    echo "  -d, --delay=NUM   Pause for NUM seconds before capture"
    echo "  -F, --format=FMT  Save image as FMT instead of the default"
    echo
    echo "Upload Modes:"
    echo
    echo " Use these options when you have an existing image"
    echo " that you want to upload to Nextcloud."
    echo
    echo "  --file FILE       Upload from the local filesystem"
    echo "  -p, --paste       Upload from the system clipboard"
    echo
    echo "Output Modes:"
    echo
    echo " These options can be used in addition to one of the"
    echo " aforementioned Screenshot or Upload Modes. If none"
    echo " are used, the default is to upload to Nextcloud."
    echo
    echo "  -c, --clipboard   Copy the captured image to clipboard"
    echo; echo
    echo "The TYPE argument of -D, --deps can be one of 'g' or 'global,"
    echo "'w' or 'wayland', 'x' or 'x11', 'a' or 'all', or omitted for"
    echo "auto. When TYPE is set to 'global', it will only list the"
    echo "global dependencies. Setting it to 'wayland' or 'x11' will"
    echo "list both the global dependencies and those of the respective"
    echo "environment, whereas 'all' will list global, Wayland *and* X11"
    echo "dependencies. When omitted, dependencies are listed based on"
    echo "the currently active environment as detected by Nextshot."
    echo "Note that TYPE is case-insensitive. -DA is the same as -Da."
    echo; echo
    echo "The --env flag affects the tools used to take screenshots."
    echo "ENV can be one of 'w', 'wl' or 'wayland' to force Wayland"
    echo "mode; 'x' or 'x11' to force X11; 'auto' or left blank to"
    echo "use the builtin automatic environment detection."
    echo
}

main() {
    local debug=false image filename json ncfilename url
    output_mode="nextcloud"

    check_bash_version && setup
    parse_opts "$@"
    parse_environment
    load_config

    if [ "$mode" = "clipboard" ] && ! check_clipboard; then
        echo "Clipboard does not contain an image, aborting."
        exit 1
    fi

    image=$(cache_image)

    if [ "$output_mode" = "clipboard" ]; then
        echo "Copying image to clipboard..."
        to_clipboard image < "$_CACHE_DIR/$image" && \
            send_notification "Your image is ready to paste!"
    else
        ncfilename="$(nc_overwrite_check "$image")"
        filename="$(echo "$image" | nc_upload "$ncfilename")"

        json=$(nc_share "$ncfilename")
        url="$(echo "$json" | make_share_url)"

        echo "$url" | to_clipboard && send_notification
    fi
}

main "$@"
