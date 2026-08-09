# DoF — Dice of Fate

[Русский](README.md) · **English**

A d20 roleplaying combat system for World of Warcraft. The addon turns freeform roleplay into structured combat: characters have stats, a role, health and energy, while every roll, effect and turn order is resolved and synchronised by the addon itself. The GM gets a control panel, players get an action bar and a readable combat log.

Built for **WoW 9.2.7** (`## Interface: 90207`).

---

## Installation

1. Download the repository and unpack it.
2. Put the folder into `World of Warcraft/_retail_/Interface/AddOns/`.
3. **The folder must be named exactly `DoF`** — the addon looks for its textures under that path.
4. Restart the game or run `/reload`.

```
Interface/AddOns/DoF/
├── DoF.toc
├── Core/  Data/  Combat/  Sync/  UI/  Locale/  Libs/  texture/
```

The Ace3 libraries ship with the addon — nothing else needs to be installed.

---

## Quick start

| | |
|---|---|
| Player | `/dof` — main window. Pick a role, spend your stat points. |
| GM | `/dof master` — control panel. Or Shift+click the minimap button. |
| All commands | `/dofhelp` |

The party or raid leader is automatically treated as the GM. Every ruling — levels, damage dealt to players, effects, turn order — originates from them; clients apply it locally and broadcast their own state back.

---

## How combat works

The core is a **d20 roll plus a stat against a threshold**. On a tie the outcome is decided by a 50/50 coin flip, and a natural 20 is a critical success.

Each offensive stat is opposed by its matching defence:

| Attack | vs | Defence |
|---|---|---|
| Strength | → | Fortitude |
| Dexterity | → | Reflex |
| Intelligence | → | Will |

The remaining stat is Spirit (healing, wound removal, charisma), while Fortitude, Reflex and Will double as both defences and skill checks.

Damage and healing come from tables keyed by level and role; a critical success adds a bonus of `min(range maximum, 5)`. Ordinary healing cannot exceed 50% of the target's maximum HP — a crit ignores that cap.

### Roles

| Role | What it gives |
|---|---|
| **Tank** | HP = base + Fortitude/2. Two successful defences in a row grant +1 to that defensive stat (up to +3). Two consecutive successful attacks on the same target shred its defence by 2 (down to −6). Damage redirection, taunt and AoE taunt. Below-average damage and healing. |
| **Fighter** | Increased damage. 15% chance to counterattack on a successful defence; a critical defence adds +3 to the counterattack. Below-average healing. |
| **Healer** | Improved healing and wound removal. A shield that absorbs all damage from one hit (2-turn cooldown) and an AoE shield for up to 4 targets. Below-average damage. |

### Resources

**Energy** (3–5 depending on level) pays for AoE actions, taunts and special actions. Skipping a turn returns 1 point.

**Wounds** come in two stages. The first applies −3 to every stat and restores HP to 25% of the new maximum. The second means the character is out of the fight: HP drops to zero and the GM decides what happens next.

**Healing fatigue** — every third successful heal adds a stack that raises the threshold of the next roll by 2 (up to 7 stacks). It is tracked per healer and survives relogging.

**Special action** — a freeform declaration by the player, rolled against a threshold of 14. It goes to the GM for approval, who sets its energy cost.

---

## Level system

The DoF level is **independent of the character's in-game level**. It is a separate **1–20** scale granted by the GM, either with `/dofsetlevel` or from the buttons on the Player tab of the GM panel. This works on servers with a fixed level cap.

The whole progression lives in a single `Progression` table in [`Core/Config.lua`](Core/Config.lua) — the index is the level, and the row describes everything that level grants:

| Lvl | Points | HP | Energy | Damage tier |
|:--:|:--:|:--:|:--:|:--:|
| 1 | 0 | 10 | 3 | 1 |
| 5 | 4 | 12 | 3 | 3 |
| 10 | 9 | 14 | 4 | 5 |
| 15 | 14 | 17 | 4 | 8 |
| 19 | 16 | 20 | 5 | 10 |
| **20** | **17** | 20 | 5 | 10 |

Stat points arrive on every level from 2 through 17; levels 18–19 raise HP and energy, and level 20 is a capstone granting the final, 17th point. A single stat cannot be raised above 8 when spending points (10 is the absolute ceiling including buffs).

To rebalance, edit `Progression` — the rest of the code reads it through getters and contains no hardcoded numbers.

---

## GM panel

Four tabs: **NPC**, **Player**, **Combat**, **Effects**.

- **NPC** — template library, HP and defence setup, attacks against a player with a damage range, threshold and debuff.
- **Player** — level (a menu of all steps plus ±1 buttons), role, stat reset, wounds, shields, HP changes, energy grants.
- **Combat** — start turn-based combat in queue or free mode, turn timer, instant defence, extra turns, excluding the GM from the queue.
- **Effects** — apply and remove buffs, debuffs, DoTs and stuns; purge and dispel.

