# NextShot

NextShot is a simple utility that shares your screenshots via NextCloud,
automatically copying the link to your clipboard.

NextShot is a work in progress currently limited to taking screenshots of a
selected window or area, or the entire desktop. At some point, support will be
added for taking screenshots of a single screen in a multi-monitor environment.

## Installation

Clone the repo, copy the script somewhere in your `$PATH`, and make it executable.

Alternatively, you can download the raw script directly:

```
sudo curl -o /usr/local/bin/nextshot https://raw.githubusercontent.com/dshoreman/nextshot/master/nextshot.sh
sudo chmod +x /usr/local/bin/nextshot
```

### Dependencies

NextShot makes use of some third party tools to provide its functionality.
To use it, you'll need the following:

* **On X11**
  * `imagemagick` for taking the screenshots
  * `slop` for selecting windows or an area on the screen
  * `xclip` for copying the share link to clipboard
* **On Wayland**
  * `grim` for taking the screenshots
  * `slurp` for selecting an area on the screen
  * `wl-clipboard` for copying the share link to clipboard
* **Everywhere**
  * `curl` for uploading and sharing screenshots via the NextCloud API
  * `yad` for the config form and filename dialogs (**optional**)

### Configuration

When you first run Nextshot, you'll be prompted to enter the config details.
Follow the instructions, click Ok and you'll see a preview of your config.
If the preview is correct, click Save. Otherwise, you can edit it before
saving to correct any mistakes.

#### Manual Config

Don't like UIs? You can skip the first-run config window by manually creating your config:

```
mkdir -p ~/.config/nextshot && vim ~/.config/nextshot/nextshot.conf
```

Below is a table of available configuration options and what they do.
Options without a default value are **required**:

| Option     | Default         | Description                                                                 |
| ---------- | --------------- | --------------------------------------------------------------------------- |
| `server`   | *n/a*           | NextCloud server URL, starting with `https://` and _no trailing /_          |
| `username` | *n/a*           | Your NextCloud username.                                                    |
| `password` | *n/a*           | NextCloud App password created specifically for NextShot.                   |
| `savedir`  | *n/a*           | Name of the folder to save screenshots in, relative to your NextCloud root. |
| `rename`   | `FALSE`         | Whether or not to prompt for a filename before upload (`true` or `false`)   |
| `hlColour` | `255,100,180`   | Colour to use for selection and window highlight, in RGB.                   |

##### Example `nextshot.conf`

```bash
server='https://example.com/nextcloud'
username='jenBloggs'
password='rcPn0-zyKC9-Dt0Vn-LG9Cn-Aa3EE'
savedir='Screenshots'
rename=false
```

## Usage

NextShot can be used directly or via a keybind in your window manager.

### In a Terminal

Simply run `nextshot` and select the area (or click in the window)
you want to capture. To capture the entire display, run NextShot with
the `--fullscreen` argument.

If you enabled the `rename` option in your config, NextShot will then
prompt you for a filename before uploading, or you can leave it as the
default and hit enter. With `rename` disabled, upload is fully automatic.

If you ran `nextshot` too soon or decide you don't want to take
the screenshot after all, hit `Ctrl+C` to abort the selection.

#### Uploading an Existing File

NextShot is able to upload any file already on your system:

```sh
cd ~/Pictures
nextshot --file fluffy-kittens.jpg
```

Note that this bypasses the rename prompt and may overwrite existing files.

### Usage via Keybind (i3 or Sway)

Add the following to your i3 config to have NextShot's different
modes bound to the Print Screen key:

```
bindsym --release Print exec "nextshot --fullscreen"
bindsym --release Shift+Print exec "nextshot --selection"
bindsym --release $mod+Print exec "nextshot --window"
```

Note that due to limitations with ImageMagick's `import` tool, it is not possible
to abort selection when it's detached from a shell such as when called by i3.

## Caveats
* NextShot will not create `savedir` for you, the directory must already exist.
* It doesn't check status of responses, it simply assumes everything works.
    Probably not a big deal, but don't expect it to work if your server is down.
* It won't protect you from typos. If you forget to give your file an extension,
    NextCloud will force download when you visit the share link.
