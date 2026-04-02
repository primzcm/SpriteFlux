TASK_CHECKLIST
DONE
- Scaffolded the AppKit menu bar project and overlay window.
- Implemented video (MP4/MOV) and GIF playback with looping.
- Added click-through behavior, move mode, and global hotkey.
- Built menu bar controls for loading media, toggling modes, resetting position, and quitting.
- Added persistence for window position, selected file, and modes.
- Documented usage and project rules.
- Fixed menu bar initialization order and deprecated file type API usage.
- Made the menu bar item always visible and prevented key-window warnings.
- Ensured the open file dialog appears for the menu bar app.
- Restored the sparkles menu bar icon with a fallback title.
- Enabled drag movement using overlay view mouse events.
- Prevented visual ghosting by disabling background window movement while dragging.
- Improved drag tracking to follow the mouse smoothly.
- Replaced the left-click menu with a hideable dashboard window opened from the status bar icon.
- Added right-click status bar actions for toggling move mode and click-through directly from the icon menu.
- Made the dashboard window open automatically on launch until the user hides it.
- Redesigned the Dashboard UI with fullSizeContentView, sf symbols, NSSwitches, and modern padding.
- Added a dashboard Options button and AppKit keyboard shortcut editor for the Move Mode hotkey.
- Simplified the shortcut editor text to better match the dashboard design.
- Added a back button and recorder-style shortcut field to make the shortcuts view feel closer to the dashboard.
- Refined the shortcuts layout with a centered heading and better-aligned recorder control.
- Restored the shortcut recorder label to its earlier font size after switching to symbol rendering.
- Rendered recorded shortcuts with macOS modifier symbols inside a monospaced shortcut label.
- Polished the dashboard with a loaded-file label, slider value readouts, and clearer labeled actions.
- Added `.gitignore` and removed tracked Xcode `xcuserdata` state files.
- Expanded asset support to include PNG, JPG/JPEG, and WEBP files alongside video and GIF.
- Added a file-backed asset library with copied assets, thumbnails, and dashboard management actions.
- Added drag-and-drop import into the asset library from the dashboard.
- Added multi-companion scene support with persisted active companions and per-companion overlay windows.
- Updated the dashboard to select and manage active companions while adding assets from the library into the current scene.
- Reworked the dashboard into a wider two-column layout to keep the default window height under control.
- Added saved scene presets for named layout save/load/delete actions from the dashboard.
- Reviewed Xcode's recommended settings and applied the safe subset in the project file.

IN-PROGRESS

TODO
- Optional settings expansion for additional shortcut actions, dashboard preferences, richer asset controls, and saved scene presets.
