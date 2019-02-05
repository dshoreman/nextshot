## NextShot

A simple bash script that takes a screenshot of the selected area, uploads to Nextcloud, and copies the share link to clipboard.

### Usage

Edit the script to set your Nextcloud base URL and upload directory:

```bash
NC_URL="https://nc.mydomain.com"
NC_DIR="Screenshots"
```
Note the directory must exist and is relative to your user root.

Finally, set `$NC_USERNAME` and `$NC_PASSWORD` to your login details, then run `./nextshot.sh`

### Notes

This script is incredibly dumb. It doesn't check status of responses, or even if you type a valid filename.

It assumes everything works, and it's likely it could break as a result.
