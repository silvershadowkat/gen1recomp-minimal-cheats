# Changelog

## Unreleased

### Fixed

- Refresh PokéPC follower sprites automatically when a followed Pokémon evolves or its shiny appearance changes.

## 2.0.5 - 2026-08-07

### Changed

- Moved the colored caught Poké Ball into the reserved space before the enemy level label, above the HP row, so levels 1 through 100 never affect its position.

## 2.0.4 - 2026-08-07

### Fixed

- Replaced the monochrome caught circle, which could read like an extra level digit, with a red/white/black pixel-style Poké Ball.
- Increased the spacing after the level in classic and staged battle HUDs.
- Added adaptive size and right-edge clamping so the icon remains fully inside both classic and wide HUD panels against level 100 Pokémon.
- Added `FOLLOWERS 0` as a true trainer-only composition, including suppression of Yellow's stock Pikachu follower.

## 2.0.3 - 2026-08-07

### Fixed

- Removed SilverShadow's redundant `FOLLOWER` party action so PokéPC's working `FOLLOWING` selector is the sole row and continues to change the follower without rearranging the party.
- Anchored the caught icon immediately after the enemy's level or status instead of to an absolute HP-bar coordinate.
- Embedded the caught icon into Dramatic Shape's snapped HUD texture, keeping it attached to the level in Stadium A/B and 2D-3D A/B battles as well as the normal layout.

## 2.0.2 - 2026-08-07

### Added

- Added the GitHub repository metadata used by Gen1Recomp's Mods screen for update checks, version browsing, and verified release-ZIP installation.
- Documented the one-time manual upgrade required for installs older than 2.0.2; future releases can update through Gen1Recomp.

## 2.0.1 - 2026-08-07

### Fixed

- Moved `SILVERSHADOW` to the top of normal Options and enabled Up/Down wraparound in every SilverShadow menu.
- Shortened crowded menu labels so toggle values no longer overlap.
- Made Pokémon-front follower counts include the lead Pokémon, allowing one Pokémon alone or one Pokémon with only the trainer trailing; counts five and six are now distinct.
- Prevented duplicate `FOLLOWER` / `FOLLOWING` party actions when PokéPC already supplies one.
- Moved the caught icon from the enemy name row to the far end of the HP row for classic and Stadium layouts.
- Consumed overworld SELECT while moving or input-locked so DexNav presses cannot also change the voxel camera.
- Reset paid field-heal escalation only after a completed Pokémon Center nurse heal; route changes intentionally retain the current cost.
- Documented that Box Heal affects stored Pokémon when closing storage and is unrelated to the paid Start-menu heal.

## 2.0.0 - 2026-08-07

### SilverShadow Mods integration

- Rebranded the visible mod and Options UI while retaining the `minimal_cheats` ID and existing setting keys.
- Refactored the runtime into deliberately ordered modules with coordinated owners for shared Options, Start, party, PC, input-step, and movement seams.
- Integrated All Pokémon Catchable 151, Useful Bag, Gen 3 Boxes, PC Anywhere, Area DexNav, HM Anywhere, Moves Manager, DV/EV Editor, Battle Move Info, Heal Anywhere, reusable machines, Summon, and the universal TM shop.
- Added Poison Save, Full Heal Catch, Perfect DVs, map/battle/box healing, Lights On, XP bar, caught indicator, and location banners.
- Replaced the old speed cheat with player-only foot/bike/surf OFF/ON/HOLD movement using x1.5/x2/x3/x4, a four-frame floor, and script-safe duration restoration.
- Added optional PokéPC Followers control integration without bundling external assets or wild-spawn functionality.
- Added Dramatic Shape/Touchpad SELECT arbitration so DexNav owns only safe free-roam SELECT.
- Added a 96-assertion headless regression suite, packaged Mod API loader test, and deterministic local/CI packaging validation.
- Changed the release asset to `silvershadow-mods-v2.0.0.zip` and expanded the workflow for the modular runtime.

## 1.1.1 - 2026-08-07

### Fixed

- Cheat category menus now reserve space for the footer and scroll after six visible rows.
- The control footer is compact enough to remain on one line (`A:CHANGE  B:BACK`).
- Long status messages can wrap without overlapping the final selectable cheat row.

## 1.1.0 - 2026-08-07

Expanded the original minimal cheat menu into categorized Battle, World, and Supplies menus while keeping the mod single-player focused.

### Added

- Categorized `BATTLE`, `WORLD`, and `SUPPLIES` cheat menus
- Player damage multiplier: x1 / x2 / x4 / x8 / x10 / OHKO
- Always Hit
- Always Critical Hit
- Always Move First
- Always Escape from wild battles
- No Wild Encounters
- Movement Speed: x1 / x2 / x3 / x4
- PC Rare Candy restock: keeps at least 99 Rare Candies in item storage while enabled
- Max Game Corner Coins action: sets coins to 9999
- Defense-in-depth online/link safeguards so gameplay cheats fall back to vanilla behavior during PvP/link sessions

### Existing Features

- Infinite HP
- Infinite PP
- EXP multiplier x1 / x2 / x4 / x8 / x10
- Endless Poké Balls
- 100% Catch Rate
- Persistent settings
- Runtime toggling without restarting

### Notes

- PC Rare Candy never reduces a stack above 99 and never deletes another PC item to make room.
- If PC storage is completely full and no Rare Candy stack exists, free one PC item slot and the cheat will stock Rare Candy automatically.
- `affects_link` remains false because the mod deliberately becomes inert for battle-affecting behavior during online/link PvP.

## 1.0.0 - 2026-08-07

Initial public release.

### Added

- Infinite HP
- Infinite PP
- EXP multiplier x1 / x2 / x4 / x8 / x10
- Endless Poké Balls
- 100% Catch Rate
- Options -> CHEATS menu
- Persistent cheat settings
- Runtime toggling
- Link Battle safeguards

EXP multiplier was implemented in this release, but it had not yet been manually verified in-game before the initial public release.
