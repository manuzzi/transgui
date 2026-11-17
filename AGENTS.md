# Repository Guidelines

## Project Overview

Transmission Remote GUI is a Lazarus/Free Pascal macOS (Cocoa) desktop client for Transmission's JSON-RPC API. `transgui.lpr` is the entry point, `transgui.lpi` stores Lazarus project settings, and most application code lives in root `.pas` units paired with `.lfm` form resources. Keep this file focused on repository-specific guidance; README, `.github/workflows/ci.yml`, `Makefile.fpc`, and scripts under `setup/macosx/` remain the source of truth for detailed commands and packaging flows.

## Project Structure & Architecture

- `main.pas`/`main.lfm` define `TMainForm`, the central UI, torrent grid, menus, tray behavior, and much of the app workflow.
- `rpc.pas` owns Transmission daemon communication through Synapse HTTP/SSL code. `TRpcThread` performs background polling and uses `Synchronize` for UI updates, so daemon-facing behavior should generally go through this layer rather than direct UI-side HTTP calls.
- `baseform.pas` provides shared form behavior for dialogs such as `AddTorrent`, `ConnOptions`, `Options`, and `TorrProps`.
- `varlist.pas` and `vargrid.pas` implement the custom data/grid layer used by torrent, peer, tracker, and file lists.
- `restranslator.pas` loads `lang/transgui.*` files at runtime; this is the app's own localization system.
- `utils.pas` contains UTF-8-safe file/config helpers, including `TIniFileUtf8`; prefer the existing UTF-8 wrappers used by the app over plain RTL path/file APIs.
- `synapse/source/lib` is vendored networking code. Treat `synapse/` as third-party code unless applying a deliberate upstream or security fix. It still contains code for other operating systems; leave it as is.
- `setup/macosx/` contains the macOS packaging scripts; `rpc-spec.txt` documents the Transmission RPC protocol.

Generated top-level output directories include `units/`, `lib/`, and `Release/`; other generated outputs include `*.lrs`, `*.res`, and the `transgui` binary. Avoid committing generated artifacts. `Makefile` is tracked but generated from `Makefile.fpc`, so do not hand-edit it for build-rule changes; when build rules change, regenerate it using `fpcmake` and commit the tracked derived file with the source change.

## Build, Test, and Development Commands

An Apple Silicon Mac is required. `setup/macosx/install_deps.sh` installs Free Pascal 3.2.2 and Lazarus into `~/pascal-toolchain` (override with `TOOLCHAIN_DIR`) without `sudo`. The path examples below use `<lazarus_dir>`, which is `~/pascal-toolchain/lazarus` by default.

Free Pascal 3.2.2 emits Objective-C metadata that the current Apple linker rejects (`malformed method list atom`). The toolchain therefore uses the assembler shim in `setup/macosx/fpc-asm-shim/`, and the LCL and every package must be compiled with that toolchain: do not use a prebuilt Lazarus.

Do not enable size optimization (`-Os`, Lazarus "Smaller code") in `transgui.lpi`. With it, Free Pascal 3.2.2 on aarch64 compiles block copies of packed records (for example `TTextStyle` in `DrawProgressCell`, or `TVarSin` in Synapse) into a loop that copies four times too many bytes. That overwrites the stack, and the app exits silently with code 255 as soon as the torrent list is painted. A smoke test with `-hidden` never paints, so check changes with a visible window and at least one torrent.

- `setup/macosx/create_app_new.sh` builds the universal (arm64 + x86_64) app bundle with OpenSSL 3 and creates the DMG in `Release/`.
- `lazbuild -B -r transgui.lpi --lazarusdir=<lazarus_dir> --compiler=<ppca64|ppcx64> --cpu=<aarch64|x86_64> --widgetset=cocoa` builds one architecture; the binary is written to `units/transgui`. Register the `trcomp` package first with `lazbuild -B -r trcomp.lpk` and the same options.
- `make clean` removes compiler output.

The macOS packaging entry points live under `setup/macosx/`; consult those scripts instead of duplicating their flow here. They sign ad hoc by default; `CODESIGN_IDENTITY` and `NOTARY_PROFILE` (a `notarytool` keychain profile) enable Developer ID signing and notarization. Some release scripts stamp build metadata into tracked files temporarily, so check `git status` afterward.

## Coding Style & Localization

Follow `.editorconfig` for charset, line endings, final newlines, trailing whitespace, and indentation; preserve its listed exceptions. Preserve `{$mode objfpc}{$H+}` and existing filename casing; avoid case-only renames. The project targets macOS only, so do not add code paths or conditional compilation for other operating systems. Use English for code comments. Form classes generally use `T<Name>Form`, and UI changes should keep `.pas` units and matching `.lfm` files synchronized. Avoid manual `.lfm` edits unless they are small, intentional, and compatible with Lazarus output.

For localization, update `lang/transgui.template` and affected `lang/transgui.*` files together when changing user-visible strings. Preserve keys, placeholders, quoting, and placeholder order. When bumping releases, keep `VERSION.txt`, `main.pas` `AppVersion`, `transgui.lpi` version metadata, and `history.txt` consistent.

## Runtime Configuration & Portability

The app stores settings with `TIniFileUtf8` to preserve UTF-8 paths and values. Home directory resolution is part of startup behavior: `--home=<dir>` overrides the default, an `.ini` file next to the executable with the same base name enables portable mode, and otherwise the app falls back to the platform configuration directory. When changing startup, file, or path handling, preserve this behavior on macOS.

## Testing & Verification

There is no automated Pascal unit-test suite. Validate code changes with the smallest relevant build or check for the touched area, and manually exercise affected UI, localization, configuration, or RPC flows when behavior changes. For packaging changes, use the matching platform script when feasible and verify the produced artifact. If a check is skipped, record why.

## Commit & Pull Request Guidelines

Recent commits use imperative, capitalized subjects without Conventional Commit prefixes, for example `Fix overflow in Base32 decode`. Keep changes focused: separate code fixes, localization refreshes, and packaging updates. Pull requests should summarize impact, list commands and manual checks run, link related issues, and include screenshots or recordings for UI-visible changes. Mention skipped checks with the reason rather than leaving verification ambiguous.

## Safety & Configuration Notes

Ask before adding dependencies, deleting locales, renaming units, or changing packaging/signing pipelines. Do not log or hardcode signing keys, API tokens, or release credentials. Before finishing, check `git status` and ensure generated backups such as `about.lfm.bak` are gone or intentionally excluded.