Turn-based combat maintains an initiative queue, tracks who has already acted, and shows every participant a shared turn order window.

---

## Interface

- Compact player and target frames with HP, energy, active effects and a role icon
- An action bar with a tooltip for every action (left-click acts, right-click opens a choice)
- Turn order window
- Combat log with separate tabs for the player and the GM
- Values above NPC nameplates
- Minimap button

Frames can be dragged and scaled, and their positions persist. Settings live under `/dof settings` or a right-click on the minimap button.

---

## Commands

The full list is available in game via `/dofhelp`. The essentials:

```
/dof                       main window
/dof master                GM panel
/dof log                   combat log
/dof stats                 character sheet
/dof level                 level, points, HP, energy
```

**Player actions**

```
/dofattack str|dex|int     attack
/dofheal                   heal (healer)
/dofshield                 shield (healer)
/dofcheck str|dex|int|spi  stat check
/dofaoeattack str|dex|int  AoE attack
/dofaoeheal                AoE heal
/dofaoebuff <effect>       AoE buff
```

**GM: players**

```
/dofsetlevel <player> <1-20>      grant a level
/dofsetrole <player>              assign a role
/dofresetstats <player>           reset stats
/dofmodifyplayerhp <player> ±N    change HP
/dofgiveshield <player> <N>       grant a shield
/dofgiveenergy <player>           +1 energy
/dofaddwound  /dofremwound        wounds on the current target
```

**GM: NPCs and combat**

```
/dofsethp <N>                     set the target's HP
/dofdefense <fort> <refl> <will>  set NPC defences
/dofnpcattack %t 5-10 12 Fort stun 0 2
/dofbuff | /dofdebuff | /dofpurge | /dofdispel
/dofcombat start [sec]            start turn-based combat
/dofcombat end                    finish it
/dofversion                       compare versions across the group
```

---

## Synchronisation

Communication runs over the addon message channel with the `DoF_SYNC` prefix, via AceComm and AceSerializer. Commands fall into two groups: some are open to anyone in the party (own state, log entries, data requests), others are GM-only (damage to players, levels, roles, combat and effect control). The check happens on receipt, in [`Sync/Security.lua`](Sync/Security.lua).

Combat state and effects are stored in SavedVariables, so a `/reload` or a disconnect mid-fight loses nothing: the client requests recovery and catches up with the group. The GM broadcasts a heartbeat that lets everyone else tell whether they are still connected.

`/dofversion` compares addon versions across the group and highlights mismatches — a version mismatch is the usual cause of "I can't see the NPCs".

---

## Localisation

Russian and English. The language follows the game client, can be switched in the settings (`/dof settings`), and applies after a UI reload.

Strings live in [`Locale/ruRU/`](Locale/ruRU) and [`Locale/enUS/`](Locale/enUS), split by area: `Core`, `UI`, `Combat`, `Effects`, `Passives`, `NPC`, `Errors`. enUS always loads and acts as the fallback for untranslated keys. Keys prefixed with `xml.` automatically become `DoF_L_*` globals for use in `Frames.xml`.

To verify integrity after edits:

```powershell
powershell -ExecutionPolicy Bypass -File Tools/check_locale.ps1
```

The script compares key sets between languages, looks for references to missing keys and checks the XML globals.

---

## Layout

| Directory | Contents |
|---|---|
| `Core/` | configuration and balance, initialisation, utilities, event bus, XML aliases |
| `Data/` | stats, units, effects, passives, NPC library |
| `Combat/` | rolls and action resolution, AoE, defence, turn system |
| `Sync/` | transport, command permissions, message handlers |
| `UI/` | windows, frames, dialogs, action bar, log |
| `Locale/` | localisation engine and the ru/en strings |
| `Tools/` | development helper scripts |

The entry point is [`DoF.toc`](DoF.toc), and load order there matters: compatibility → libraries → locales → core → data → sync → combat → UI → initialisation.

---

## Development

Balance is concentrated in [`Core/Config.lua`](Core/Config.lua): level progression, damage and healing tables, action costs, cooldowns, wound penalties. Editing those tables requires no code changes.

Compatibility between the 9.x and 10.0+ APIs is isolated in [`Core/Compat.lua`](Core/Compat.lua), which swaps `SetResizeBounds` and `SetMinResize` depending on the client version.

Fonts are chosen at runtime with Cyrillic-capable ones first: any explicit `SetFont` disables the client's own glyph fallback, so on non-Russian builds `FRIZQT__.TTF` would render Cyrillic as boxes.

---

## Author

**Skyrogx**

Version 1.0
