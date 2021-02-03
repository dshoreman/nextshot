![Nextshot logo](resources/logo.png)
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fdshoreman%2Fnextshot.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Fdshoreman%2Fnextshot?ref=badge_shield)

**Quickly take screenshots on Linux—sharing instantly with Nextcloud**

[![GitHub release](https://img.shields.io/github/tag/dshoreman/nextshot.svg?label=release)](https://github.com/dshoreman/nextshot/releases)
[![AUR version](https://img.shields.io/aur/version/nextshot.svg)][1]
[![Build Status](https://travis-ci.com/dshoreman/nextshot.svg?branch=master)](https://travis-ci.com/dshoreman/nextshot)
[![GitHub issues](https://img.shields.io/github/issues/dshoreman/nextshot)][3]
[![License](https://img.shields.io/github/license/dshoreman/nextshot)](LICENSE.md)

---

Nextshot enables quick and easy capture of the desktop, a window or selection—either instantly
or after a delay. Images can be copied directly to clipboard, or shared automatically via
Nextcloud (the default) so you can paste the public link in chats.

#### Compatibility

From the start, the primary goal has been to work with both i3 and Sway. Since the release
of  1.0, this has largely been achieved. While Nextshot will work on Sway and likely most
X11-based environments, the nature of Wayland means extra work will be required for eventual
compatibility with compositors other than Sway.

*TL;DR: YMMV*

## Table of Contents

* [Installation](#installation)
  * [Arch Linux](#arch-linux)
  * [Manual Install](#manual-install)
  * [Recommended Shortcuts](#recommended-shortcuts)
* [Usage](#usage)
  * [Screenshot Modes](#screenshot-modes)
  * [Upload Modes](#upload-modes)
  * [Tray Menu](#tray-menu)
* [Configuration](#configuration)
  * [Example nextshot.conf](#example-nextshotconf)
  * [Available Options](#available-options)
* [Troubleshooting](#troubleshooting)
* [Known Issues](#known-issues)
* [Contributing](#contributing)

## Installation

### Arch Linux

NextShot can be installed [from the AUR][1] as `nextshot`, though its dependencies vary
based on your environment:

```sh
# To use in i3 (or other X11-based environments)
sudo pacman -S --asdeps imagemagick slop xclip xdotool yad

# To use in Sway
sudo pacman -S --asdeps grim slurp wl-clipboard yad
```

For more information on dependencies, run `nextshot --deps` after install.
Note that Nextshot will not automatically  
install any keyboard shortcuts. A set of [recommended keybindings](#recommended-shortcuts)
is provided below for users of i3 and Sway.

### Manual Install

For other distributions, install dependencies as above then run the following to install Nextshot:

```sh
git clone -b master https://github.com/dshoreman/nextshot.git
cd nextshot && sudo make install
```

### Recommended Shortcuts

To have Nextshot's primary functions bound to the Print Screen key on i3 and Sway, add the following
to your `config` file in `~/.config/i3` and/or `~/.config/sway` respectively:

```
bindsym Print exec --no-startup-id "nextshot -m"
bindsym Mod4+Print exec --no-startup-id "nextshot -w"
bindsym Shift+Print exec --no-startup-id "nextshot -a"

bindsym Ctrl+Print exec --no-startup-id "nextshot -mc"
bindsym Ctrl+Mod4+Print exec --no-startup-id "nextshot -wc"
bindsym Ctrl+Shift+Print exec --no-startup-id "nextshot -ac"
```

These bindings will have `PrtScr` capture the current screen, `Shift+PrtScr` capture an area, and
`Super+PrtScr` capture a window—each uploading automatically to Nextcloud and copying the
share link to your clipboard.

When combined with `ctrl`, the raw image will be copied to clipboard instead of uploading to Nextcloud.

## Usage

Nextshot can be used in a few ways, but it's most flexible when run in a terminal.
Some of the more common usage examples are listed below. For details on all available
CLI options, run `nextshot --help`.

### Screenshot Modes

The following examples will upload a screenshot to Nextcloud and copy the share link. To
bypass Nextcloud and instead copy the image to clipboard, add the `-c` or `--clipboard` option.

* **Capture an area/selection**

    `nextshot -a` or `nextshot --area`

* **Capture a specific window**

    `nextshot -w` or `nextshot --window`

* **Capture the active display**

    `nextshot -m` or `nextshot --monitor`

* **Capture *all* outputs**

    `nextshot -f` or `nextshot --fullscreen`

Image capture can also be delayed by passing the `-d`, `--delay` option followed by a `TIMEOUT`, for
example `nextshot -d3.5` or `nextshot --delay 2m` to delay 3.5 seconds or 2 minutes respectively.

To abort selection in the `--area` or `--window` modes, press the Escape key.

### Upload Modes

There are two modes that support uploading an existing image to Nextcloud.

* **Share an image from the clipboard**

    `nextshot -p` or `nextshot --paste`

* **Share an image from the local filesystem**

    `nextshot --file kittens.jpg`

    **Note:** The `--file` option bypasses the rename prompt and [may overwrite
    existing files](#known-issues) if it is already in Nextcloud. To avoid issues,
    first rename or copy the image to ensure a unique filename in Nextcloud.

### Tray Menu

If you have Yad installed, you can use Nextshot via its tray icon. A normal click will
trigger Nextshot's [`--area`](#screenshot-modes) screenshot mode, while right clicking
will open a menu with quick access to most of Nextshot's functions.

![Preview of Nextshot tray menu](resources/tray.png)

The Nextshot tray menu can be started with `nextshot -t`, which you can add to `.xinitrc`
or your i3/Sway config to have it automatically started when you login.

## Configuration

The first time you run Nextshot, one of two things will happen. If you don't have Yad, you'll be
prompted to open an example config ready for editing in your `$EDITOR`. See below for details on
all available options.

If you *do* have Yad, a GUI will open for you to enter your settings. Follow the instructions and
click Ok. You'll now see a preview of the config - correct any mistakes and click Save when you're done.

### Example `nextshot.conf`

The `nextshot.conf` file should be stored in the `~/.config/nextshot` directory, which is created
automatically when you first run Nextshot. It's sourced as a Bash script, so config options are
assigned much the same way as you would define any regular Bash variables:

```bash
server='https://example.com/nextcloud'
username='jenBloggs'
password='rcPn0-zyKC9-Dt0Vn-LG9Cn-Aa3EE'
savedir='Screenshots'
rename=false
```

### Available Options

#### `server` - required

This is the base URL to your Nextcloud instance, including `http[s]://` but excluding the trailing `/`.
It may be for example `https://nc.example.com` or `https://example.com/nextcloud` depending on whether
you use a subdomain specific to Nextcloud or simply host it in a folder on your main website.

---

#### `username` - required

The username you use for Nextcloud, used to authenticate with the API when uploading screenshots.

---

#### `password` - required

This is **not** your Nextcloud account password but an *App Password* that you create specifically
for Nextshot, to be used in conjunction with your `username` for API authentication.

You can create an App password by going to **Settings > Personal > Security** in your Nextcloud UI.

Assuming your Nextcloud is hosted at *nc.example.com*:
1. Head to https://nc.example.com/settings/user/security
2. Enter `Nextshot` in the *App name* input
3. Click *Create new app password* and enter your account password to confirm
5. Copy the resulting App Password to your config, then click Done

The app password will be 5 blocks of alphanumeric characters, separated by dashes.

---

#### `savedir` - required

The name of a folder on your Nextcloud instance which should be used to upload screenshots.

This is relative to your Nextcloud root. To have your screenshots uploaded to a `Screenshots`
folder inside the root-level `Photos` directory, you would set `savedir='Photos/Screenshots'`
in your config file.

Note that this folder is not created automatically, so it must exist in Nextcloud *before* running Nextshot.

---

#### `link_previews` - optional

When set to `true`, Nextshot will append `/preview` to generated share links. With this option enabled,
clicking the link will take you directly to the full-size image rather than Nextcloud's default share UI.

Defaults to `false`


---

#### `pretty_urls` - optional

When disabled (set to `false`), this will insert `/index.php` in share links, after the Server URL.  
Leave this set to `true` (enabled) if your Nextcloud server has Pretty URLs enabled.

Defaults to `true`

---

#### `format` - optional

Set the default image format and file extension for saving screenshots.  
Supported values are `png`, `jpg` or `jpeg`.

Defaults to `png`.

---

#### `rename` - optional

When you set this option to `true`, Nextshot will prompt you to enter a custom filename before
uploading to Nextcloud. Be sure to include the extension as it will not be added automatically.
Triggering Nextshot from the [#tray-menu](tray menu) or a [#recommended-shortcuts](keybinding) will require Yad for the rename prompt.

Defaults to `false`.

---

#### `hlColour` - optional

Set this to customise the highlight colour when selecting an area or window to screenshot.

It should be specified as comma-separated RGB so that Nextshot can parse the individual colour
values and pass them along to either Slop or Slurp, depending on whether you use X11 or Wayland.

Defaults to `255,100,180`.

## Troubleshooting

#### Nextshot is detecting the wrong environment

In some cases it may be that Nextshot's environment detection doesn't quite work as expected. One
example of this might be if your system has both X11 *and* Wayland. If you were to start a tmux
session under X11 then switch to Wayland and run Nextshot from within tmux, it will think you're
running under the X11 environment when that's not really the case.

To fix this you can bypass the default detection method:
```sh
nextshot --env=wayland ...
```

For a more permanent fix, you can set or `export` the `NEXTSHOT_ENV` environment variable:
```sh
export NEXTSHOT_ENV=wayland
nextshot ...

# or

NEXTSHOT_ENV=wayland nextshot ...
```

Likewise if you're running from X11 but Nextshot detects Wayland, you can set `--env` or
`NEXTSHOT_ENV` to `x11`. For more details and possible values, see `nextshot --help`.

#### The tray icon shows up, but right-click doesn't do anything!

There was a bug introduced to Yad in v1.0 that breaks context menus in the tray icons it creates.

This issue was fixed in [v1cont/yad@06de51c][2], which was released as part of Yad v5.0. If you're still running an older version,
update to v5 or greater and the tray menu will be working again. If you still have problems, please create an issue.


## Known Issues

* [Tray icon is currently unavailable on Wayland](https://github.com/dshoreman/nextshot/issues/48)


## Contributing

If you find Nextshot useful and would like to contribute, there are a few ways you can help:
* Vote for the [nextshot package][1] on the AUR
* [Report any bugs][3] you find while using Nextshot
* Submit a feature request if there's something you'd like added
* Send a PR if you know some Bash! Check the [open issues][3] for ideas
* Finally, donate via [PayPal] or [Liberapay] (but only if you can afford to)

---

*Nextshot camera icon provided by [Icons8][4].*

[PayPal]: https://paypal.me/dshoreman
[Liberapay]: https://liberapay.com/dshoreman
[1]: https://aur.archlinux.org/packages/nextshot/
[2]: https://github.com/v1cont/yad/commit/06de51cff3ff4c98039161745f20c2c16a516cb3
[3]: https://github.com/dshoreman/nextshot/issues
[4]: https://icons8.com


## License
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fdshoreman%2Fnextshot.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fdshoreman%2Fnextshot?ref=badge_large)