# 3. Hotkey window

The most important feature: a terminal that drops down from the edge of the
screen on a global shortcut.

## Behaviour

- **Global shortcut** toggles it from any app (default `⌘⇧\`, configurable).
- **Slides in** from the top edge (top, bottom, left, right or centre,
  configurable). Animation ≤ 150 ms, can be turned off.
- **Shows on every desktop** (Space) and **over full-screen apps**.
- **Opens on the screen under the mouse** (or the main screen, configurable).
- **Hides when you click elsewhere** (configurable).
- **Size** in percent or pixels, for example `height = 45%`, `width = 100%`.
- **Has tabs**, like a normal window. (Ghostty's quick terminal is a single
  session; this one is not.)
- Pressing the shortcut again hides it and gives focus back to the previous
  app.
- Normal windows (`⌘N`) still exist next to the dropdown.
- **Can be turned off** (`hotkey-enabled = false`, or the switch in Settings
  and in the onboarding): the shortcut is released and the dropdown hidden.
- **Shortcut recorder** in Settings and the onboarding: click it, press the
  keys. A shortcut needs ⌘, ⌃ or ⌥ (or is a function key). While it listens,
  the current hotkey is released so it can be pressed again.
- **Dock and app switcher:** with `dock-icon = auto` (default) the app shows
  in the Dock and `⌘⇥` only while a normal window is open. With the dropdown
  alone it stays out of both, like a menu-bar utility (see
  [settings](09-settings.md)).
- **Layout:** with the tabs in a sidebar, the sidebar runs from the top with a
  + and the menu button in its first row (see [look](02-look.md)).

## Implementation notes

- An `NSPanel` (non-activating where useful), borderless, with collection
  behaviour "can join all Spaces" and "full-screen auxiliary".
- **The window is created once at launch and only hidden, never destroyed.**
  Showing it must not start a shell or load anything.
- Global shortcut through the system hot-key API (Carbon `RegisterEventHotKey`
  or a maintained wrapper). This does not need Accessibility permission, unlike
  an event tap. Check again on the target macOS version.
- Launch at login (optional, in config) so the hotkey is always ready.

## Settings example

```json
"hotkey": {
  "shortcut": "cmd+shift+backslash",
  "position": "top",
  "height": "45%",
  "screen": "mouse",
  "autohide": true,
  "animation": 0.12
}
```
