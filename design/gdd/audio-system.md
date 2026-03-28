# Audio System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Atmosphere — the Celtic tone that makes each match and journey feel real

## Overview

The Audio System manages all sound in Fidchell: music, sound effects, and ambient audio. It listens to signals from the Board Rules Engine (piece moved, piece captured, match ended, King threatened) and Scene Management (scene changed) to trigger appropriate audio without being called directly by gameplay systems. Music is scene-based — each screen and chapter has a distinct track or mood. Sound effects are event-driven — every board action has a corresponding sound. Ambient audio provides environmental texture per chapter location (coastal wind, forest, rain, court hall murmur). The system runs on Godot's AudioServer with three buses (Music, SFX, Ambient) independently mixable. There is no voice acting — the game is text-only. Audio is the atmosphere layer: it tells the player where they are, what just happened, and how it should feel.

## Player Fantasy

The player should hear Ireland. Not a fantasy orchestra — something closer to a fire in a stone room, a harp string plucked once, rain on a thatched roof. The music should be sparse enough that silence has weight. A piece moving should sound like stone sliding on wood. A capture should have a satisfying, final quality — something taken, not just removed. The King's escape should feel like a held breath released. Between matches, the ambient sound should change with the landscape: Connacht's wind, Munster's rain, the quiet of the midlands, the murmur of Tara's court. The audio should never compete with the player's concentration during a match — it should support it. The game should sound the way old wood smells.

## Detailed Design

### Core Rules

#### 1. Audio Buses

Three independent buses on Godot's AudioServer:

| Bus | Purpose | Default Volume | Player Control |
|-----|---------|---------------|----------------|
| **Music** | Scene music, chapter themes | 70% | Settings slider |
| **SFX** | Board events, UI feedback | 100% | Settings slider |
| **Ambient** | Environmental loops per chapter | 50% | Settings slider |
| **Master** | Parent bus — controls overall volume | 100% | Settings slider (or device volume) |

Each bus can be independently muted or adjusted. Settings are persisted via Save System.

#### 2. Music — Scene and Chapter Mapping

| Scene | Music | Behavior |
|-------|-------|----------|
| **Splash / Main Menu** | Main theme — solo harp or low uilleann pipes, Celtic melody | Loops. Fades out on scene change. |
| **Campaign Map** | Chapter-specific ambient music (see below) | Crossfades when changing chapters. |
| **Match (Chapter 1)** | Light tension — sparse strings, soft bodhrán pulse | Loops during match. Intensity does not change dynamically. |
| **Match (Chapter 2)** | Moderate tension — added low drone, darker tone | Loops during match. |
| **Match (Chapter 3)** | Higher tension — fuller instrumentation, rhythmic drive | Loops during match. |
| **Match (Chapter 4)** | Peak tension — full Celtic instrumentation, urgent but controlled | Loops during match. |
| **Match (Final Boss)** | Unique Murchadh theme — the main theme inverted or minor key, gravitas | Loops. Distinct from all other match music. |
| **Tutorial** | Gentle, instructional — lighter version of Chapter 1 match music | Loops. |
| **Dialogue overlay** | Music continues from underlying scene (ducked slightly) | Music volume reduces ~20% while dialogue text is displayed. |
| **Match Result** | Victory: brief triumphant sting (harp flourish). Defeat: brief somber sting (low drone fade). | One-shot, not looped. Underlying match music fades. |
| **Credits** | Full arrangement of main theme | Plays once. |
| **Settings / Pause** | Music continues from underlying scene | No change. |

#### 3. Chapter Ambient Audio

Each chapter location has a distinct ambient loop:

| Chapter | Location | Ambient Sound |
|---------|----------|---------------|
| 0 (Prologue) | Tara, The High Court | Indoor murmur, fire crackle, distant voices |
| 1 | Connacht coast | Coastal wind, distant waves, seabirds |
| 2 | Munster / Leinster border | Rain on leaves, forest atmosphere, occasional thunder |
| 3 | Heart of Ireland | Open field wind, crickets, evening quiet |
| 4 | Leinster / Tara | Court ambience returning — stone halls, muffled voices, torch crackle |

Ambient audio plays on the campaign map and during matches set in that chapter. It crossfades (1.0s) when the chapter changes.

#### 4. Sound Effects — Board Events

The Audio System listens to Board Rules Engine signals and plays corresponding SFX:

