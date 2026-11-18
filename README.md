# Rot Ranch (腐烂牧场)

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/sayanget/rot-ranch/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/sayanget/rot-ranch/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D brainrot ranch for make.fun's roblox-brainrot-01 bounty. Play: https://www.roblox.com/games/70608989520373

## Version 2: what's new

- **A soundtrack and sound effects, made in-game.** No uploaded audio: `RanchAudio` pitches Roblox's
  built-in samples by semitones to play an original boom-chick western reel (bass, banjo rolls, a lead
  tune, clip-clopping hooves) and every cue: lasso whoosh and arpeggio, cash ticks, gate clunk, rustle,
  rebirth fanfare, mutation sparkle, the stampede siren and rumble, the rustler's whistle, the twister's
  wind and a sad-trombone sting when you are trampled. The music ducks under every warning. **M** mutes it.
- **23 original critters, 5 mutations.** Eleven new ones join the cast (Tumbleweasel, Beanburro, Cactopus
  Rex, Jalapeño Jackalope, Wienerbago, Banjo Buzzard, Rattlesnack, Haybale Hydra, Brisket Bronco, The
  Moothership, Skelecow Supreme). Moldy x2 and Golden x3 now sit beside **Spicy x4** (on fire),
  **Crystal x6** (glass and shards) and **Ghost x10** (spectral force field). Drive weights are split per
  rung so the new rares show up without flooding the drive with Rotten Gods.
- **Two new events** on a shared calendar with a visible next-event timer: **Golden Hour** (the sky turns
  gold, glitter falls on the drive, pens pay x2 and Golden critters roll 4x as often) and the
  **Dust Devil** (a purple twister that snakes through a row of ranches, flings anyone not sheltering in
  a locked ranch and spits coins to chase). The **stampede** and **rustler raids** are still there.
- **Onboarding and progression UI.** A four-step trail guide (lasso, get home, lock, survive an event),
  a **RanchDex** (B) with turning 3D portraits, ??? silhouettes and mutation pips, and a **contract
  board** of three short jobs that pay cash or a Lucky Horseshoe (extra drive luck).
- **World, light and juice.** Lighting is built from source (`Mood`: sky, atmosphere, bloom, sun rays,
  colour grading) and changes with every event. A neon ROT RANCH arch spans the drive; there is a
  chuckwagon camp, lantern posts, pines, dead trees, rocks, flowers, rolling tumbleweeds and a water
  tower with a turning vane. The lasso is a visible rope. Critters trot, breathe, hop and wriggle
  (`CritterMotion`), and the cash counter, "+$" pops and reward pops bounce.

## How to play

**The loop.** Walk your rancher (WASD, Shift to sprint) out to the **Cattle Drive**, where critters trot
from the Rot Corral to Dust Canyon wearing their price tags. Hold **E** to lasso one: the rope flies,
and it sails over the fence into a free stall of your ranch, paying its money a second. Climb the ladder
(Common, Uncommon, Rare, Epic, Legendary, Mythic, Rotten God), hunt mutations, fill your RanchDex,
finish contracts, then **Rebirth** (R) for a permanent cash multiplier, two more stalls, a longer gate
lock and better luck on the drive.

**The tension.** Every ranch has a gate. Hold **E** on a critter behind a rival's *open* gate to rustle
it and run it home over your head. Lock your own gate (**L**, the HUD button or the LOCK pad). Masked
rustlers ride in to raid open ranches: tag one for your critter back and a bounty. The calendar runs
the stampede (off the drive or be trampled for 12% of your cash), Golden Hour and the Dust Devil.

## Layout

- `default.project.json` describes the world (prairie, drive, red barn, silo, water tower, Rot Corral,
  Dust Canyon) and maps the scripts.
- `src/shared` (ReplicatedStorage): `Cast` (critters, rarities, mutations, economy), `Critters` (the
  part-built 3D models, mutation finishes, labels, lasso rope), `Controls` (keys, cues, throws).
- `src/server/Ranch.server.luau` boots the server. `src/ranch` (ServerStorage): `Ledger` (all state,
  deeds and cues), `Events` (the calendar), `Stampede`, `GoldenHour`, `DustDevil`, `CattleDrive`, `Pens`,
  `Income`, `Rustling`, `Rebirth`, `Contracts`, `Guide`, `Showcase` (reach each screen for a tour).
  `src/workshop`: `World` (ranches and scenery), `Mood` (lighting).
- `src/client` (StarterPlayerScripts and ReplicatedFirst): `RanchClient`, `Hud`, `RanchDex`,
  `RanchAudio`, `CritterMotion`.

Build with `rojo build default.project.json --output game.rbxl`; hand in with
`mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts`. `TOUR.json` reaches each screenshot through
`ServerStorage.Showcase.stage`.

<sub>Entered on [make.fun](https://make.fun/?ref=2skz259x&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
