# Claude Monitor

A macOS menu bar app that shows your [Claude Code](https://claude.ai/code) rate-limit usage at a glance.

![Claude Monitor popover showing current and weekly usage bars](assets/claudecode.png)

---

## Why

Claude Code enforces two rolling rate limits — a **5-hour window** and a **7-day window**. There's no built-in visual indicator, so it's easy to be surprised by throttling mid-session. Claude Monitor puts live percentage bars in your menu bar so you always know where you stand before you hit a wall.

---

## How it works

```
Claude Code hook script
        │
        │  POST /statusline  (JSON)
        ▼
  localhost:22666
  ┌─────────────────────┐
  │  Embedded HTTP server│  ← Network.framework, pure Swift, no dependencies
  │  (StatusLineServer)  │
  └─────────┬───────────┘
            │  in-memory
            ▼
  ┌─────────────────────┐
  │   SwiftUI popover   │  ← NSPanel + NSVisualEffectView, adapts to light/dark mode
  │  Current  ████░ 62% │
  │  Weekly   ██░░░ 34% │
  └─────────────────────┘
```

- **No network calls** — all data stays on-device. The app is a passive listener.
- **No background daemon** — the HTTP server lives inside the menu bar app process.
- **Native macOS UI** — NSPanel popover with `NSVisualEffectView(.popover)` material, semantic colors, auto light/dark switching.
- **Zero external dependencies** — pure Swift, SPM, Network.framework.

The JSON payload Claude Code sends looks like this:

```json
{
  "rate_limits": {
    "five_hour": {
      "used_percentage": 62.5,
      "resets_at": 1748123456
    },
    "seven_day": {
      "used_percentage": 34.1,
      "resets_at": 1748456789
    }
  }
}
```

---

## Build & install

Requirements: macOS 12+, Xcode Command Line Tools.

```bash
git clone https://github.com/tarek360/claude-monitor
cd claude-monitor
bash build.sh
```

This produces `dist/ClaudeMonitor.app`. Drag it to `/Applications` or run it directly.

> **First launch on macOS:** The app is ad-hoc signed but not notarized, so Gatekeeper will block it with a security warning. To open it:
> 1. **Right-click** (or Control-click) the `.app` → choose **Open** → click **Open** in the confirmation dialog.
>
> Alternatively: after dismissing the warning, go to **System Settings → Privacy & Security**, scroll down to *"ClaudeMonitor was blocked"*, and click **Open Anyway**.
>
> You only need to do this once.

---

## Connect Claude Code

Claude Monitor receives data through Claude Code's **statusline hook** — a shell script Claude calls automatically during sessions. You need to add one `curl` line to that script.

### Option A — Let Claude set it up for you (recommended)

Copy the prompt below and paste it into any Claude Code session:

```
I want to connect my Claude Monitor menu bar app (https://github.com/tarek360/claude-monitor).
Please add the following line to my statusline hook script so it sends data to the app.
If I don't have a statusline hook set up yet, create one for me using /statusline.

curl -X POST -H "Content-Type: application/json" -d "$input" http://localhost:22666/statusline 2>/dev/null || true
```

Claude will use the `/statusline` slash command to locate or create your hook script and add the line.

### Option B — Add it manually

Find your statusline hook script (usually `~/.claude/statusline.sh` or wherever `/statusline` configured it) and append:

```bash
curl -X POST -H "Content-Type: application/json" -d "$input" http://localhost:22666/statusline 2>/dev/null || true
```

The `|| true` and `2>/dev/null` ensure Claude Code is never interrupted if the monitor app isn't running.

---

## Usage

- **Left-click** the menu bar icon → opens the usage popover
- **Right-click** → Quit or View on GitHub
- The popover dismisses automatically when you click anywhere else

---

## Project structure

```
macos/
  main.swift               # AppDelegate, NSPanel popover management
  popover_view.swift       # SwiftUI model + views
  statusline_server.swift  # Embedded HTTP server (Network.framework)
  Info.plist
assets/
  claudecode.png           # App header image
scripts/
  build-icon.sh            # Generates AppIcon.icns from icon.svg
Package.swift              # SPM configuration (macOS 11+, no external deps)
build.sh                   # Assembles the .app bundle
```

---

## License

MIT
