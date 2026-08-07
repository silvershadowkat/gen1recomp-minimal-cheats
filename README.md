# SilverShadow Mods

SilverShadow Mods is an all-in-one gameplay and quality-of-life mod for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp). It evolved from Gen1Recomp Minimal Cheats and deliberately keeps the internal mod ID `minimal_cheats`, so existing settings continue to belong to the same mod after upgrading to 2.x.

Pokémon Blue is the primary target. Red and Yellow use the engine's live game data and version-aware encounter patches rather than a hard-coded Blue dataset.

## Install

Download `silvershadow-mods-v2.0.2.zip` from Releases and choose **Import mod .zip** in Gen1Recomp. Alternatively, copy the extracted `silvershadow_mods` folder directly into Gen1Recomp's `mods` directory. Do not use GitHub's automatically generated source archive.

The installable archive has `manifest.json`, `main.lua`, and `modules/` at its root; it contains no ROM data or Pokémon artwork.

Version 2.0.2 adds Gen1Recomp launcher updates through the mod's GitHub releases. If 2.0.1 or older is installed, import 2.0.2 manually once because those older manifests do not know which repository to check. From 2.0.2 onward, Gen1Recomp can check for updates, show available versions, download the release ZIP, verify the mod ID, and replace the installed copy from its Mods screen.

## Always-active systems

- Complete All Pokémon Catchable 151 content and impossible-evolution changes
- Useful Bag pockets, sorting, full TM/HM labels, 999 distinct bag types, and 999 distinct PC item stacks (normal per-item stacks remain capped at 99)
- Gen 3-style storage boxes and Start/physical-PC access to Pokémon and item storage
- Area DexNav on free-roam SELECT, using the final live encounter table
- HM Anywhere with HM-item and badge requirements; deterministic Surf/Fish interaction uses the best owned rod
- Moves Manager with evolutionary-line move memory and DV/EV Editor
- Battle Move Info, reusable TMs, forgettable HMs, and the universal free TM shop
- Start-menu Heal and Summon tools

These structural systems have no master toggle because other integrated systems rely on their data and UI contracts.

## SILVERSHADOW options

Normal Options contains one `SILVERSHADOW  OPEN` row. Its grouped menus contain:

- **Battle:** Infinite HP/PP, EXP x1/x2/x4/x8/x10, damage x1/x2/x4/x8/x10/OHKO, Always Hit/Crit/First/Escape
- **Capture:** 100% Catch, Endless Balls, Full Heal Catch, Perfect DVs
- **World:** No Encounters and Lights On
- **Healing:** Poison Save, Heal on Map Change, Heal after Battle, Box Heals
- **Supplies:** PC Rare Candy (target 99) and Max Game Coins (9999)
- **Movement:** x1.5/x2/x3/x4 and independent OFF/ON/HOLD behavior for foot, bike, and surf movement
- **Display:** XP Bar, caught indicator, and location banners (all on by default)
- **Storage:** Classic/Big box grid and cursor wrapping
- **Followers:** shown only when PokéPC Followers is installed

`BOX HEAL` is the Gen 3 storage behavior: when enabled, closing the storage screen heals Pokémon in boxes. It does not control the paid `HEAL ¥...` Start-menu command. Paid field-heal cost increases with each use and resets only after completing a heal with a Pokémon Center nurse; changing maps or routes does not reset it.

`ON` movement is boosted by default and holding B temporarily returns to vanilla speed. `HOLD` is vanilla by default and holding B boosts it. The unified engine only adjusts player manual-step duration, calls the engine's existing modifier first, floors movement at four frames, and restores the vanilla duration before scripts.

## Compatibility and safety

- **Link/PvP:** gameplay cheats become inert during link battles and sessions. `affects_link` remains false by design.
- **Dramatic Shape Voxel Mod:** SilverShadow's outer free-roam handler owns controller/touch SELECT for DexNav; keyboard `3`, Dramatic Shape's Options rows, battle SELECT, and menu SELECT remain untouched.
- **SilverShadow Touchpad:** virtual SELECT uses the same normal input path as controller SELECT and therefore reaches DexNav.
- **PokéPC Followers:** optional. In Trainer mode, `FOLLOWERS` is the number of Pokémon behind the trainer. In Pokémon mode, it is the total number of Pokémon on screen including the lead; `TRAINER TRAIL` independently puts the trainer behind them. PokéPC remains the owner of all walker sprites.

Followers EX is not required. No PokéPC, Dramatic Shape, Stadium, follower, or ROM-derived assets are bundled. Overworld Encounters and Followers EX wild-spawn/roaming systems are intentionally not included.

## Development

Runtime files are selected by `runtime-files.txt`. Run the headless suites with the Gen1Recomp LuaJIT executable and `tests/test_silvershadow.lua` plus `tests/test_loader.lua`, then run `python tools/package.py` to build and validate both install formats. The same packaging script is used by the release workflow.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for references and license attribution.

## Disclaimer

This unofficial community mod is not affiliated with or endorsed by Nintendo, The Pokémon Company, Game Freak, or the Gen1Recomp developers. No ROM or Pokémon game assets are included.
