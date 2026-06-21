# Hush

**A voice-synced, screen-share-invisible teleprompter for macOS.**

Hush puts your script right at the camera so you keep eye contact, scrolls it **as you speak** (and waits when you pause), and stays **invisible during screen sharing** — Zoom, Teams, Meet, Loom, OBS, and even screenshots never see it.

> Status: **early (M0–M1)**. The core voice-sync engine is implemented and tested (52 self-test checks). The macOS app — Ghost Mode overlay, notch placement, live mic→on-device-speech→spring-eased scroll pipeline, 3-2-1 countdown, and a script library/editor — is implemented and compiles; on-device tuning of the scroll feel is the next pass. See the [roadmap](#roadmap).

---

## How it works

- **Ghost Mode** — the overlay window sets `NSWindow.sharingType = .none`, which removes it from `ScreenCaptureKit` / `CGWindowList` output. Viewers and recordings never see it; you do. ([`GhostPanel.swift`](Sources/HushApp/GhostPanel.swift))
- **Voice-synced scrolling** — a hybrid engine combines on-device speech recognition with a bounded sequence-alignment matcher to track *where you are* in the script, plus a voice-activity fallback so it keeps moving when recognition stalls and freezes on silence. ([`ScrollSyncEngine.swift`](Sources/HushCore/ScrollSyncEngine.swift))
- **Notch-aware placement** — the prompter centers under the camera notch (or top-center on non-notch displays), floats over full-screen apps, shows on every Space, and never steals focus. ([`GhostPanel`](Sources/HushApp/GhostPanel.swift) + [`ScreenGeometry`](Sources/HushApp/ScreenGeometry.swift))
- **On-device & private** — speech and audio are processed locally; nothing leaves your Mac.

## Architecture

`HushCore` is a **pure, dependency-free** Swift module — no AppKit / AVFoundation / Speech imports — so the entire voice-sync pipeline is deterministically testable headlessly. Audio and speech enter through the `AudioSource` / `SpeechSource` protocols, which the app implements with `AVAudioEngine` and `SFSpeechRecognizer`, and which tests implement with fixture replay.

```
Sources/
  HushCore/      pure logic: Tokenizer, Normalizer, Alignment, VADEngine,
                 ScrollSyncEngine, Calibration, AudioSource/SpeechSource protocols
  HushCheck/     portable self-test: replays synthetic fixtures, asserts gates
  HushApp/       macOS app shell: GhostPanel, ScreenGeometry, PrompterView, menu bar
docs/            design spec, user flows, exhaustive test plan, synthetic data
app/             XcodeGen project for producing the signed .app bundle
```

## Build & test

Requires the Swift toolchain (Xcode or Command Line Tools).

```bash
swift build              # builds HushCore, HushCheck, and the app shell
swift run HushCheck      # runs the voice-sync self-test (no Xcode needed)
```

`HushCheck` replays the synthetic ASR fixtures in [`docs/synthetic-data.md`](docs/synthetic-data.md) through the engine and asserts the acceptance gates in [`docs/test-plan.md`](docs/test-plan.md) — e.g. clean-read accuracy within ±3 tokens, number/acronym normalization, ad-lib hold-then-resync, and no scroll runaway on silence.

### Building the macOS app bundle

The app shell compiles with `swift build`. To produce a runnable, signable `.app` (menu-bar agent, mic/speech usage strings, bundle id `com.iamabhishekmathur.hush`):

```bash
brew install xcodegen
cd app && xcodegen generate && open Hush.xcodeproj
```

## Roadmap

| Milestone | Scope |
|-----------|-------|
| **M0** ✅ | Overlay panel + Ghost Mode + notch placement · pure `ScrollSyncEngine` + replay tests |
| **M1** ✅ | Live `AVAudioEngine` + on-device `SFSpeechRecognizer` (`LiveMic`) · `PresentationCoordinator` (VAD + sync + `SpringScroller`) · countdown · script library + editor |
| M2 | On-device scroll-feel tuning (TextKit per-token offsets) · calibration onboarding · settings |
| M3 | Global hotkeys · manual override polish · accessibility pass |
| M4 | Permissions/error flows · multi-monitor · perf hardening |
| M5 | Signing/notarization · onboarding polish · release |

Full design lives in [`docs/`](docs): [dev-spec](docs/dev-spec.md) · [user-flows](docs/user-flows.md) · [test-plan](docs/test-plan.md) · [synthetic-data](docs/synthetic-data.md).

## Acknowledgements

Inspired by the macOS notch-teleprompter category (Moody, Notchie, NotchPrompter). Hush is an independent, open-source take.

## License

[MIT](LICENSE) © 2026 Abhishek Mathur
