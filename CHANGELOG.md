# Changelog

## 2.1.6 - 2026-08-08

### Added

- Add a safe, zero-cost ordinary-item catalogue to each editable Useful Bag pocket. Press SELECT on a pocket, choose from the live Red/Blue/Yellow item registry in native game order, choose a quantity, and confirm.
- Add `QUANTITY` to ordinary owned items' existing Bag `USE` / `TOSS` menu, allowing an exact stack size from 1 through 99.
- Add `EDIT PC ITEMS` to Start-menu and physical-PC storage, with categorized add, exact-quantity, and removal actions for PC item stacks.

### Safety

- Exclude all TMs, HMs, Key Items, badges, and unused placeholder records from creation and quantity editing.
- Keep item editing inert during link play and preserve normal mart stock, badge progression, prices, and sell values.

## 2.1.5 - 2026-08-08

### Fixed

- Respect the configured trainer composition during Free Fly, SURF, and town-FLY departure/arrival. Pokémon-lead mode with `TRAINER TRAIL` off now shows the traveling lead Pokémon by itself in both classic and voxel rendering; enabling `TRAINER TRAIL`, or using trainer-front mode, keeps the trainer riding the lead Pokémon.

## 2.1.4 - 2026-08-08

### Changed

- Keep ground-only Pokémon visible during Free Fly over walkable land, where they run along the trainer's exact trail using normal follower animation. They temporarily return to their Poké Balls over water, fences, buildings, map seams, and other non-walkable cells, then respawn safely when the trainer reaches walkable ground again.
- Ground followers do not perform independent route-finding. Flying through a safe opening gives them a valid trail to follow; flying directly across blocked terrain uses the hide-and-respawn fallback instead.

## 2.1.3 - 2026-08-08

### Fixed

- Make SURF taught through the Move Editor a complete field capability without requiring HM03: it appears in that Pokémon's submenu, works through the contextual water interaction, supplies the player's surf mount, and qualifies the Pokémon as a swimming follower. `BADGE CHECK` still controls the Soul Badge requirement.
- Keep Start -> HM strictly inventory-based. Teaching FLY through the Move Editor no longer creates the HM menu; an actual HM02 or HM05 item is required for that menu, while edited FLY remains available from the Pokémon submenu.

### Clarified

- Waterfall is present in Gen I as a regular battle move, not an HM or overworld field move, so All Moves may teach it without creating a field action.

## 2.1.2 - 2026-08-08

### Fixed

- Treat Pokémon taught SURF through the Move Editor as swimmers in travel-aware follower formations after HM03 has been obtained, even when their species cannot naturally learn SURF.
- Make dual FLY/SURF followers use the capability matching the current trip: they fly during Free Fly and swim during SURF. FLY-only companions can still fly alongside the trainer while surfing.
- Apply `BADGE CHECK` consistently to SURF: ON requires the Soul Badge and OFF permits using owned HM03 without it, matching Free Fly and town FLY behavior.

## 2.1.1 - 2026-08-07

### Fixed

- Treat FLY taught through the Move Editor as a real field capability even for species that cannot naturally learn it. The Pokémon submenu and Start -> HM now expose ordinary town FLY without requiring HM02, while still honoring the optional badge check and outdoor-map requirement.
- Classify any Pokémon that actually knows FLY as an airborne travel follower, so edited move sets behave consistently during Free Fly and SURF formations.
- Revalidate Free Fly eligibility and the badge setting at takeoff, preventing a party menu left open across an option change from bypassing the current safety setting.

## 2.1.0 - 2026-08-07

### Added

- Integrated a SilverShadow-specific Free Fly party action for eligible FLY users, with A-to-land controls, assisted landing, outdoor collision bypass, safe water landings, story-gate and badge enforcement, trainer-sight control, voxel-aware height, and strict link-session disablement.
- Added `FLY BOOST`, `FLY HEIGHT`, `TRAINER SIGHT`, `STORY GATES`, and `BADGE CHECK` to Movement. Flight speed uses the existing shared `MOVE BOOST` multiplier and OFF/ON/HOLD behavior; no SELECT shortcut, whistle, or gift Pokémon is included.
- Added travel-aware follower formations. The trainer rides the selected flight or SURF mount; Flying types fly, Psychic/Ghost types hover, and Water/SURF-capable followers swim after HM03 is obtained. Ground-only followers temporarily return to their Poké Balls and the exact configured pack returns on safe land.
- Added per-species surf mounts for actual SURF-knowing party members while retaining the normal engine surf sprite for HM-device fallback.
- Added `ALL MOVES` to the party Move Editor. SELECT switches between remembered moves and the complete live move registry; damaging moves are grouped by Gen I Physical/Special type and Status moves by Major Status, Stat Lower, Stat Raise, Field/State, Traps/Triggers, Recovery, or Utility/Other. Every registered move is indexed exactly once and each final list is alphabetical.
- Added player-owned levels 101 through 255. Battle EXP and Rare Candy continue leveling normally, every post-100 level uses the species' 99-to-100 EXP requirement, wild/trainer PokÃ©mon remain unchanged, and the DV/EV Editor now includes a direct `LEVEL` row.
- Added `NO DRAWBACKS` to Battle options. Player charge moves resolve immediately, Hyper Beam-style recharge is removed, and self-KO moves do not faint the user. `INFINITE HP` also independently protects the player from Selfdestruct and Explosion.

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
