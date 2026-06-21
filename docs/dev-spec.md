# Hush — Development Spec

## 1. Goals & non-goals
**Goal:** presenter reads a script at camera level, the script scrolls in sync with their speech, and the prompter is invisible to anyone watching a screen share or screenshot. Feels "magic" = scroll responds to speech in < 300 ms and tracks position, not just volume.

**Non-goals (v1):** Windows, cloud sync, non-English ASR, AI generation, hardware beam-splitter mode.

## 2. Platform & stack
- **Min OS:** macOS 14.7 (Sonoma). **Arch:** universal (Intel + Apple Silicon).
- **UI:** SwiftUI + AppKit (`NSPanel`, `NSHostingView`).
- **Audio:** AVFoundation (`AVAudioEngine`).
- **Speech:** Speech.framework (`SFSpeechRecognizer`, `requiresOnDeviceRecognition = true`).
- **Persistence:** SwiftData (scripts), UserDefaults via `@AppStorage` (settings), Keychain (license).
- **Global hotkeys:** `CGEvent` tap or a small lib (e.g. KeyboardShortcuts).
- **No dock icon:** `LSUIElement` / `NSApp.setActivationPolicy(.accessory)`; control via `MenuBarExtra`.

## 3. Module architecture
```
App (SwiftUI @main, .accessory)
├── MenuBarController        — MenuBarExtra: play/pause, script picker, open editor/settings, quit
├── OverlayWindowController  — owns the NSPanel (Ghost Mode, notch, spaces, non-activating)
│     └── PrompterView (SwiftUI in NSHostingView): text, reading line, volume beam, hover chrome
├── PresentationCoordinator  — session state machine; wires audio→sync→scroll; owns countdown/end
│
├── AudioSource (protocol)            ── LiveAudioSource (AVAudioEngine tap)  | MockAudioSource (replay)
├── SpeechSource (protocol)           ── LiveSpeechSource (SFSpeechRecognizer)| MockSpeechSource (replay)
├── VADEngine                — RMS/dB → isSpeaking, beamLevel  (PURE)
├── ScrollSyncEngine         — tokens + ASR results + VAD → target token index  (PURE, the core)
├── ScrollAnimator           — spring from current→target y at 60 fps
├── Calibration              — noise floor, speaking dB, WPM, mic gain
│
├── ScriptStore (SwiftData)  — CRUD, import, tokenization cache, read-time estimate
├── SettingsStore            — appearance, voice, hotkeys, target display
├── PermissionsManager       — mic + speech TCC state + recovery deep-links
├── ScreenGeometry           — notch / safeAreaInsets / target-screen frame
└── LicenseManager           — Keychain store + offline grace + verify endpoint
```
**Testability rule:** `VADEngine`, `ScrollSyncEngine`, `Calibration`, tokenizer, and `LicenseManager` have **zero** AVFoundation/Speech/AppKit imports. Audio and speech enter only through the `AudioSource`/`SpeechSource` protocols, so tests replay fixtures on a virtual clock.

## 4. Overlay window (Ghost Mode + notch + spaces)
`NSPanel` subclass config:
```swift
styleMask = [.nonactivatingPanel, .borderless, .resizable]
isFloatingPanel = true
level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
hidesOnDeactivate = false
isMovableByWindowBackground = true
backgroundColor = .clear ; isOpaque = false ; hasShadow = false
// GHOST MODE — the whole trick:
sharingType = .none        // excluded from ScreenCaptureKit / CGWindowList / screenshots
// toggle .none <-> .readOnly for ghost on/off
```
- **Non-activating** = never steals focus; the app you present from stays key. Override `canBecomeKey = false`, `canBecomeMain = false`.
- **Hover-pause / click-through:** default `ignoresMouseEvents = true` so clicks pass to the app behind; on cursor-in-region (tracking area) show chrome and pause; on click of a control, temporarily accept events.
- **Notch placement:** `ScreenGeometry` reads target `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea`+`auxiliaryTopRightArea`. Notch present → center panel under it, top-anchored. No notch (external/Intel) → top-center fallback with a thin handle.
- **Multi-monitor:** panel lives on `SettingsStore.targetScreen` (default: screen that has the menu bar / where launched). `.canJoinAllSpaces` keeps it on every Space of that display.

