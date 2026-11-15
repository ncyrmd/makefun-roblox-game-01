# Neon Harvest — make.fun roblox-game-01

A 2D arcade catcher for Roblox: catch the falling neon stars, dodge the
bombs, grab hearts to heal, and reach each level's target before the
75-second timer runs out. Five levels, a catch-streak combo multiplier,
a best score saved per player, and a win screen after level 5.

- **Move:** ← → or A / D on keyboard, ◀ ▶ buttons on touch.
- **Goal:** reach the level target (150 / 300 / 500 / 750 / 1000 points).
- **Orbs:** ★ Star +10, ★ Golden +25 (fast, rare), ♥ Heart +1 life,
  ✖ Bomb −1 life. Four catches in a row raise the multiplier, up to 3x.
- **Lives:** 3. A bomb costs one; a missed star breaks the combo.

## How it is built

- `src/shared/Config.luau` — every tuned number and the palette.
- `src/shared/OrbMath.luau` — pure maths (lanes, fall, catches, combo).
- `src/shared/GuiTheme.luau` — the shared look of every label and button.
- `src/server/GameServer.server.luau` — the authority: per-player state,
  spawn schedule, catch validation, levels, timer, game over / victory.
- `src/server/ScoreStore.luau` — best score in a DataStore, pcall-guarded.
- `src/client/GameClient.client.luau` — the screen: arena, HUD, menus,
  input (ContextActionService + touch buttons), orb rendering, catch reports.
- `src/client/Effects.luau` — pops, floating scores, bomb flash and shake.
- `main.ts` — copies the place, sources, screenshots and `PLAY.json` to
  `/output` and writes `dossier.json` with `vendor/makefun-roblox.ts`.
- `game.rbxl` — built with `rojo build default.project.json --output game.rbxl`
  (Rojo 7.7.1). No uploaded audio or images: the game works with no assets.

## Status — what is still missing

This repository is complete as a game, but it is **not yet submittable**:

1. **Publish:** `PLAY.json` still names no place (ids are 0). The game must
   be published as a Public experience from a Roblox account that can
   already publish (2+ days old, past the age check), then `PLAY.json`
   filled with its real `place_id` and `universe_id`.
2. **Screenshots:** `screenshots/` is empty. Three or four real gameplay
   captures (start, play, end) must be taken in Roblox Studio while the
   game is running, each ≤ 256 KiB, long side ≤ 1280, short side ≥ 480.

Both steps need Roblox Studio (Windows/macOS) and a Roblox account —
neither is available on the Linux machine that built this game. The
screenshots and the play link are deliberately left blank rather than
faked: a fabricated `place_id` or a mock screenshot would be refused
by the gate and would misrepresent the game to the judge.

## Build

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## License

MIT — see `LICENSE`.
