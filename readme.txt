Transmission Remote GUI.
Copyright (c) 2008-2019 by Yury Sidorov and the Transmission Remote GUI working group.

Transmission Remote GUI is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

Transmission Remote GUI is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

In addition, as a special exception, OpenVPN Technologies, Inc. gives
permission to link the code of this program with the OpenSSL Library (or with
modified versions of OpenSSL that use the same license as OpenSSL), and
distribute linked combinations including the two. You must obey the GNU General
Public License in all respects for all of the code used other than OpenSSL. If
you modify this file, you may extend this exception to your version of the
file, but you are not obligated to do so. If you do not wish to do so, delete
this exception statement from your version.
*********************************************************************************

Transmission Remote GUI is a feature-rich macOS front-end to remotely control a Transmission daemon via its RPC protocol. It is faster and has more functionality than the built-in Transmission web interface.

Since version 6.0.0 the application is macOS only and runs natively on Apple Silicon and Intel Macs. The original cross-platform project, with Windows and Linux builds, is at https://github.com/transmission-remote-gui/transgui

Transmission Remote GUI is developed using Lazarus RAD and the Free Pascal compiler.

Features:
 * Native macOS application, universal for Apple Silicon and Intel
 * Native macOS notification when a download finishes
 * uTorrent-like interface
 * Select files to download
 * Choose file priority
 * View details about connected peers
 * Full information about each torrent
 * Per-torrent options

Project home:
https://github.com/manuzzi/transgui

INSTALLATION

The disk images are listed on the GitHub Releases page:
https://github.com/manuzzi/transgui/releases/latest

The application needs macOS 14 Sonoma or later. It runs natively on both Apple Silicon and Intel Macs.

Disk image.
This method requires no additional prerequisites or dependencies:
  1. Download the disk image from the release page.
  2. Open the image file to mount the image.
  3. Drag the app icon to your Applications folder and run it from there.

First launch.
A disk image built without a Developer ID certificate, such as the ones produced by the CI workflow of this repository, is signed ad hoc and is not notarized, so macOS blocks the first launch. To open the application anyway:
  1. Try to open it once and dismiss the warning.
  2. Open System Settings > Privacy & Security, scroll to the Security section and click "Open Anyway".
You can also remove the quarantine flag from a terminal: xattr -dr com.apple.quarantine "/Applications/Transmission Remote GUI.app"

Building from source.
An Apple Silicon Mac is required: the Intel half of the universal application is cross-compiled and runs under Rosetta 2. The application needs macOS 14 or later.
- Clone the repository and cd to the "setup/macosx" folder;
- Execute "./install_deps.sh" to install Free Pascal 3.2.2 and Lazarus 4.8 into ~/pascal-toolchain (set TOOLCHAIN_DIR to use another folder). It does not need sudo and changes nothing outside that folder;
- Execute "./create_app_new.sh" to build the universal (arm64 and x86_64) application with OpenSSL 3 bundled inside, and to create "Release/transgui-<version>.dmg".
The application is signed ad hoc, which is enough to run it on the Mac that built it. To sign with a Developer ID and to notarize the disk image, set CODESIGN_IDENTITY to your identity and NOTARY_PROFILE to a keychain profile created with "xcrun notarytool store-credentials" before running the script.

NOTIFICATIONS AND PERMISSIONS

The application shows a native macOS notification when a download finishes.
- Turn it on or off with "Show notifications" on the General tab of the Options dialog. It is on by default and does not depend on the menu bar icon options.
- The first time, macOS asks for permission to show notifications. You can change your answer later in System Settings > Notifications > Transmission Remote GUI.
- Notifications are shown only when the application runs from its .app bundle, not when the bare binary is started from a build folder.
- On macOS Sequoia and later, macOS may also ask for permission to use the local network, which the application needs to reach a Transmission daemon on your network.

COMMAND LINE PARAMETERS

You can specify a path to a .torrent file or a magnet link as a command-line parameter. The program will add the specified torrent.

-hidden: Start the program hidden. Only the program's menu bar icon will be visible.
--home=<home_dir>: Specifies a home directory for the program. All the program's settings are stored in the home directory. You can run multiple instances of the program by specifying different home directories. This option takes precedence over portable mode and the default user-profile location.

PORTABLE MODE

If the program finds the transgui.ini file in the same folder as the binary file, then it will store all configuration and data files in the program's folder, instead of the folder in a user profile.

FIXED SHORTCUTS

Alt + 1: All Torrents
Alt + 2: Downloading
Alt + 3: Completed
Alt + 4: Active
Alt + 5: Inactive
Alt + 6: Stopped
Alt + 7: Error
Alt + 8: Waiting
Alt + S: Search box (filter torrents by keywords) - Esc cancels the filter and clears the box.
Alt + G: Info Pane - General Tab
Alt + K: Info Pane - Trackers Tab
Alt + P: Info Pane - Peers Tab
Alt + F: Info Pane - Files Tab


ADVANCED PARAMETERS

There are some parameters in the transgui.ini file that cannot be modified via the GUI.
More info on: https://github.com/transmission-remote-gui/transgui/issues/924 (File Manager & Shortcuts)
and https://github.com/transmission-remote-gui/transgui/issues/1070 (.torrent Auto Opening)

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
*********************************************************************************
Big Icons

Farm-Fresh Fatcow Web Hosting
http://www.fatcow.com/
License Creative Commons (Attribution 3.0 United States)
https://creativecommons.org/licenses/by/3.0/us/legalcode

Visual Farm
http://icons8.com/
License Creative Commons Attribution-No Derivative Works 3.0 Unported
https://creativecommons.org/licenses/by-nd/3.0/legalcode
