# SpriteFlux

SpriteFlux is a native macOS menu bar overlay app that displays a floating animated character on top of all windows. It supports looping video (MP4/MOV) and GIF playback with click-through and move modes.

## Features
- Transparent, borderless overlay window that stays on top of all windows and spaces
- MP4/MOV playback via AVFoundation with smooth looping
- GIF playback fallback
- Click-through mode so the overlay never blocks your workflow
- Move mode to drag the overlay anywhere
- Dashboard window that opens automatically on launch and can be reopened from the menu bar icon
- Global hotkey: Cmd + Shift + M
- Persistent overlay state (position, file path, modes)

## Requirements
- macOS 12.0 or later
- Xcode 15 or later

## Run In Xcode
1. Open `SpriteFlux.xcodeproj` in Xcode.
2. Select the `SpriteFlux` scheme.
3. Build and run.

The app runs as a menu bar agent (no Dock icon). The dashboard window opens automatically when SpriteFlux launches. After you hide it, left-click the sparkles icon in the menu bar to show or hide it again (falls back to `SF` if symbols are unavailable). Right-click the icon for quick actions, including Move Mode and Click-through toggles.

## Hotkeys
- Toggle Move Mode: Cmd + Shift + M

## Dashboard Window
- `Open Animation File...` Choose an MP4, MOV, or GIF from disk.
- `Move Mode` Enable dragging the overlay.
- `Click-through` Enable or disable mouse passthrough.
- `Reset Position` Move the overlay to the default center-right position.
- `Hide Dashboard` Close the dashboard without quitting SpriteFlux.
- `Quit` Exit SpriteFlux.

## Right-Click Menu
- `Show Dashboard` or `Hide Dashboard` Toggle the dashboard window.
- `Open Animation File...` Choose media without opening the dashboard first.
- `Move Mode` Toggle overlay dragging directly from the status icon.
- `Click-through` Toggle mouse passthrough directly from the status icon.
- `Reset Position` Move the overlay to the default center-right position.
- `Quit` Exit SpriteFlux.

## Load GIF Or Video
Use the dashboard action `Open Animation File...` and select a `.gif`, `.mp4`, or `.mov` file. The overlay will resize to fit the media and loop automatically.
