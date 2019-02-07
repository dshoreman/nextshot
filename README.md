# NextShot

NextShot is a simple utility that shares your screenshots via NextCloud,
automatically copying the link to your clipboard.

NextShot is a work in progress currently limited to taking screenshots of a
selected area. At some point (hopefully in the near future), support will be
added for selecting a window as well as screenshots of the entire screen.

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

* `curl` for uploading and sharing screenshots via the NextCloud API
* `imagemagick` for taking the screenshots
* `xclip` **or** `wl-clipboard` for copying the share link to clipboard
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

There are only a few config options, all of which are required:

| Option     | Description                                                                 |
| ---------- | --------------------------------------------------------------------------- |
| `server`   | NextCloud server URL, starting with `https://` and _no trailing /_          |
| `username` | Your NextCloud username.                                                    |
| `password` | NextCloud App password created specifically for NextShot.                   |
| `savedir`  | Name of the folder to save screenshots in, relative to your NextCloud root. |
| `rename`   | Whether or not to prompt for a filename before upload (`true` or `false`)   |

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

Simply run `nextshot` and select the area you want to capture.
NextShot will then prompt you for a filename before uploading,
or you can leave it as the default and hit enter.

If you ran `nextshot` too soon or decide you don't want to take
the screenshot after all, hit `Ctrl+C` to abort the selection.

### Usage via Keybind (i3-wm)

To run NextShot when you press Print Screen, add the following to your i3 config:

```
bindsym --release Print exec nextshot
```

Note that due to limitations with ImageMagick's `import` tool, it is not possible
to abort selection when it's detached from a shell such as when called by i3.

## Caveats
* NextShot will not create `savedir` for you, the directory must already exist.
* It doesn't check status of responses, it simply assumes everything works.
    Probably not a big deal, but don't expect it to work if your server is down.
* It won't protect you from typos. If you forget to give your file an extension,
    NextCloud will force download when you visit the share link.
