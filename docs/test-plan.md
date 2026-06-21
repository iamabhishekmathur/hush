# Hush — Test Plan (exhaustive)

Maps every user flow (`user-flows.md` A–H) to test cases, defines the automated replay harness that makes voice-sync deterministically testable, sets numeric acceptance gates, and catalogs the synthetic inputs (in `synthetic-data.md`).

## 1. Strategy & levels
| Level | What | Tooling | Where it runs |
|-------|------|---------|---------------|
| Unit | Pure engines: tokenizer, `VADEngine`, `ScrollSyncEngine`, `Calibration`, normalizer, `LicenseManager` | XCTest | CI, headless |
| Replay/integration | Full audio→sync→scroll pipeline driven by **fixtures** through `MockAudioSource`/`MockSpeechSource` on a virtual clock | XCTest + fixture loader | CI, headless |
| UI / snapshot | SwiftUI views (editor, settings, prompter, onboarding) | XCUITest + snapshot (pointfree-style) | CI (mac runner) |
| Manual / exploratory | Ghost Mode in real capture tools, real-mic voice feel, multi-monitor, fullscreen | Scripted manual checklist | Local Macs |
| Performance | Latency, fps, CPU, memory | Instruments + XCTest `measure` | Local + nightly |
| Accessibility | VoiceOver, keyboard-only, contrast, Reduce Motion | Accessibility Inspector + manual | Local |
| Compatibility | OS/arch/display matrix | Matrix run | Lab Macs / VMs |

**Design constraint that makes this work:** `ScrollSyncEngine` + `VADEngine` import no AVFoundation/Speech/AppKit. Audio and ASR enter via `AudioSource`/`SpeechSource` protocols. Tests feed timestamped fixtures (`synthetic-data.md`) through mocks on a virtual clock and assert the **scroll-index trajectory** — no mic, no human, fully deterministic.

## 2. Test environment matrix
| Axis | Values |
|------|--------|
| OS | macOS 14.7, 15.x, 26.x (and an unsupported 14.6 for the hard-gate test) |
| Arch | Apple Silicon (M-series), Intel |
| Display | built-in notch, built-in non-notch, external single, dual-monitor (notch + external) |
| Mic | built-in, AirPods/BT, USB interface |
| Capture tools | Zoom, Teams, Google Meet, Loom, OBS, QuickTime, macOS screenshot/record |
| Locale/voice | en-US native, en-US accented (non-native), fast speaker, slow speaker |

## 3. Automated replay harness
**Fixture format** (see `synthetic-data.md` for instances):
- `script.txt` — raw script.
- `asr-stream.jsonl` — one event per line: `{t_ms, partialTokens:[...], segmentConfidence}` simulating `SFSpeechRecognizer` partials (including realistic misrecognitions).
- `vad-stream.jsonl` — `{t_ms, rms_db}` (or derived from a label track) for `isSpeaking`.
- `ground-truth.jsonl` — `{t_ms, expectedTokenIndex}` (the word the presenter is actually on).

**Harness loop:** advance virtual clock; deliver audio + ASR events at their `t_ms`; sample `ScrollSyncEngine.anchor`/`scrollTarget`; compare to ground truth → emit metrics. Deterministic, repeatable, runs in CI.

## 4. Acceptance gates (numeric)
**Voice-sync (per fixture class):**
| Metric | Clean read | Paused | Ad-lib | Skip/jump | Noisy/accented |
|--------|-----------|--------|--------|-----------|----------------|
| Frames within ±3 tokens of ground truth | ≥ 92% | ≥ 88% | ≥ 75% | ≥ 80% | ≥ 70% |
| Re-sync time after divergence (median / p95) | — | ≤0.8s/2s | ≤1.5s/3s | ≤1.2s/2.5s | ≤2s/4s |
| Unintended jumps > MAX_JUMP per 500 words | < 1 | < 1 | < 2 | n/a | < 2 |
| Word→scroll latency p95 | < 300 ms | < 300 ms | — | < 350 ms | < 400 ms |
| Silence → velocity 0 | ≤ 600 ms in all classes |

**System:** 60 fps during scroll (zero dropped frames > 1/sec); CPU < 15% AS / < 25% Intel; memory < 250 MB; cold launch < 1.5 s.
**Ghost Mode:** 0 pixels of overlay in **every** capture tool in §7. **Focus:** 0 focus-steal events in flow E3.
**Release gate:** all P0/P1 cases pass; voice-sync gates met on full fixture set; Ghost matrix 100%; a11y P0 pass; no P0/P1 open bugs.

## 5. Test suites by flow

