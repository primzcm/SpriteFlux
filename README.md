# SpriteFlux

SpriteFlux is a native macOS menu bar overlay app that displays a floating animated character on top of all windows. It supports looping video plus common image formats with click-through and move modes.

## Features
- Transparent, borderless overlay window that stays on top of all windows and spaces
- MP4/MOV playback via AVFoundation with smooth looping
- GIF, PNG, JPG/JPEG, and WEBP image playback
- Multiple active companions at once, each with its own window and position
- Click-through mode so the overlay never blocks your workflow
- Move mode to drag the overlay anywhere
- Dashboard window that opens automatically on launch and can be reopened from the menu bar icon
- Editable global hotkey for Move Mode, defaulting to Cmd + Shift + M
- Persistent companion scene state (active companions, positions, and controls)
- Saved asset library with copied files, thumbnails, favorites, rename, and delete actions

## Requirements
- macOS 12.0 or later
- Xcode 15 or later

## Run In Xcode
1. Open `SpriteFlux.xcodeproj` in Xcode.
2. Select the `SpriteFlux` scheme.
3. Build and run.

The repo includes a `.gitignore` that excludes common local Xcode artifacts (like `DerivedData` and `xcuserdata`).
The Xcode project also enables a small reviewed subset of current recommended build settings rather than applying Xcode's full automatic migration blindly.

The app runs as a menu bar agent (no Dock icon). The dashboard window opens automatically when SpriteFlux launches. After you hide it, left-click the sparkles icon in the menu bar to show or hide it again (falls back to `SF` if symbols are unavailable). Right-click the icon for quick actions, including Move Mode and Click-through toggles.

## Hotkeys
- Toggle Move Mode: configurable from Dashboard -> Shortcuts…
- Default Move Mode shortcut: Cmd + Shift + M
- The shortcuts view renders modifier keys using native macOS symbols like `⌘` and `⇧`.

## Dashboard Window
- `Open…` Choose an MP4, MOV, GIF, PNG, JPG/JPEG, or WEBP file from disk.
- `Active` Select which companion the controls apply to, or remove active companions from the scene.
- `Move Mode` Enable dragging the overlay.
- `Click-through` Enable or disable mouse passthrough.
- `Reset Position` Move the overlay to the default center-right position.
- `Library` Import assets into SpriteFlux, then add them into the scene, favorite them, rename them, or delete them from the dashboard.
- `Drag and drop` Drop a supported file onto the dashboard to import it into the library and add it as a new companion immediately.
- `Shortcuts…` Open the shortcuts view, edit the Toggle Move Mode hotkey, or go back to the dashboard.
- `Hide Dashboard` Close the dashboard without quitting SpriteFlux.
- `Quit` Exit SpriteFlux.
- The dashboard shows the selected companion plus live Scale/Opacity values for that companion.
- The dashboard uses a wider two-column layout so the active scene and asset library sit beside the controls instead of extending vertically.

## Right-Click Menu
- `Show Dashboard` or `Hide Dashboard` Toggle the dashboard window.
- `Open Asset…` Import media without opening the dashboard first.
- `Move Mode` Toggle overlay dragging directly from the status icon.
- `Click-through` Toggle mouse passthrough directly from the status icon.
- `Reset Position` Move the overlay to the default center-right position.
- `Quit` Exit SpriteFlux.

## Load Assets
Use the dashboard action `Open…`, drag a file onto the dashboard, or use `Library`. Imported assets are copied into SpriteFlux's Application Support folder so the library keeps working even if the original file moves. SpriteFlux currently supports `.mp4`, `.mov`, `.gif`, `.png`, `.jpg`, `.jpeg`, and `.webp` assets. Each imported asset can be added to the scene as its own companion window, and the current scene is restored on launch.
