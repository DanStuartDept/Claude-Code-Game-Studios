# Fidchell — Game Concept Handover

---

## What Is Fidchell

Fidchell is an ancient Celtic board game, historically played across Ireland and Britain. It is an asymmetric strategy game for two players — one side attacks, the other defends. The game is a variant of the Roman *ludus latrunculorum* adapted into the Celtic world.

This project is a single-player mobile game built around Fidchell. The core experience is a campaign mode with a personal story arc, named opponents, feuds, and a final confrontation. Quick standalone matches against AI are also available, but the campaign is the heart of the game.

---

## The Board Game — Rules

### The Board
A 7×7 grid of tiles. Four corner tiles and the centre tile (the Throne) are special restricted squares.

### The Pieces
Two sides: **Light (Defenders)** and **Dark (Attackers)**.

- **Attackers** — 16 dark stone pieces. They move first. Their goal is to capture the King.
- **Defenders** — 8 light stone pieces plus the King. Their goal is to escort the King to safety.
- **The King** — 1 special piece belonging to the Defender side. Larger than other pieces. The entire game revolves around him.

### Starting Layout
The King starts on the Throne — the centre tile of the board. Defenders are arranged around him in a cross formation. Attackers surround the board from the outside edges.

### Movement
All pieces move orthogonally — up, down, left, right — any number of squares in a straight line, like a rook in chess. No diagonal movement. No jumping over other pieces.

### Restricted Tiles
The four corner tiles and the centre Throne may only be entered by the King. All other pieces must move around them.

### Capture
Capture is **custodial** — a piece is removed from the board when it is sandwiched between two enemy pieces on opposite sides along a row or column. Moving into a sandwich does not count — a piece is only captured when an enemy piece actively closes the trap.

- The corner tiles and the empty Throne act as hostile pieces for capture purposes — a single enemy piece flanked against a corner or the empty throne is captured.
- The King cannot be captured by a standard two-sided sandwich. He requires four pieces surrounding him on all four sides — or three sides plus a hostile tile (corner or empty Throne).

### Winning
- **Defenders win** — the King reaches any corner tile.
- **Attackers win** — the King is surrounded on all four sides and cannot move.
- **No legal moves** — if a player has no legal moves on their turn, they lose.

### Turn Order
Attackers (Dark) always move first.

---

## The Campaign — Story Premise

> *You are an elite Fidchell champion at the court of a great Irish lord. In the opening match, you are publicly defeated by a powerful rival. Disgraced before the court, you are banished westward. From the shores of Connacht, you must rebuild your reputation match by match, travelling east through the provinces, settling feuds, and defeating the rivals who stand between you and the final confrontation — a rematch against the man who took everything from you.*

The campaign is a story of **disgrace, exile, and return**. It is not a vast RPG. It is a personal journey told through named opponents, reactive dialogue, and a final boss who remembers you.

---

## Campaign Structure

Five chapters. Approximately 18 to 20 matches total. Some characters appear more than once through rematches and feuds.

---

### Chapter 0 — Prologue: The Disgrace
*Location: Tara, The High Court*

Two matches. The first is a tutorial. The second is the inciting incident — a formal match against Murchadh mac Fáelán, Champion of the High Court. The player **cannot win this match**. The outcome is locked by the story. The defeat is public. The banishment follows immediately.

This chapter establishes Murchadh as the final boss and plants the seeds of the feud.

---

### Chapter 1 — The West
*Location: Connacht, the wild shore*

Four matches. The player has arrived with nothing — no reputation, no allies. The opponents here are accessible and human. Nobody knows who the player is yet, which is both a humiliation and a relief. The chapter ends when the player has earned enough reputation to move inland.

---

### Chapter 2 — The Old Roads
*Location: Munster / Leinster border*

Four matches. Word has begun to travel. Some opponents have heard of the disgrace. The tone shifts — the player is now being tested rather than welcomed. A feud may carry over from Chapter 1 depending on how those matches went. The chapter boss is cold, formal, and hard to read.

---

### Chapter 3 — The Midlands
*Location: Heart of Ireland*

Five matches. This is the widest chapter. Feuds intensify. Rivals return. Recurring opponents now know the player's history and their dialogue reflects it. The chapter boss is a legendary figure who has lost nine times — to players who later became legends. Beating him is the turning point of the campaign.