### Suite A — Onboarding (P0)
| ID | Case | Input | Expected |
|----|------|-------|----------|
| A-01 | First launch shows Welcome | fresh install | Welcome sheet + menu bar icon; no dock icon |
| A-02 | Mic grant happy path | click Allow | proceeds to speech step |
| A-03 | Mic denied recovery | click Deny | recovery card + working System Settings deep link; grant later → unblocks without relaunch |
| A-04 | Speech denied → VAD mode | Deny speech | onboarding continues; app flagged VAD-only |
| A-05 | Calibration captures profile | read passage (fixture P-CAL) | noiseFloor/speaking/WPM stored; values within sane bounds |
| A-06 | Calibration with silence | say nothing 10 s | graceful "couldn't hear you, retry" |
| A-07 | Position preview under notch | notch Mac | overlay centered under notch; drag persists |
| A-08 | First script via sample | choose sample | sample loaded, lands IDLE |
| A-09 | Quit mid-onboarding | quit at step 4 | relaunch resumes at step 4 |

### Suite B — Script management (P0/P1)
| ID | Case | Input | Expected |
|----|------|-------|----------|
| B-01 | Create new | New Script | empty titled doc, editor focus |
| B-02 | Autosave + counts | type 200 words | word count + read-time live; persists on relaunch |
| B-03 | Paste 5k words | fixture S-LONG | no UI lag > 100 ms; tokenization async |
| B-04 | Duplicate | Duplicate | "copy" suffix, independent edits |
| B-05 | Delete + undo | Delete | confirm sheet; undo toast restores |
| B-06 | Rename | edit title | persists |
| B-07 | Reorder | drag rows | order persists across relaunch |
| B-08 | Search | query | title+body match, case-insensitive |
| B-09 | Import .txt/.md/.rtf | fixtures S-MD, S-RTF | content + sections correct |
| B-10 | Import garbage | binary file renamed .txt | rejected with message, no crash |
| B-11 | Empty script run | 0 words | Start disabled or "nothing to present" |
| B-12 | Emoji / RTL / unicode | fixture S-UNICODE | renders; tokenizer doesn't crash; sync degrades gracefully |

### Suite C — Presenting (P0)
| ID | Case | Input | Expected |
|----|------|-------|----------|
| C-01 | Start + countdown | Start, countdown=3 | 3-2-1 then PRESENTING |
| C-02 | Voice-sync clean | fixture F-CLEAN | meets clean-read gates (§4) |
| C-03 | Hover pause | cursor over overlay | scroll halts; resume on leave |
| C-04 | Hotkey pause/resume | pause key | toggles; anchor preserved |
| C-05 | Manual scroll override | ↑/↓ + trackpad | mode=manual 4 s → re-anchor |
| C-06 | Speed live | faster x3 | creep + spring speed up; no jerk |
| C-07 | Size live | bigger x3 | relayout; yOffsets recomputed; sync still tracks |
| C-08 | Move/resize | drag | within constraints; persists |
| C-09 | Reach end | fixture to EOF | stops at last line; End affordance; auto-IDLE |
| C-10 | Stop teardown | Stop | overlay hidden; **AVAudioEngine + ASR stopped** (assert no running tap) |
| C-11 | Ad-lib + return | fixture F-ADLIB | freezes off-script; re-syncs ≤1.5s median |
| C-12 | Skip ahead | fixture F-SKIP | jumps forward to match; capped per tick |
| C-13 | Jump back / restart line | fixture F-REPEAT | small back ok; large back needs 2 confirms; no oscillation |
| C-14 | Numbers/acronyms | fixture F-TECH | "$29/API/99.9%" normalize-match; no stall |
| C-15 | Long session (ASR rotation) | 8-min fixture | recognizer rotates at ~50s; anchor preserved; no gap |

### Suite D — Ghost Mode (P0, manual + automated where possible)
See §7 matrix. Each cell = overlay invisible in capture, visible to presenter.

### Suite E — Window / Spaces (P0/P1)
| ID | Case | Expected |
|----|------|----------|
| E-01 | Over fullscreen Keynote | overlay stays on top |
| E-02 | All Spaces | present on every Space of its display |
| E-03 | No focus steal | typing in presenting app uninterrupted; overlay absent from ⌘-Tab and Mission Control window list |
| E-04 | Click-through | click empty overlay area reaches app behind |
| E-05 | Snap-notch vs free-float | toggle works; free-float position persists |
| E-06 | Resolution / scale change | overlay re-anchors correctly |

### Suite F — Settings (P1)
| ID | Case | Expected |
|----|------|----------|
| F-01 | Appearance live preview | font/size/color/opacity/spacing apply instantly + persist |
| F-02 | Hotkey rebind + conflict | rebind works; conflict (e.g. ⌘Q, or duplicate) blocked with message; reset works |
| F-03 | Mic sensitivity | VAD threshold + beam respond live |
| F-04 | Voice-sync off | manual-only scroll at fixed speed |
| F-05 | Recalibrate | re-runs passage, updates profile |
| F-06 | Target display | overlay moves to chosen display |

