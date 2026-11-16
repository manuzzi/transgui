# Transmission Remote GUI

[![CI](https://github.com/transmission-remote-gui/transgui/actions/workflows/ci.yml/badge.svg)](https://github.com/transmission-remote-gui/transgui/actions/workflows/ci.yml)

![Screenshot](https://i.imgur.com/XBbF4Vh.png)

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
  - [Without a package manager](#without-a-package-manager)
  - [Homebrew](#homebrew)
  - [Building from source](#building-from-source)
- [Command line parameters](#command-line-parameters)
- [Portable mode](#portable-mode)
- [Fixed hotkeys](#fixed-hotkeys)
- [Advanced parameters](#advanced-parameters)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Introduction

Transmission Remote GUI is a feature-rich macOS front-end to remotely control a Transmission daemon via its RPC protocol. It is faster and has more functionality than the built-in Transmission web interface.

Transmission Remote GUI is developed using Lazarus RAD and the Free Pascal compiler.

Features:

- Native macOS application
- uTorrent-like interface
- Select files to download
- Choose file priority
- View details about connected peers
- Full information about each torrent
- Per-torrent options

## Installation

The installers are listed on the GitHub [Releases](https://github.com/transmission-remote-gui/transgui/releases/latest) page, and the installation instructions are listed below :arrow_down:

### Without a package manager

This method requires no additional prerequisites or dependencies:

1. Download the disk image from the release page.
2. Open the image file to mount the image.
3. Directly run the application or drag the app icon to your disk / Applications folder.

### Homebrew

You need to have [Homebrew](https://brew.sh/) installed. Execute this command to install Transmission Remote GUI:

- `brew install --cask transmission-remote-gui`

### Building from source

1. Make sure you have Lazarus (Cocoa widgetset) and the Free Pascal compiler installed and working.
2. Download the source archive and extract it to a folder, or clone the repository.
3. Open a terminal and cd to the source folder.
4. Execute the `lazbuild -B transgui.lpi --lazarusdir=<lazarus_dir>` command to build the transgui.res file, replacing `<lazarus_dir>` with your Lazarus installation path.
5. Execute the `make LAZARUS_DIR=<lazarus_dir>` command to build the application.

## Command line parameters

You can specify a path to a .torrent file or a magnet link as a command-line parameter. The program will add the specified torrent.

- `-hidden`: Start the program hidden. Only the program's menu bar icon will be visible.
- `--home=<home_dir>`: Specifies a home directory for the program. All the program's settings are stored in the home directory. You can run multiple instances of the program by specifying different home directories. This option takes precedence over portable mode and the default user-profile location.

## Portable mode

If the program finds the transgui.ini file in the same folder as the binary file, then it will store all configuration and data files in the program's folder, instead of the folder in a user profile.

## Fixed hotkeys

- <kbd>Alt</kbd> + <kbd>1</kbd>: All Torrents
- <kbd>Alt</kbd> + <kbd>2</kbd>: Downloading
- <kbd>Alt</kbd> + <kbd>3</kbd>: Completed
- <kbd>Alt</kbd> + <kbd>4</kbd>: Active
- <kbd>Alt</kbd> + <kbd>5</kbd>: Inactive
- <kbd>Alt</kbd> + <kbd>6</kbd>: Stopped
- <kbd>Alt</kbd> + <kbd>7</kbd>: Error
- <kbd>Alt</kbd> + <kbd>8</kbd>: Waiting
- <kbd>Alt</kbd> + <kbd>S</kbd>: Search box (filter torrents by keywords) - Esc cancels the filter and clears the box.
- <kbd>Alt</kbd> + <kbd>G</kbd>: Info Pane - General Tab
- <kbd>Alt</kbd> + <kbd>K</kbd>: Info Pane - Trackers Tab
- <kbd>Alt</kbd> + <kbd>P</kbd>: Info Pane - Peers Tab
- <kbd>Alt</kbd> + <kbd>F</kbd>: Info Pane - Files Tab

## Advanced parameters

There are some parameters in the `transgui.ini` file that cannot be modified via the GUI.
More info on: [#924](https://github.com/transmission-remote-gui/transgui/issues/924) (File Manager & Shortcuts) and [#1070](https://github.com/transmission-remote-gui/transgui/issues/1070) (.torrent Auto Opening)

```ini
[Interface]
; Maximum number of elements in the folder history list
MaxFoldersHistory=10

[Interface]
; If "Open Container Folder" gives you an error, try the nondefault value
; FileOpenDoc=1 (default 0)

[Interface]
WatchLocalFolder={LOCAL Folder to watch for torrent files}
WatchDestinationFolder={REMOTE destination where the data would be saved; if this value is missing or empty, the last destination folder is used}
; Time period in MINUTES between folder scans for torrents
; Fractional values are allowed; use 0.5 or 0,5 for 30 seconds, depending on locale
WatchInterval=1

[Shortcuts]
; Modify all the shortcuts of the GUI here

[StatusBarPanels]
; Customize the width of the status bar panels to fit your language
; 0 is the leftmost panel and 7 is the rightmost panel.
0=327
1=152
2=152
3=130
4=130
5=130
6=130
7=130

[MainForm]
; Size of the Big Icon Toolbar buttons (defaults to 64 if missing)
BigToolBarHeight=48

[MainForm]
; 1=Shows dates relative to now, 0=Shows absolute dates using the system date and time format
FromNow=1
```

## License

Copyright (c) 2008-2019 by Yury Sidorov and the Transmission Remote GUI working group.

Transmission Remote GUI is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

Transmission Remote GUI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