## 5. Audio + VAD
- `AVAudioEngine` install tap on input node, 100 ms hop, mono, 16 kHz downsample (matches ASR).
- `VADEngine.update(rms)` → dBFS; `isSpeaking = dB > vadThreshold` with attack 80 ms / release 250 ms; `silenceToPause` after 600 ms below threshold. `beamLevel` = smoothed normalized RMS (drives the volume beam).
- Same tap feeds both VAD and the `SpeechSource` (single mic stream).

## 6. Speech recognition layer
- `SFSpeechRecognizer(locale: en-US)`, `requiresOnDeviceRecognition = true`, `addsPunctuation = false`, `taskHint = .dictation`.
- Stream partial results; on each partial, extract recognized token list + segment confidences.
- Recognizer has a max utterance length → **rotate** the recognition request every ~50 s or on long silence to avoid the 1-minute cap; carry `anchor` across rotations.
- If speech permission denied or recognizer unavailable → degrade to **VAD-only creep mode** (still usable, just no word-tracking).

## 7. Scroll-sync engine (the core algorithm)
**Inputs:** tokenized script (`tokens[i] = {norm, yOffset, distinctive}`); stream of ASR partials; VAD `isSpeaking`.
**Output:** `targetTokenIndex` → `scrollTarget = tokens[i].yOffset - readingLineOffset`.

**State & config**
```
anchor          : Int   = 0      // best estimate of last-spoken token
mode            : voiceSynced | vadCreep | frozen | manual
TAIL    = 5      // # recognized content-words used to match
BACK    = 4      // search window behind anchor
AHEAD   = 18     // search window ahead of anchor
MIN_CONF= 0.55   // accept threshold (normalized alignment score)
MAX_JUMP= 12     // cap forward token advance per accepted match
STOPWORDS = {the,a,an,and,of,to,in,is,it,uh,um,like,you-know,...}
```

**Tokenization (pre-pass, cached per script)**
1. Split on whitespace; lowercase; strip punctuation.
2. Normalize for ASR drift: numbers↔words ("10"↔"ten", "99.9"↔"ninety nine point nine"), currency ("$29"↔"twenty nine dollars"), acronyms ("API"↔"a p i"). Keep map both directions.
3. Mark `distinctive = !STOPWORDS.contains(norm) && len ≥ 4` (used to reject false jumps on common words).
4. Record each token's rendered `yOffset` (filled after layout).

**Per ASR-partial update**
```
tail = lastN(contentWords(recognized), TAIL)          // drop stopwords/fillers
if tail.isEmpty: return
window = tokens[clamp(anchor-BACK) ... clamp(anchor+AHEAD)]
(matchEnd, score) = boundedAlign(tail, window)        // see scoring
if score >= MIN_CONF and matchEnd >= anchor-2 and tailHasDistinctiveMatch:
    anchor = clamp(matchEnd, anchor, anchor+MAX_JUMP)  // forward, small back allowed
    scrollTarget = tokens[anchor].yOffset - readingLineOffset
    mode = .voiceSynced
else:
    mode = vad.isSpeaking ? .vadCreep : .frozen
```

**boundedAlign** = local sequence alignment (bounded Smith–Waterman) of `tail` against `window`. Substitution scores: exact 1.0 · number/acronym-normalized 0.9 · phonetic match (Double Metaphone) 0.6 · else −0.3. Gap penalty −0.4. Return best end-index in script coords and `score/len(tail)`.

**Per audio buffer**
```
vad.update(rms)
if mode == .vadCreep and vad.isSpeaking:
    scrollTarget += creepVelocity * dt        // creepVelocity from calibrated WPM
beamLevel = smooth(rms)
if !vad.isSpeaking for > silenceToPause: scrollTarget velocity → 0  (no runaway)
```

**Render loop (CADisplayLink / TimelineView, 60 fps)**
```
scrollY = criticallyDampedSpring(scrollY, scrollTarget, dt)   // never jerks; honor Reduce Motion → snap
```

**Edge handling**
- **Ad-lib (off-script):** no match → `frozen`/gentle creep; resume when distinctive script words reappear.
- **Skip ahead:** distinctive match far ahead within AHEAD → jump (capped by MAX_JUMP per tick, so a big skip catches up over a few ticks).
- **Repeat / restart line:** small backward (≤2) allowed; larger backward needs 2 consecutive confirming matches.
- **Common-word trap:** require ≥1 distinctive token in the matched span before accepting.
- **Manual override:** user trackpad/key scroll → `mode = .manual` for 4 s, then re-anchor to nearest distinctive match.