---

### Chapter 4 — The Return
*Location: Leinster, approaching Tara*

Three matches plus the final boss. The court is within reach. Opponents here are gatekeepers — they are deciding whether the player deserves to walk back into the hall where they were disgraced. The chapter ends with the rematch against Murchadh. Winning it is the campaign's resolution.

---

## Reputation System

Reputation is a single score that accumulates across the campaign. It gates chapter access and influences how opponents speak to the player.

| Score | Unlocks |
|---|---|
| 0 | Chapter 1 |
| 15 | Chapter 2 |
| 35 | Chapter 3 |
| 60 | Chapter 4 |
| 80 | Final boss match |

Reputation is earned by winning matches. Bonus reputation is awarded for winning feuds, winning rematches, and winning quickly (in fewer moves). It cannot be lost — only stalled by losing streaks.

---

## The Feud System

Feuds are personal. Some opponents take a loss badly. Some take a win badly. Feuds are created when:

- The player loses to an opponent with a high tendency toward grudges
- A chapter boss is defeated and chooses to come back

When a feud is active:
- The opponent reappears later in the campaign at a harder difficulty
- Their pre-match dialogue is hostile and references the prior result
- Winning a feud match grants a significant reputation bonus
- Losing a feud match deepens the hostility — the opponent may escalate to **Nemesis** status

A **Nemesis** opponent is the hardest version of that character. Their dialogue is cold and final. Beating them clears the feud permanently.

### Rivalry States

| State | Description |
|---|---|
| Neutral | No significant history |
| Feud Pending | Loss flagged — feud will activate at next encounter |
| In Feud | Active hostility. Rematch injected into campaign |
| Feud Resolved | Player won. Respect earned. Tension cleared. |
| Nemesis | Three losses to same opponent. Maximum hostility. |

---

## The Dialogue System

Every opponent has their own voice. Dialogue appears before and after each match. It is short — one to three lines — and always grounded in the player's actual history with that character.

The system tracks:
- Whether this is the first meeting
- How many times they have played
- Who won each time
- Whether a feud is active
- Whether a rematch is happening
- Whether this is the final boss encounter

A narrator voice also appears between scenes, describing the journey in sparse, first-person prose. It references the player's progress, the landscape they are crossing, and the weight of what they are trying to do.

---

## The Opponents — All 13 Characters

---

### Murchadh mac Fáelán
**Champion of the High Court · Tara**

The opening villain and the final boss. The man who beat the player in front of everyone and said nothing about it — he didn't need to. Iron-grey beard. A golden torque at his throat. He plays with complete certainty and speaks with contempt so refined it barely sounds like contempt. He doesn't hold grudges because he doesn't need to. He simply wins.

*Difficulty: 7 — the hardest opponent in the game.*

---

### Séanán na Farraige
**Séanán of the Shore · Connacht coast**

A fisherman who plays Fidchell the way he reads the sea — by feel, with occasional flashes of accidental brilliance. Gap-toothed, weather-worn, completely unbothered. He laughs when he loses a piece. He laughs when he wins one. He buys the player a drink either way.

*The first real opponent. Gentle introduction.*

---

### Brigid na Scailpe
**Brigid of the Cliffs · Connacht**

Red hair in a tight braid. Sharp grey eyes. She owns the cliff-top territory and plays like she owns time itself — patient, defensive, waiting for the player to overextend. She says very little. When she does speak, she means it.

*Defensive style. Hard to beat quickly.*

---

### Tadhg an Ósta
**Tadhg of the Three Fires · Connacht**

The innkeeper. Fat hands, loud voice, a fire-scarred apron, always leaning forward over the board. He has not lost at his own table in six winters. He is not gracious in defeat. If the player beats him, he will remember. If the player loses, he will also remember. High feud tendency — the most likely character to trigger a grudge match.

*Aggressive, boastful. High feud risk. May reappear in Chapter 3.*

---

### Fiachra an Fhánaí
**Fiachra Without Roots · Connacht / border**

No fixed age. Dressed in road-worn layers. He carries a battered board under his arm and plays a different game every time — not because he is erratic, but because he is genuinely curious about what the board can do. He is the Chapter 1 boss. Losing to him sets up a rematch in Chapter 2.

