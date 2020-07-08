# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]
### Added
* Active config values are now shown as part of verbose output
* File extension can now be set with `format` in config and/or at runtime
* New `pretty_urls` config option to support Nextcloud servers that require `/index.php`

### Changed
* Window selection on Sway is now via Slurp instead of a list

### Fixed
* Floating windows weren't able to be selected on Sway


## [1.3.2] - 2020-04-06
### Fixed
* Printf no longer fails with non-dot decimal separators in locale


## [1.3.1] - 2019-12-31
### Fixed
* Bad echo in the `usage` function


## [1.3.0] - 2019-12-31
### Added
* `--prune-cache` option to remove cached images older than 30 days
* New "logo" with a proper png icon for the tray menu

### Changed
* Config window's button icons no longer depend on GTK icon names
* Running `make install` is now more verbose

### Fixed
* Pasting the share URL in Alacritty will no longer hang or error
* Quit icon in tray menu is finally a proper Quit icon again


## [1.2.4] - 2019-08-21
### Fixed
* Buttons now appear as intended after being broken since Yad 1.0


## [1.2.3] - 2019-06-17
### Fixed
* jq was listed in --deps as a Wayland dependency, not a global one


## [1.2.2] - 2019-06-13
### Fixed
* Issue on some systems that caused spaces in filename to break upload


## [1.2.1] - 2019-06-08
### Fixed
* Issue where duplicate files would fail with unexpected response


## [1.2.0] - 2019-06-06
### Added
* Ability to force environment with `NEXTSHOT_ENV` var or `--env` flag
* Debug mode for detailed output, enabled with `-v, --verbose`
* Basic error handling in case of issues when sharing a screenshot

### Changed
* Filename prompt now uses CLI instead of Yad when running interactively

### Fixed
* Quit item in tray menu didn't actually quit


## [1.1.1] - 2019-04-04
### Fixed
* Issue where not setting delay would break screenshots


## [1.1.0] - 2019-03-28
### Added
* Support for pausing between selection and capture with new `--delay` CLI option
* New `link_previews` config option to append `/preview` to generated share links
* This changelog!

### Fixed
* Minor issue where bools were saved to config as uppercase from GUI window


## [1.0.0] - 2019-03-25
### Added
* Support for copying to clipboard
* Support for GUI window selection on Sway
* Tray menu
* New `--deps` option to check dependency status
* Support for short options
* Makefile to make installation easier
* Basic error handling and improved output for Curl commands

### Changed
* `--selection` is now `--area` for better cross-compatibility

### Fixed
* Issue where missing required options would not trigger `exit`
* Bug where Nextshot would continue to run when missing one or more required options in config
* Issues with resolving paths in `--file` mode
* Various bugs related to aborting config,s election and upload
* Issue where config wouldn't run if `~/.config/nextshot` existed but was empty


## [0.8.2] - 2019-02-21
### Added
* Extra checks for unset, null and non-integer choices

### Fixed
* Issue introduced in 0.8.1 where empty selection expected integer expression 


## [0.8.1] - 2019-02-21
### Fixed
* Empty window selection would trigger 'unary operator expected' errors


## [0.8.0] - 2019-02-21
### Added
* Support for `--window` mode on Sway via CLI prompt with window list
* Dependency on `jq` for parsing output from swaymsg

### Removed
* Selection fallback warning on Wayland


## [0.7.1] - 2019-02-20
### Fixed
* Minor syntax (quoting) issue


## [0.7.0] - 2019-02-20
### Added
* Support for `--paste` on Wayland

### Changed
* Config colour format is now true RGB
* Config colour is now applied to both Slop (X11) *and* Slurp (Wayland)

### Removed
* Alpha channel is now applied automatically and thus removed from config

### Fixed
* `--window` mode defaulting to `--fullscreen` on Wayland


## [0.6.0] - 2019-02-16
### Added
* Ability to configure Nextshot in CLI when Yad isn't installed
* Sanity check to enforce minimum Bash version

### Fixed
* Issue where Nextshot would attempt to upload non-image files


## [0.5.0] - 2019-02-15
### Added
* `hlColour` config option to set Scrot's highlight colour

### Changed
* `rename` config is now optional and defaults to `false`


## [0.4.1] - 2019-02-14
### Fixed
* Missing help text for `--file` and `--paste` modes
* Syntax complaints from Shellcheck


## [0.4.0] - 2019-02-13
### Added
* Desktop notifications support
* Ability to upload from clipboard


## [0.3.0] - 2019-02-12
### Added
* Support for uploading from file
* Dedicated `--window` mode

### Changed
* Now uses Slop for window selections

### Fixed
* Issue where CURL broke if `server` lacked `https://`


## [0.2.1] - 2019-02-12
### Added
* `--help` CLI option to show usage information
* `--version` CLI option to show Nextshot version


## [0.2.0] - 2019-02-12
### Added
* Support for full-screen screenshots


## [0.1.0] - 2019-02-09
### Added
* Screenshots of selected area
* Nextcloud uploading
* Automatic sharing
* Optional ability to rename before upload
* Copying link to clipboard on X11 and Wayland


[Unreleased]: https://github.com/dshoreman/nextshot/compare/v1.3.2...develop
[1.3.2]: https://github.com/dshoreman/nextshot/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/dshoreman/nextshot/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/dshoreman/nextshot/compare/v1.2.4...v1.3.0
[1.2.4]: https://github.com/dshoreman/nextshot/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/dshoreman/nextshot/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/dshoreman/nextshot/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/dshoreman/nextshot/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/dshoreman/nextshot/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/dshoreman/nextshot/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/dshoreman/nextshot/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/dshoreman/nextshot/compare/v0.8.2...v1.0.0
[0.8.2]: https://github.com/dshoreman/nextshot/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/dshoreman/nextshot/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/dshoreman/nextshot/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/dshoreman/nextshot/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/dshoreman/nextshot/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/dshoreman/nextshot/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/dshoreman/nextshot/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/dshoreman/nextshot/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/dshoreman/nextshot/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/dshoreman/nextshot/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/dshoreman/nextshot/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/dshoreman/nextshot/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dshoreman/nextshot/releases/tag/v0.1.0