## 8. Calibration ("learns your voice")
Onboarding reads a fixed 3-sentence passage. Measure & persist per-profile:
- `noiseFloorDb` (first 1 s of silence), `speakingDb` → `vadThreshold = mean(noiseFloor, speaking) `
- `avgWPM` (words / elapsed) → `creepVelocity`
- `micGain` recommendation if input too hot/quiet
Re-runnable from Settings → Voice.

## 9. Script model & persistence (SwiftData)
```
Script { id, title, body (attributed), createdAt, updatedAt, orderIndex,
         wordCount(derived), estReadSeconds(derived from avgWPM),
         tokenCacheVersion, settingsOverride? (font/speed) }
```
- Import: `.txt`, `.md`, `.rtf`, paste, drag-drop. Markdown headings → section breaks; blank line → paragraph gap.
- Inline markers (optional, MVP-light): `[[pause]]`, `[[slow]]`, `## section` for editor structure.

## 10. Settings model
`General` (launch at login, target display, countdown seconds) · `Appearance` (font family/size, weight, color, background opacity, line spacing, reading-line position, mirror off) · `Voice & Scroll` (voice-sync on/off, mic device, sensitivity, fallback creep speed, recalibrate) · `Hotkeys` (global: start/stop, pause, faster/slower, bigger/smaller, ghost toggle; with conflict detection) · `Privacy` (mic + speech status + open-System-Settings deep links) · `License` · `About/Updates`.

## 11. Licensing
- Payhip license key → `LicenseManager.activate(key)` → POST verify endpoint → store signed entitlement in Keychain.
- **Offline grace:** valid entitlement cached; re-verify every 14 days, 30-day offline grace.
- States: `trial` (e.g. 7-day or watermark), `licensed`, `expired`, `invalid`, `seatExhausted`.

## 12. Permissions & error handling
| Condition | Behavior |
|-----------|----------|
| Mic not granted | Block voice-sync; banner + button → `x-apple.systempreferences:...Privacy_Microphone` |
| Speech not granted | Run **VAD-only** mode; non-blocking notice |
| Mic busy / no input device | Toast; auto-recover on device change (`AVAudioEngine` config-change notif) |
| Audio device changes mid-session | Reconfigure tap, keep session, re-warm ASR |
| No notch / external display | Top-center fallback placement |
| macOS < 14.7 | Hard gate at launch with message |
| Recognizer 1-min cap hit | Auto-rotate request, preserve anchor |

## 13. Performance budgets
- Word→scroll latency **p95 < 300 ms**. · Render **60 fps**, zero dropped frames during scroll.
- CPU during presentation: **< 15%** (Apple Silicon), < 25% (Intel). · Memory **< 250 MB**.
- Cold launch to ready **< 1.5 s**. · Audio hop 100 ms.

## 14. Security & privacy
- All audio/speech on-device; nothing leaves the Mac except the license-verify call (key only).
- Ghost Mode (`sharingType = .none`) verified against every capture path (test plan §7).
- No analytics by default; if added, opt-in and event-only (no script content).

## 15. Build & distribution
- Universal binary, hardened runtime, Developer ID signing, **notarization + stapling** for Payhip download.
- Entitlements: `com.apple.security.device.audio-input`, Speech usage strings (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`).
- Auto-update: Sparkle (direct build). MAS build later (sandboxed; same APIs are sandbox-safe).

## 16. Milestones
| M | Deliverable | Exit criteria |
|---|-------------|---------------|
| M0 | Overlay panel + Ghost Mode + notch placement | Invisible in Zoom + screenshot; floats over fullscreen; never steals focus |
| M1 | Script store + editor + manual scroll + countdown | Create/edit/run a script, manual + hotkey scroll |
| M2 | VAD creep + volume beam + calibration | Scroll follows speech energy; pauses on silence within 600 ms |
| M3 | ASR word-alignment (ScrollSyncEngine) | Meets voice-sync acceptance metrics (test plan §4) on fixtures |
| M4 | Settings, hotkeys, permissions/error states | All flows F & H pass |
| M5 | Licensing, signing/notarization, onboarding polish | Release-gate checklist green |
