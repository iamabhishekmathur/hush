# Hush — User Flows

Every flow has an ID (A–H), preconditions, numbered steps, postcondition, and notes. Each flow ID maps 1:1 to a test suite in `test-plan.md`. UX principle throughout: **native macOS HIG, minimal chrome that fades during presentation, keyboard-first, never steal focus.**

## Session state machine (the prompter)
```
        ┌─────────┐  select script + Start   ┌───────────┐
        │  IDLE   │ ───────────────────────► │ COUNTDOWN │
        └─────────┘                          └─────┬─────┘
             ▲                                     │ countdown == 0
             │ Stop/close                          ▼
        ┌────┴─────┐  hover / hotkey pause   ┌───────────┐
        │  PAUSED  │ ◄────────────────────── │ PRESENTING│
        └────┬─────┘  resume                 └─────┬─────┘
             │                                     │ reach end
             └───────────────► [END] ◄─────────────┘
PRESENTING substates (scroll mode): voiceSynced ⇄ vadCreep ⇄ frozen ⇄ manual
GHOST overlay (on/off) is orthogonal to all states.
```

---

## A. First-run / onboarding
**Pre:** fresh install, no permissions, no scripts.
1. Launch → menu bar icon appears, **Welcome** sheet opens (what Hush does, 3 bullets, "Get started").
2. **Microphone permission** step → request → granted (happy) **or** denied → show recovery card with "Open System Settings."
3. **Speech recognition permission** step → granted **or** denied → notice "Voice-sync will use volume-only mode; you can enable later."
4. **Calibration**: prompt user to read a fixed passage aloud; live meter + beam; on finish show "Voice profile saved."
5. **Position preview**: overlay appears under the notch with sample text; "Looks good" / "Move it" (drag).
6. **First script**: "Paste a script", "Import file", or "Use a sample." 
7. **Done** → land in IDLE with the script loaded; tooltip points at menu bar + global start hotkey.
**Post:** permissions resolved, calibration stored, ≥1 script exists, overlay positioned.
**Notes:** every step skippable; resumable if quit mid-onboarding.

## B. Script management
**Pre:** app onboarded.
- **B1 Create:** menu/editor → "New Script" → titled "Untitled" → editor focus.
- **B2 Edit:** type/format (size, paragraph, section break, pause marker); autosave; word count + est. read time update live.
- **B3 Paste long:** ⌘V a 5k-word block → renders without lag; tokenization cache rebuilt in background.
- **B4 Duplicate:** right-click → Duplicate → "<title> copy".
- **B5 Delete:** select → Delete → **confirm** sheet → removed; undo toast (10 s).
- **B6 Rename:** double-click title or field → edit.
- **B7 Reorder/organize:** drag rows in library sidebar; order persists.
- **B8 Search:** filter field matches title + body.
- **B9 Import:** drag `.txt/.md/.rtf` onto window or library; markdown headings → sections.
**Post:** library reflects changes; all persisted across relaunch.

## C. Presenting (core)
**Pre:** ≥1 script, mic granted.
- **C1 Start:** select script → Start (button/global hotkey) → COUNTDOWN (configurable 0–10 s) → PRESENTING.
- **C2 Voice-sync scroll:** speak → text advances tracking position; beam reflects volume; reading line holds the current line.
- **C3 Pause:** hover cursor over overlay **or** pause hotkey → scrolling halts, subtle "paused" affordance.
- **C4 Resume:** move cursor away / resume hotkey → continues from same anchor.
- **C5 Manual override:** two-finger scroll or ↑/↓ keys → mode=manual 4 s → re-anchors to nearest distinctive word.
- **C6 Speed live:** faster/slower hotkeys adjust creep speed + spring responsiveness.
- **C7 Text size live:** bigger/smaller hotkeys; layout + token yOffsets recomputed.
- **C8 Reposition/resize:** drag background to move; drag edge to resize (within constraints).
- **C9 Countdown:** numeric overlay 3-2-1 before scrolling begins.
- **C10 Reach end:** scroll stops at last line; "End" affordance; auto-return to IDLE after N s or on Stop.
- **C11 Stop/close:** Stop hotkey/menu → overlay hides → IDLE; audio + ASR torn down.
- **C12 Ad-lib then return:** go off-script (unscripted words) → prompter freezes/creeps gently → resumes sync when script words spoken again (re-sync ≤ 1.5 s median).
- **C13 Skip / jump back:** read a line out of order → prompter jumps to matched location (forward cap per tick; backward needs confirmation).
**Post:** session ends cleanly; no audio engine left running; last position remembered per script (optional).

