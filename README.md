# Rot Ranch (腐烂牧场)

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/sayanget/rot-ranch/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/sayanget/rot-ranch/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D brainrot ranch for make.fun's roblox-brainrot-01 bounty. Play: https://www.roblox.com/games/70608989520373

**The loop.** Walk your R15 rancher (WASD, Shift to sprint) out to the **Cattle Drive**, the dirt trail
where critters trot from the Rot Corral to Dust Canyon wearing their price tags. Hold **E** to lasso one:
it flies over the fence into a free stall of your ranch and starts paying its money a second, with a
"+$" pop over its head every tick. Climb the ladder (Common, Uncommon, Rare, Epic, Legendary, Mythic,
Rotten God), hope for Golden (x3) or Moldy (x2) mutations, then **Rebirth** (R) for a permanent cash
multiplier, two more stalls, a longer gate lock and rarer critters on the drive.

**The tension.** Every ranch has a gate. Hold **E** on a critter behind a rival's *open* gate to rustle it
and run it home over your head (slower, and you drop it if you fall). Lock your own gate (**L**, the HUD
button or the LOCK pad, only from inside your ranch). Masked rustlers ride in to raid open ranches: tag
one to win your critter back. Every couple of minutes the dust rises over Dust Canyon: **STAMPEDE IN 10**,
then a herd of glowing-eyed rot bulls thunders down the whole drive. Anyone caught in the open is thrown,
drops what they carry and loses 15% of their cash. Behind a fence you are safe.

**The cast** (all original): Spudmoo (potato cow), Cluckaroni (macaroni chicken), Hamwich Hog (sandwich
pig), Baagel Bleatski (bagel sheep), Goatcho Supremo (nacho goat), Toastallion (toaster horse),
Llamplighter (lamp llama), Duckwaffle Deluxe, Tractortoise, Sheriff Scarecrowbar, Disco Udderlord and
The Grand Rotfather. Each is its own part-built silhouette, labelled with name, rarity and $/s.

## Layout

- `default.project.json` describes the world (prairie, drive, red barn, silo, water tower, Rot Corral,
  Dust Canyon, golden-hour lighting) and maps the scripts.
- `src/shared` (ReplicatedStorage): `Cast` (critters, rarities, mutations, prices, rebirth rules), `Controls`.
- `src/server/Ranch.server.luau` boots the server; `src/ranch` (ServerStorage): `Ledger` (all state),
  `CattleDrive`, `Pens`, `Income`, `Rustling`, `Stampede`, `Rebirth`; `src/workshop`: `World`, `Critters`.
- `src/client`: `RanchClient` (ReplicatedFirst) and `Hud` (StarterPlayerScripts).

Build with `rojo build default.project.json --output game.rbxl`; hand in with
`mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts`.

<sub>Entered on [make.fun](https://make.fun/?ref=2skz259x&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