*Tactical and unpredictable. Chapter 1 boss.*

---

### Orlaith na gCros
**Orlaith of the Crossroads · Munster**

Middle-aged, composed, ink-stained fingers. She has studied accounts of historic matches and reads the player like a text. Her style is immovable — she maximises the King's escape routes and waits for the player to run out of good moves. She is not unkind, but she is not warm either.

*Defensive. Cryptic tone. Chapter 2 opener.*

---

### Diarmait Óg
**Diarmait the Reckless · Leinster border**

Young. Handsome. A chip on his shoulder the size of a standing stone. He has heard about the player's disgrace and has already decided what it means. He plays fast and badly and sometimes brilliantly by accident. Losing to him stings because he makes it personal. He will come back for a rematch regardless of the result.

*Aggressive. Boastful. Guaranteed rematch.*

---

### Conchobar Críonna
**Conchobar the Cold · Midlands**

Old. Thin. Bony fingers. He has played this game longer than the player has been alive and he knows it. He speaks to the player the way a teacher speaks to a student who is behind — not cruel, but correct. He is the Chapter 2 boss and reappears in Chapter 3 harder and less forgiving.

*Tactical. Contemptuous. Chapter 2 boss.*

---

### Eithne an Chiúin
**Eithne the Wordless · Midlands**

She does not speak. She gestures at the board when it is your turn. She wins without comment and loses the same way. There is something terrifying about playing someone who registers nothing — no frustration, no satisfaction. Just the next move.

*Stoic. No dialogue. Plays with mechanical efficiency.*

---

### Ruairí an Bhaird
**Ruairí of the Thousand Songs · Midlands**

A bard with a colourful cloak and a small harp he never actually plays. He treats every match as material for a story — which means he sometimes makes the dramatic move rather than the correct one. He is not a great player but he is an entertaining opponent, and he will absolutely sing about this game at a hundred fires, whichever way it goes.

*Erratic. Cheerful. Replacement node if no feud is active.*

---

### Caoimhe an Léinn
**Caoimhe of the Written Laws · Leinster**

Precise posture. A wax tablet nearby. She approaches the game the way she approaches everything — as a problem to be formalised. She is not interested in the emotional stakes. She is interested in the solution. Her playing style is designed to disrupt the player's plans rather than execute her own. She scales in difficulty between her first and second appearance.

*Tactical. Appears in both Chapter 2 and Chapter 4.*

---

### Niall na Naoi gCailleadh
**Niall of the Nine Losses · Midlands**

He is named for having lost nine times — to players who were later regarded as legends. He considers a loss to be an honour given, not taken. He smiles when he is losing. He smiles more when he is winning. He is the Chapter 3 boss, and the hardest opponent the player will face before the final chapter. Beating him is the moment the player knows they are ready.

*The emotional peak of the middle campaign. Chapter 3 boss.*

---

### Saoirse na Cúirte
**Saoirse of the High Court · Leinster / Tara**

Court robes. Hands clasped. She has been told to decide whether the player deserves entry to the final hall. She has already formed a view. Her style exposes weaknesses — not to crush the player, but to confirm whether they are ready for what comes next. She is the final gatekeeper before Murchadh.

*Difficulty 6. Chapter 4 penultimate match.*

---

## Tone and Feel

The game is not a comedy. It is not epic fantasy. It is something closer to a quiet historical drama — personal, spare, and grounded. The writing should feel like it belongs to the landscape: unhurried, honest, and occasionally sharp.

The player is not a hero on a quest. They are a person trying to recover something they lost. The opponents are not villains. They are people with their own lives, most of whom happen to be very good at Fidchell.

The only exception is Murchadh — and even he is not a villain in the traditional sense. He is simply someone who beat the player fairly and whose existence represents everything the player has to overcome.

---

## What the Player Carries Through the Game

- **A reputation score** that reflects their progress and opens new chapters
- **A rivalry history** with every character they have faced — wins, losses, feuds
- **A set of feud flags** that may alter which matches appear in later chapters
- **The memory of the prologue loss** — it is referenced in dialogue throughout, and resolved only at the very end

The game ends when the player defeats Murchadh in the final rematch, or when they choose to walk away. There is no other ending.

---

*Concept document — March 2026*