### Suite G — Licensing (P1)
| ID | Case | Input (see synthetic-data §4) | Expected |
|----|------|------|----------|
| G-01 | Valid activate | K-VALID | licensed; persists |
| G-02 | Invalid format | K-BADFMT | inline error, no network call |
| G-03 | Revoked key | K-REVOKED | "key revoked" |
| G-04 | Seat exhausted | K-SEATFULL | "seat limit reached" + manage link |
| G-05 | Offline grace | valid then offline | works within grace; warns near expiry |
| G-06 | Offline past grace | offline > grace | reverts to trial limits, non-destructive |
| G-07 | Deactivate/move | release seat | re-activate elsewhere succeeds |
| G-08 | Update flow | Sparkle feed | changelog → install → relaunch keeps state |
| G-09 | Relaunch restore | G6 of flows | last script + settings + window pos + license restored |

### Suite H — Permissions / errors (P0)
| ID | Case | Expected |
|----|------|----------|
| H-01 | Mic denied at use | blocking banner + deep link; recover post-grant w/o restart |
| H-02 | Speech denied | auto VAD-only + notice; upgrade when granted |
| H-03 | Mic busy | toast; auto-recover when freed |
| H-04 | Device change mid-session | re-tap to built-in; session continues; ASR re-warms (fixture F-DEVSWAP) |
| H-05 | No notch | top-center fallback; positioning works |
| H-06 | macOS 14.6 | hard-gate dialog; clean exit |
| H-07 | First-run no internet | onboarding completes (no net needed); license defer- able |

## 6. Voice-sync test matrix (the core)
Run every script class × every speech scenario through the harness (§3). Scenarios: **clean, paused, ad-lib, skip-ahead, repeat/restart, fast-talker, slow-talker, accented, noisy-background, mumbled/low-volume, two-speaker-interrupt, homophone-heavy, numbers/acronyms, code/jargon.** Each must meet the relevant §4 gate. Fixtures defined in `synthetic-data.md`; expand by generating variants (speed ×0.7/×1.4, noise +6/+12 dB SNR, 5% / 15% token-error injection).

## 7. Ghost Mode verification matrix (P0 — zero tolerance)
| Capture path | Ghost ON expect | Ghost OFF expect |
|--------------|-----------------|------------------|
| Zoom share | absent | present |
| Microsoft Teams share | absent | present |
| Google Meet share | absent | present |
| Loom recording | absent | present |
| OBS display capture | absent | present |
| QuickTime screen recording | absent | present |
| macOS ⌘⇧3 / ⌘⇧4 / ⌘⇧5 | absent | present |
| ScreenCaptureKit sample app | absent | present |
| Display 1 overlay / share Display 2 | absent | absent (different display) |
**Automation aid:** a small ScreenCaptureKit harness app captures a frame and asserts the overlay's known pixel signature is absent (ON) / present (OFF) — automates most rows; Zoom/Teams/Meet/Loom remain manual.

## 8. Performance tests
- PT-01 latency: timestamp injected ASR token → frame where scrollTarget reflects it; p95 < 300 ms.
- PT-02 fps: Instruments Core Animation during 5-min scroll; 0 frames dropped > 1/sec.
- PT-03 CPU/mem: sustained presentation; assert budgets (§4).
- PT-04 cold launch < 1.5 s to menu-bar ready.
- PT-05 large script (5k & 20k words) editor + tokenization responsiveness.
- PT-06 8-hour idle leak check (overlay hidden) — memory flat.

## 9. Accessibility tests
- AX-01 VoiceOver: all controls labeled; onboarding navigable.
- AX-02 keyboard-only: full operation (create→edit→present→stop) with no mouse.
- AX-03 contrast: overlay text meets WCAG AA over typical backgrounds; warn on low-contrast color choice.
- AX-04 Reduce Motion: scroll snaps instead of springs; fades disabled.
- AX-05 Dynamic Type in editor; Increase Contrast respected.

## 10. Compatibility / regression
- CT-01 full suite on each OS×arch cell (§2).
- CT-02 display matrix (notch/non-notch/external/dual) for positioning + Ghost.
- CT-03 upgrade test: install vN over vN-1 → scripts/settings/license migrate.
- CT-04 mic-device matrix (built-in/BT/USB) for VAD threshold + device-swap.

## 11. Exploratory / negative / edge
- Rapid Start/Stop spamming → no zombie audio engine, no crash.
- Toggle Ghost repeatedly mid-share → state stays correct.
- Resize to min/max bounds → no clipping/overlap of reading line.
- Script with only stopwords ("the the the") → no runaway jumps.
- 20k-word script run to end → memory stable, no scroll drift.
- Sleep/wake mid-session → session recovers or stops cleanly.
- Two displays hot-unplug the overlay's display → overlay migrates to remaining display.
- Locale set to non-English → English ASR still loads or clean message.

## 12. Bug severity & release gate
- **P0:** crash, Ghost leak, focus steal, data loss, permission deadlock, voice-sync gate miss on clean read. → block.
- **P1:** core flow degraded, recovery missing, perf budget miss. → block release.
- **P2:** polish, rare edge. → ship-with-note.
**Gate to ship v1:** §4 gates met on full fixture set · Ghost matrix 100% · Suites A,C,D,E,H 100% P0/P1 · a11y P0 pass · no open P0/P1.