## D. Ghost Mode / screen share
**Pre:** presenting or idle with overlay visible.
- **D1** Enable Ghost → share screen in **Zoom** → presenter sees overlay, viewers/recording do **not**.
- **D2** Repeat verification for **Teams, Google Meet, Loom, OBS, QuickTime screen recording**.
- **D3** Screenshot (⌘⇧3 full, ⌘⇧4 region, ⌘⇧5 record) → overlay absent from captured image/video.
- **D4** Toggle Ghost **off** → overlay now appears in captures (for users who want it visible, e.g. classic teleprompter on a second machine).
- **D5** Multi-monitor: overlay on display 1, share display 2 → overlay absent regardless; share display 1 with Ghost on → still absent.
**Post:** capture output matches Ghost state in every tool.

## E. Window / Spaces behavior
- **E1** Over fullscreen app (Keynote present, fullscreen Safari) → overlay stays visible on top.
- **E2** Across Spaces / Mission Control → overlay present on every Space of its display.
- **E3** Focus: clicking/typing in the presenting app never loses focus to the overlay; overlay never appears in ⌘-Tab.
- **E4** Hover region pauses; clicking through empty overlay area reaches the app behind (click-through).
- **E5** Snap-to-notch vs free-float toggle; in free-float, position persists.

## F. Settings & customization
- **F1** Appearance: change font/size/weight/color/opacity/line-spacing/reading-line position → live preview.
- **F2** Hotkeys: rebind any global shortcut; **conflict detection** vs system + internal; reset to defaults.
- **F3** Mic sensitivity slider → VAD threshold shifts; beam updates live.
- **F4** Voice-sync on/off → manual-only mode (pure scroll at fixed/creep speed).
- **F5** Recalibrate voice → re-run calibration passage.
- **F6** Target display selection (multi-monitor).
**Post:** all settings persist across relaunch.

## G. Licensing / lifecycle
- **G1** Unlicensed/trial state → defined limit (e.g. watermark or time-limited) + "Buy" link.
- **G2** Enter license key → Activate → success (licensed) / invalid-format / revoked / seat-exhausted messaging.
- **G3** Offline activation → cached entitlement honored within grace window.
- **G4** Deactivate / move Mac → release seat; re-activate elsewhere.
- **G5** Update available → changelog → install (Sparkle) → relaunch.
- **G6** Quit & relaunch → restores last script, settings, license, window position.

## H. Permissions & error states
- **H1** Mic denied at use-time → blocking banner + System Settings deep link → recover without restart after grant.
- **H2** Speech denied → automatic VAD-only mode + dismissible notice; upgrade path when later granted.
- **H3** Mic in use by another app → toast; recover when freed.
- **H4** No notch (Intel/external) → top-center fallback with handle; positioning still works.
- **H5** macOS < 14.7 → hard gate dialog at launch.
- **H6** Audio device unplugged mid-session (AirPods removed) → reconfigure to built-in mic, session continues, ASR re-warms.

---

## UX acceptance bar (applies to all flows)
- Every destructive action confirmable + undoable where feasible.
- Overlay chrome hidden during PRESENTING; appears only on hover, fades in/out (respect Reduce Motion).
- Full keyboard operability; VoiceOver labels on all controls; Dynamic Type in editor; sufficient text contrast on overlay.
- No spinner > 1 s without a label; no permission prompt without preceding context screen.
- Cold launch → menu bar ready < 1.5 s.