| Signal | SFX | Description |
|--------|-----|-------------|
| `piece_moved` | Stone slide | Short scrape — stone piece sliding on wooden board |
| `piece_captured` | Stone impact + removal | Heavier thud — piece struck and removed |
| `piece_captured` (multi) | Sequential impacts with 0.1s gap | Each capture plays individually (matches Board UI's sequential animation) |
| `king_threatened` | Low warning tone | Subtle tension — a held note or quiet drum tap |
| `match_ended` (victory) | Victory sting | Harp flourish, brief and satisfying |
| `match_ended` (defeat) | Defeat sting | Low drone fade, somber but not punishing |
| `turn_changed` | Soft tick | Barely audible — signals turn change without being intrusive |

#### 5. Sound Effects — UI Events

| Event | SFX | Description |
|-------|-----|-------------|
| Piece selected (tap) | Soft click | Light stone tap — piece picked up |
| Piece deselected | Softer click | Quieter — piece set back down |
| Dialogue text appears | None | Text is silent — the rhythm is the player's reading pace |
| Dialogue tap to advance | Soft page turn or tap | Very subtle — acknowledges input |
| Button tap (menus) | UI click | Standard, unobtrusive |
| Match start (board appears) | Board set — pieces placed | Brief ambient rattle of stones being arranged |

#### 6. Music Transitions

| Transition | Method | Duration |
|-----------|--------|----------|
| Scene change (base scene) | Crossfade — old track fades out, new fades in | 1.0s (matches Scene Management's 0.4s visual fade, but music extends slightly) |
| Overlay push (dialogue, pause) | Duck — music volume drops 20% | 0.3s fade |
| Overlay pop | Unduck — music volume returns | 0.3s fade |
| Match end → result | Match music fades, victory/defeat sting plays | 0.5s fade out, sting plays immediately |
| Chapter change on campaign map | Crossfade music + crossfade ambient | 1.0s |

#### 7. Mobile Considerations

- **Battery:** Audio processing is lightweight. Use compressed formats (OGG Vorbis for music/ambient, WAV for short SFX).
- **Speaker quality:** Mix for phone speakers (limited bass). Test on device speakers, not just headphones.
- **Silent mode / mute switch:** Respect device silent mode. If the device is muted, all audio is muted. No override.
- **Headphone detection:** No special behavior — same mix for speakers and headphones.
- **Background audio:** When the app backgrounds, all audio stops. On resume, music and ambient restart from an appropriate point (not from the beginning — resume position or loop restart).

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Idle** | App launched, no scene loaded yet | Audio buses initialized. Master volume applied. | First scene loads |
| **Playing** | Scene active | Music track playing (looped), ambient loop playing (if applicable), SFX responding to signals | Scene changes or app backgrounds |
| **Ducked** | Overlay pushed (dialogue, pause) | Music volume reduced 20%. SFX still active. Ambient unchanged. | Overlay popped |
| **Transitioning** | Scene changing | Crossfading music and/or ambient. SFX temporarily suppressed during fade. | Crossfade completes |
| **Suspended** | App backgrounded | All audio stopped. Playback positions noted for resume. | App resumed |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board Rules Engine** | Audio listens to signals | Subscribes to: `piece_moved`, `piece_captured`, `turn_changed`, `match_ended`, `king_threatened`. Plays corresponding SFX. No direct calls — signal-driven only. |
| **Scene Management** | Audio listens to scene changes | Subscribes to: `scene_changed(scene_name)`, `overlay_pushed`, `overlay_popped`. Triggers music crossfade, ducking, and ambient changes. |
| **Campaign System** | Audio reads chapter context | On match start, Audio reads the current chapter from Campaign to select the correct match music and ambient track. |
| **Save System** | Save persists volume settings | Volume levels for Music, SFX, Ambient buses are stored in the save file's settings block. Restored on load. |
| **Board UI** | No direct interaction | Board UI and Audio both listen to Board Rules Engine signals independently. They do not coordinate — SFX timing naturally aligns with animation timing because both respond to the same signal. |

## Formulas

No mathematical formulas. Audio playback is event-driven (signal → SFX) and state-driven (scene → music track). Volume is a linear slider (0.0–1.0) applied to Godot AudioServer bus volume.

The only calculation is ducking:

```
ducked_volume = current_music_volume * (1.0 - duck_amount)
```

| Variable | Type | Value | Source | Description |
|----------|------|-------|--------|-------------|
| `current_music_volume` | float | 0.0–1.0 | Settings | Player's music volume setting |
| `duck_amount` | float | 0.2 | Config | How much to reduce music during overlays |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Player mutes all audio in settings | All buses at 0. SFX signals still fire (no errors) but produce no sound. | Muting should be clean — no errors from silent playback |
| Multiple captures in rapid succession | Each capture SFX plays sequentially with 0.1s gap (matching Board UI animation timing) | Audio and visual stay synchronized |
| Player opens pause menu during match | Music ducks. Ambient continues. SFX from Board Rules Engine are suppressed (match is paused). | Pause should feel like a pause, not silence |
| App backgrounded during music crossfade | Crossfade stops. On resume, new track starts from the beginning at full volume. | Don't try to resume mid-crossfade — just start clean |
| Scene changes rapidly (player taps through dialogue quickly) | Each scene change triggers a new crossfade. If a crossfade is interrupted by another, the new one takes over from the current volume level. | Smooth transitions even under rapid input |
| Match victory SFX plays but match music hasn't finished fading | Victory sting plays over the fading music. Sting is mixed louder — it cuts through. | The sting is the emotional punctuation — it should be heard |
| Device on silent/vibrate mode | All game audio is muted. No override. | Respect platform conventions |
| No audio file found for an event | Log warning. Play nothing. Do not crash. | Missing audio should be silent, not broken |
| Player adjusts volume slider while music is playing | Volume changes in real-time with no interruption or restart. | Standard audio behavior |
| Tutorial match — same SFX as normal? | Yes. Board events use the same SFX regardless of match type. Tutorial music is a lighter variant. | Consistent audio language from the first match |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Board Rules Engine** | This depends on | Soft — Audio listens to board event signals for SFX | `piece_moved`, `piece_captured`, `turn_changed`, `match_ended`, `king_threatened` signals |
| **Scene Management** | This depends on | Hard — Audio needs scene change signals for music/ambient transitions | `scene_changed`, `overlay_pushed`, `overlay_popped` signals |
| **Campaign System** | This depends on | Soft — Audio reads current chapter for track selection | Current chapter context |
| **Save System** | Save persists audio settings | Soft — Volume settings in save file | Settings block |

**This system depends on:** Scene Management (hard), Board Rules Engine (soft).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `default_music_volume` | 0.7 | 0.0–1.0 | Louder music — more atmospheric, may compete with SFX | Quieter music — more focus on SFX and ambient |
| `default_sfx_volume` | 1.0 | 0.0–1.0 | Louder effects — more tactile feedback | Quieter effects — less feedback |
| `default_ambient_volume` | 0.5 | 0.0–1.0 | Louder environment — more immersive | Quieter environment — less distraction |
| `music_crossfade_duration` | 1.0s | 0.3–2.0s | Slower transitions — smoother but may overlap awkwardly | Faster transitions — snappier but more abrupt |
| `duck_amount` | 0.2 | 0.0–0.5 | More ducking during dialogue — text feels more prominent | Less ducking — music stays present during dialogue |
| `sfx_capture_gap` | 0.1s | 0.05–0.3s | More space between sequential captures | Faster capture sequence |
| `victory_sting_volume` | 1.0 | 0.7–1.0 | Louder victory moment | Subtler victory |
| `defeat_sting_volume` | 0.8 | 0.5–1.0 | Louder defeat — more punishing feel | Softer defeat — less discouraging |

## Acceptance Criteria

- [ ] Three audio buses (Music, SFX, Ambient) are independently controllable via Settings
- [ ] Volume settings persist through Save System and restore on load
- [ ] Each scene has a corresponding music track that plays on entry
- [ ] Music crossfades smoothly on scene transitions (1.0s)
- [ ] Chapter-specific ambient audio plays on campaign map and during matches
- [ ] Ambient crossfades on chapter change
- [ ] `piece_moved` signal triggers stone slide SFX
- [ ] `piece_captured` signal triggers capture SFX (sequential for multi-captures)
- [ ] `king_threatened` signal triggers warning tone
- [ ] `match_ended` triggers appropriate victory or defeat sting
- [ ] Music ducks during dialogue overlays and restores on pop
- [ ] Final boss match has a unique music track
- [ ] All audio stops when app backgrounds and resumes cleanly
- [ ] Device silent mode is respected — no audio override
- [ ] Missing audio files produce silence and a log warning, not a crash
- [ ] Audio runs without noticeable battery impact on mobile
- [ ] Match SFX align with Board UI animations (both driven by same signals)
- [ ] Music format: OGG Vorbis. SFX format: WAV. All loaded from `assets/audio/`
- [ ] No hardcoded audio paths — all mappings in external config

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should match music dynamically intensify during the match (e.g., when few pieces remain or King is threatened), or stay at a constant level? Dynamic is more cinematic but adds complexity. | Audio Director | Prototyping | — |
| Should there be distinct SFX for capturing vs. being captured, or the same sound for both? | Sound Designer | Audio production | — |
| Who composes the music? Original Celtic compositions, licensed library music, or AI-generated? | Producer | Pre-production budget | — |
| Should there be a "no music" ambient-only mode for players who find music distracting during strategy? | UX Designer | Playtesting | — |
| Should the narrator dialogue have a subtle audio cue (e.g., a soft chime) when it appears, even though there's no voice acting? | Audio Director | Playtesting | — |
