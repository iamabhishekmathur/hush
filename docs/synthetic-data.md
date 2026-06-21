# Hush — Synthetic Test Data

Concrete fixtures the harness (`test-plan.md` §3) replays. Each script is tokenized with **0-based indices** so ASR streams can assert an exact `expectedTokenIndex`. ASR streams emulate `SFSpeechRecognizer` partials, including realistic misrecognitions. `t_ms` is the virtual-clock timestamp.

---

## 1. Sample scripts (the text a user provides)

### S1 — "Sales pitch" (clean, conversational)
```
Hi there. I'm going to show you how Hush keeps you looking at the
camera while you present. Watch the script scroll as I speak. When I
pause, it waits for me. Let's dive in.
```
Tokenized (content words shown with index; stopwords kept for layout, marked ·):
```
0 hi   1 there   2 ·i'm  3 going  4 ·to  5 show  6 ·you  7 ·how  8 hush
9 keeps 10 ·you 11 looking 12 ·at 13 ·the 14 camera 15 ·while 16 ·you
17 present 18 watch 19 ·the 20 script 21 scroll 22 ·as 23 ·i 24 speak
25 ·when 26 ·i 27 pause 28 ·it 29 waits 30 ·for 31 ·me 32 ·let's 33 dive 34 ·in
```
Word count 35 · est. read ~13 s @ 160 WPM.

### S2 — "Founder / VC intro"
```
We started Hush because every founder I know freezes on camera. You
forget your numbers, you lose your story. Hush fixes that. It puts
your script where your eyes already are, and it moves when you move.
```

### S3 — "Technical demo" (numbers, acronyms, currency — stresses normalization)
```
Our API handles 99.9% uptime. Pricing starts at $29, one time, no
subscription. The SDK ships for iOS and Android today, with a CLI for
power users.
```
Index excerpt (normalization pairs the engine must handle):
```
0 our  1 API(→"a p i")  2 handles  3 99.9%(→"ninety nine point nine percent")
4 uptime  5 pricing  6 starts  7 ·at  8 $29(→"twenty nine dollars")  9 ·one
10 time  11 ·no  12 subscription  13 ·the  14 SDK(→"s d k")  15 ships
16 ·for  17 iOS(→"i o s")  18 ·and  19 Android  20 today  21 ·with  22 ·a
23 CLI(→"c l i")  24 ·for  25 power  26 users
```

### S4 — "Keynote opener" (long, ~250 words) — generate full text in fixtures; used for ASR-rotation + drift tests.
### S5 — "Webinar w/ list" — contains a bulleted list + a section break (tests section markers).
### S6 — "Social reel" (~40 words, fast cadence) — tests fast-talker creep + short re-sync.

---

## 2. Simulated ASR streams + expected trajectory

Format per line: `{t_ms, partial:[recognized tokens so far / tail], conf, expectedTokenIndex}`. The engine should drive `anchor` to ~`expectedTokenIndex`.

### F-CLEAN — S1 read cleanly (acceptance: ≥92% frames within ±3)
```
{  300, ["hi"],                                  0.94,  0}
{  900, ["hi","there"],                          0.93,  1}
{ 1700,["there","i'm","going","to","show"],      0.90,  5}
{ 2600,["show","you","how","hush"],             0.88,  8}
{ 3400,["how","hush","keeps","you","looking"],  0.91, 11}
{ 4200,["keeps","you","looking","at","the","camera"],0.89,14}
{ 5200,["the","camera","while","you","present"], 0.90, 17}
{ 6100,["watch","the","script"],                 0.92, 20}
{ 6900,["the","script","scroll","as","i","speak"],0.91,24}
{ 8000,["when","i","pause"],                     0.93, 27}
{ 8800,["pause","it","waits","for","me"],        0.90, 31}
{ 9700,["let's","dive","in"],                    0.92, 34}
```
Assert: monotonic non-decreasing anchor; final anchor ≥ 33; no jump > MAX_JUMP.

### F-ADLIB — S1 with off-script aside between idx 17 and 18
Speaker says after "…while you present" → *"and honestly this changed my whole workflow"* (not in script) → then resumes "watch the script scroll".
```
{ 5200,["the","camera","while","you","present"],         0.90, 17}
{ 6000,["and","honestly","this","changed","my","whole"], 0.84, 17}   ← no script match → HOLD at 17
{ 6800,["my","whole","workflow"],                        0.83, 17}   ← still frozen/creep
{ 7600,["watch","the","script","scroll"],                0.91, 21}   ← re-sync
```
Assert: anchor stays 17 (±1) during aside; re-sync to ~21 within ≤1.5 s of "watch".

### F-SKIP — S1 jump forward (skips idx 18–24, reads "when I pause" early)
```
{ 3400,["how","hush","keeps","you","looking"], 0.91, 11}
{ 4000,["when","i","pause","it","waits"],        0.88, 29}   ← distinctive "pause/waits" far ahead
```
Assert: forward jump accepted but **capped per tick** (advances toward 29 over ≤3 ticks); no overshoot past 31; no false jump on the common words.

### F-REPEAT — S2 restart a line (says "you forget your numbers" twice)
Assert: small backward correction allowed once; second confirming match required before re-anchoring back; no oscillation between the two positions.

