# Cursor Companion

A menu bar helper for macOS that watches your cursor in the background, captures contextual screenshots, and pipes them to an AI that replies with playful, sarcastic commentary. Commentary is spoken aloud in real time (using `AVSpeechSynthesizer`) and mirrored via macOS notifications. A global hotkey lets you pause or resume without touching the UI.

## Features
- Background cursor polling combined with movement/time heuristics to throttle captures.
- Focused screenshot capture: crops around the cursor so the AI sees the relevant context, with optional fallback to full-screen.
- Pluggable AI client: OpenAI (`gpt-4o-mini` by default) or an offline mock when no API key is present.
- Real-time voice playback plus banner notifications (with customizable voice/rate/pitch).
- A floating "fairy" overlay that glides to self-chosen spots, highlights windows/text it finds interesting, and whispers the same quip (toggleable from the menu bar).
- Menu bar controls and a `⌃⌥⌘P` global hotkey to pause/resume the pipeline.
- Permission guidance for Screen Recording & Accessibility.

## Requirements
- macOS 13 or newer (AppKit, AVFoundation, UserNotifications).
- Screen Recording and Accessibility permissions (granted via **System Settings → Privacy & Security**).
- Swift toolchain installed. When running inside a sandboxed environment, point `CLANG_MODULE_CACHE_PATH` to a writable folder (see below).

## Configuration
Set your OpenAI credentials once:

```bash
bash scripts/set_api_key.sh
# Optional: verify what the app sees
bash scripts/check_api_key.sh
```

The setup script also lets you pick an Apple speech voice (e.g. `com.apple.ttsbundle.Samantha-premium`) and tweak rate/pitch for a more natural delivery.

The script saves `config.json` under `~/Library/Application Support/CursorCompanion/`. Subsequent launches (even via the `.app` bundle) will pick up the key, model, and optional base URL automatically. You can still override via environment variables if you prefer.

Without a valid API key, the app stays functional but falls back to a local mock that narrates generic hints.

## Building & Running
From the repository root:

```bash
# Optional: redirect the module cache if the default (~/.cache/clang) is blocked
export CLANG_MODULE_CACHE_PATH="$(pwd)/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

# Option A: run from Xcode (`⌘R`) or `swift run`
swift run

# Option B: package a reusable .app bundle (stable permissions)
bash scripts/package_app.sh            # builds Release & installs ~/Applications/CursorCompanion.app
open ~/Applications/CursorCompanion.app
```

If `swift build` fails due to sandbox restrictions (e.g., when caches under `~/Library` are inaccessible), ensure the module cache export above is set or run outside the sandbox. Once the build succeeds, launch the generated binary or keep it running via `swift run`.

## Using the app
1. On first launch, macOS will prompt for Accessibility and Screen Recording consent. Approve both in **System Settings**.
2. A bolt icon appears in the menu bar. Use it to pause/resume or quit.
3. While active, every ~12 seconds (or after sizable mouse movement) the app captures a cropped region around the cursor and sends it to the configured AI provider.
4. Responses arrive as spoken commentary plus a notification banner. The speech engine interrupts previous utterances for fresh takes.
5. Toggle the fairy overlay directly from the ⚡️ menu if you need a quieter desk.
6. Toggle the pipeline from anywhere with `⌃⌥⌘P`.
7. For consistent macOS permissions, launch the packaged app at `~/Applications/CursorCompanion.app`. Its bundle path stays constant across rebuilds, so Screen Recording and Accessibility approvals stick.

## Extending
- Swap in a different provider by adding a new `AIProvider` implementation (e.g., pointing to a local multimodal server) and injecting it through `AppController`.
- Introduce cropped captures (around the cursor) by extending `ScreenshotCapturer` to create sub-images before encoding.
- Persist transcripts by logging `AIResponse` values to disk.
- Add a proper preferences window for tuning capture cadence, hotkey, or voice settings.

## Caveats & Next Steps
- Continuous screenshots raise privacy considerations; consider adding an allow/deny app list before production use.
- Error handling currently surfaces via notifications; you might want backoff/retry logic for transient network issues.
- Unit/UI tests are not wired up yet. The capture/AI layers should be factored for dependency injection to simplify testing.
- Building via `swift build` may require additional toolchain setup if the installed SDK and compiler versions mismatch.
