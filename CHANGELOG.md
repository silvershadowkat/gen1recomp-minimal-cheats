# Changelog

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