### F-TECH — S3 with normalization + a misrecognition
```
{  400,["our"],                                          0.92, 0}
{ 1100,["our","a","p","i","handles"],                    0.86, 2}   ← "API"→"a p i" must match idx1
{ 2200,["handles","ninety","nine","point","nine","percent"],0.80,3}← idx3 "99.9%" normalized
{ 3000,["percent","uptime"],                             0.88, 4}
{ 3900,["pricing","starts","at","twenty","nine","dollars"],0.83, 8}← "$29" normalized
{ 4800,["one","time","no","subscription"],               0.87, 12}
{ 5700,["the","s","d","k","ships"],                      0.84, 15}  ← "SDK"
{ 6600,["for","i","o","s","and","android"],              0.82, 19}  ← "iOS"
{ 7500,["today","with","a","c","l","i"],                 0.80, 23}  ← "CLI"
{ 8300,["for","power","users"],                          0.86, 26}
```
Assert: every normalized token matches its script index; no stall on numbers/acronyms; ≥85% frames within ±3.

### F-NOISY — S1 with 10% token-error injection + low confidence (≤0.6)
Inject substitutions (e.g. "hush"→"movie", "scroll"→"scrawl") and drop two tokens. Assert: phonetic fallback recovers ≥70% frames within ±3; no runaway on bad tokens.

### F-DEVSWAP — S1 read; at t=5000 the `AudioSource` emits a device-change event (AirPods removed)
Assert: pipeline reconfigures, ASR re-warms, anchor preserved (no reset to 0), session continues to end.

### F-SILENCE — S1 read, then 5 s of silence after idx 17, then resume
Assert: within 600 ms of silence the scroll velocity → 0 (no creep runaway); resumes on speech.

### VAD label tracks (for VAD-only mode tests)
`vad-stream.jsonl` per fixture: `{t_ms, rms_db}` — calibrate `vadThreshold` from P-CAL; assert creep advances only while `isSpeaking`, halts ≤600 ms after silence.

### P-CAL — calibration passage (read during onboarding)
```
The quick brown fox jumps over the lazy dog. Pack my box with five
dozen liquor jugs. How razorback jumping frogs can level six piqued gymnasts.
```
Expected outputs within sane bounds: noiseFloor −55…−40 dBFS, speaking −25…−10 dBFS, WPM 110–190.

---

## 3. Edge-case input catalog (scripts)
| Fixture | Content | Expected handling |
|---------|---------|-------------------|
| S-EMPTY | "" | Start disabled / "nothing to present" |
| S-1WORD | "Hello." | runs, ends immediately at idx 0, no crash |
| S-LONG | 5,000 words (lorem + dialogue) | paste/import < 100 ms UI block; async tokenize |
| S-HUGE | 20,000 words | editor + run stable; memory < 250 MB |
| S-UNICODE | emoji 🎤, accents café, RTL "مرحبا", combining marks | renders; tokenizer no crash; sync degrades, doesn't error |
| S-STOPWORDS | "the the the and and the" | no runaway jumps (no distinctive tokens) |
| S-CODE | code block with `func()`, symbols | tokenizer skips symbol noise; readable layout |
| S-NUMBERS | "Call 1-800-555-0199 by 5/6/2026 for 50% off" | dates/phones/percent normalize or pass through, no stall |
| S-ALLCAPS | "WELCOME TO THE SHOW" | case-insensitive match works |
| S-MD | markdown with `# H1`, `## H2`, `- bullets` | headings → sections; bullets preserved |
| S-RTF | rich text w/ bold/size | imports, formatting mapped or flattened cleanly |
| S-BINARY | binary file renamed `.txt` | rejected with message, no crash |

---

## 4. License key fixtures
| ID | Key (format `HUSH-XXXX-XXXX-XXXX`) | Verify response | Expected UI |
|----|-------------------------------------|-----------------|-------------|
| K-VALID | HUSH-7G4K-9PQ2-XR1A | 200 valid, seat free | Licensed; persists to Keychain |
| K-BADFMT | hush 123 | (no call) | inline "invalid format", no network |
| K-REVOKED | HUSH-DEAD-BEEF-0000 | 200 revoked | "this key was revoked" |
| K-SEATFULL | HUSH-FULL-SEAT-9999 | 200 seat_exhausted | "seat limit reached" + manage link |
| K-UNKNOWN | HUSH-ZZZZ-ZZZZ-ZZZZ | 404 not_found | "key not found" |
| K-OFFLINE | K-VALID then network off | (cached entitlement) | works within grace; warns near expiry |
| K-EXPIRED-GRACE | K-VALID, offline > 30 d | (grace exceeded) | reverts to trial, non-destructive |

Verify endpoint contract (tiny backend): `POST /verify {key, machineId} → {status: valid|revoked|seat_exhausted|not_found, entitlement?, seatsUsed, seatsMax, signedToken}`. App stores `signedToken` (signature-checked) in Keychain; re-verify cadence 14 d, offline grace 30 d.

---

## 5. How to expand the fixture set (for "exhaustive")
Generate variants programmatically from the base streams:
- **Speed:** scale all `t_ms` ×0.7 (fast) and ×1.4 (slow).
- **Accent/error:** inject 5% and 15% token substitution using a phonetic-confusion table (b↔p, m↔n, "hush"↔"movie").
- **Noise:** lower confidences by 0.15 / 0.30 and drop 1-in-10 tokens (simulates low SNR).
- **Two-speaker:** interleave a second token stream (interrupting voice) → engine should ignore non-matching tail, hold anchor.
Each generated fixture is run through the harness and checked against the §4 gate for its class.
