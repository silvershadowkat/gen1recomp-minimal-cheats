## 3.3.1

- Show a tiny, always-visible speed multiplier at the top right in all three generations. Read the engine’s effective speed live, including contextual speeds, fast-forward and link-play locks. Draw crisp pixel text after shaders and screen scaling.

## 3.3.0

- Add an automatic Rare Candy quantity picker across Gen 1-3. Apply each native level gain, move-learning check and evolution in sequence; consume only successful candies and show total level, HP and stat growth. Respect inventory, eggs, native restrictions and existing level caps. This is item functionality, not a cheat toggle or Mod Deck action.
- Preserve the imported capture ball silhouette and rim in both wobble directions. Rotate only the painted interior on the native pixel grid, keeping Poké, Great, Safari, Ultra and Master Balls crisp without blur. Gen 2 exclusive balls retain their native art.
- Let B exit the native Gen 3 party-screen stop-learning confirmation, including during a candy batch.

# 3.2.0 — Mod Deck live cheat settings

- Add a local data-only bridge for the active game/save across all eleven versions. Reuse the in-game option definitions and setting setters; expose cheat toggles and multipliers without tools/editors/actions.
- Sync both directions, including an already open SilverShadow options menu. Validate session, game, expected previous value, setting key and allowed values; acknowledge applied/rejected requests. Retain link-play restrictions and normal in-game save semantics.
- Pair with Mod Deck 0.5.38 (build 115): active-game heading, live values, pending acknowledgements and disabled controls when disconnected. Existing native cheat adapters and controller helpers remain unchanged.

# 3.1.10 — Post-catch nickname prompt

- Keep Gen 1 nickname YES/NO prompts on the modern 256×192 canvas when they appear above battle dialogue. Preserve native choice callbacks, caught Pokemon storage, Pokedex registration and name-entry screens. Party and PC confirmations retain their own layout.

# 3.1.9 — Native bag pouches and battle item messages

- Move SUMMON immediately above MODS in the shared Gen 1/2 Start menu.
- Add Left/Right pouches to Gen 1 field Item and battle Bag, using the PC item editor classifications. Keep native use/toss/cancel and stack-aware SELECT/A reordering; remember field and battle pouches separately. Begin battle bags on Poké Balls.
- Fit long TM/HM labels inside the native item box.
- Keep battle item messages on the modern 256×192 surface, including rejected Moon Stone use, without altering native item outcomes, party menus or disabled-HUD behavior.

# 3.1.8 — Move learning cancellation and adjusted power

- Make B accept the stop-learning confirmation in all three generations, so repeated B presses leave the move-learning flow instead of looping. A on NO still resumes learning; native completion callbacks, item consumption and unrelated YES/NO choices are preserved.
- Show PWR in the modern Gen 1/2 and Gen 3 move-info window: base power × STAB × type effectiveness. Use current battler types, including transformations, and Gen 3 target/ability immunities. Mixed or unselected double-battle targets show `?`; status and nonstandard base-power moves show `--`.
- Keep PP, colored type and matchup text, with four aligned rows. PWR is a comparison value, not HP damage; it excludes Attack/Defense, random rolls, critical hits, weather and damage-cheat multipliers.

# 3.1.7 — Local collection, Summon and capture artwork

- Keep Gen 1's modern battle canvas behind trainer-switch and post-faint YES/NO prompts, with a matching popup and native choice behavior. Preserve native Party/Bag layouts.
- Replace Gen 2/3 global encounter timers with fixed local habitat/progression mappings and an uncaught-local preference on every normal encounter. Keep ordinary native encounters and mix in local additions even with the preference off.
- Give every Johto/Hoenn species a FireRed/LeafGreen home after the actual National Dex unlock. Put extra legendaries in Cerulean Cave; preserve scripted encounters and existing Pokemon. Use Mt. Silver and Sky Pillar for the corresponding extra legendary pools in Johto and Hoenn.
- Make registered Gen 3 DexNav start an uncaught local wild battle immediately. Use the same area pools as ordinary encounters, including water while surfing.
- Add Gen 2's 251-species Summon list and change Gen 3 Summon from direct party grants to native wild battles. Summon uses a healthy lead's level and respects FRLG's National Dex restriction.
- Redirect modern Gen 1/2 capture balls to matching imported Gen 3 Poke, Great, Ultra, Master and Safari Ball artwork, preserving native trajectories, shakes, particles and capture outcomes. Gen 2-exclusive balls keep their native art.

# 3.1.6 — Start-menu cleanup

- Delete the paid Heal Anywhere module, removing its HEAL shortcut and field-machine rendering hooks from the code and release package. PC access and other healing tools are unchanged.

# 3.1.5 — Evolution and move learning

- Add independently toggled Gen 1/2 evolution presentation, native old/new-form timing, high-contrast silhouettes, and clean full 4:3 composition using imported FRLG assets.
- Carry native move-learning prompts, choices, forget lists and results into the same presentation, including type colors, PP and move details. Preserve native callbacks and existing HM/reusable-machine behavior.
- Decode the money glyph as ¥ instead of the imported `<ED>` alias. Raise the opponent's Gen 1 intro Poké Balls without moving the player's row.
- Keep Gen 3 and saved progress untouched.

# 3.1.4 — Followers across doors and routes

- Gather Gen 1/2 followers at the arrival tile after a warp; do not invent a trail through houses or walls.
- Preserve follower entities, movement progress and trail history across connected routes in all three generations, translating into the destination map’s coordinates.
- Preserve Gen 2’s primary follower as well as the extra party followers, and retain Yellow’s special Pikachu without duplicating it.
- Check every intervening ground tile when creating a new behind-player formation.
- Retain 3.1.3’s title/intro pixel fixes and shared move colors.

# 3.1.3 — Title pixel preservation and editor colors

- Align Gen 1 boot/title artwork and retro-v3 sampling to the same whole-pixel scale, preserving thin letter strokes.
- Extend the original Red/Blue intro bars across the wide surround, including native palette fades.
- Share one type palette across battles and Gen 1/2/3 move editors; color move lists, type categories and type labels without changing move rules.

# 3.1.2 — Battle layout and LCD refinements

- Use a 256x192 battle canvas for an exact 5x pixel scale on the 1280x960 Nova. Preserve sharp native sprite and font proportions.
- Repair native Gen 1 Bag/Party transitions, level-up stats, intro party balls, back-sprite baseline and entry clipping; interpolate native HP animation for smoother display.
- Add a 4:3 battle view to FireRed, LeafGreen, Ruby, Sapphire and Emerald, retaining each game’s own terrain, chrome and controls. Party and Bag screens extend native backgrounds to 4:3 while preserving unscaled text, icons and controls.
- Add colored move names and read-only type matchups to Gen 3. Respect selected double-battle targets; show VARIES for mixed spread matchups, STATUS for support moves and SPECIAL for fixed/conditional damage.
- Reflow Gen 2 Party/Pack panels across 4:3, retain all six party rows and item submenus, and match the LCD sampling lattice to the actual battle/menu render scale.
- Align fractional retro-v3 LCD grids without changing preset parameters or overworld zoom.

# 3.1.1 — LCD shader pixel alignment

- Remove retro-v3's tiny UV stretch in its loaded vertex shader so LCD grid lines keep a consistent phase and thickness. Applies to fresh and cached translations without modifying preset files.
- Keep Shader FX intermediate canvases at explicit pixel resolution on high-DPI devices. This fixes uneven LCD grid lines and triangular shading caused by doubled render targets and resampling on the Nova.
- Scope the correction to the shader pass; retain native world/UI canvas scaling and all preset choices. Restore the graphics constructor even if a shader fails.
- Add focused regression coverage for target sizing, option preservation, idempotence and error cleanup.

# 3.1.0 — Gen 3 / engine 0.3.91

- Support all eleven Gen 1–3 games with generation-native module loading.
- Add Gen 3 battle cheats for both allied slots, native PP/HP/ball handling, and link exclusions. Keep trainer and unsupported double capture restrictions.
- Add 386-species normal/shiny followers, Pokemon control and optional trainer trail.
- Add map-local Free Fly with default badge/story gates, safe landing, return-to-ground and airborne save rejection.
- Add Gen 3 Dex Hunt, queued DexNav, no-trade evolution alternatives and obtainable held items, retaining native evolution gates.
- Add Gen 3 IV/EV/level editors and current-level/ancestral move learning with a SELECT-switchable categorized full move picker.
- Restore native Gen 1 Bag and PC item operations; retain a separate additive item editor. Keep native Gen 2/3 inventory screens.
- Add an optional full 4:3 Gen 1/2 battle layout redirecting to imported FRLG sprites, matching trainer portraits, UI and font assets. Add type-colored moves, effectiveness, HP and caught indicators.
- Preserve native Yellow starter Pikachu identity, happiness and availability alongside extra followers.
- Remove the retired starter substitution and cache a missing optional healing-machine image, with a drawn fallback.
- Add HM-device field actions in Gen 2/3, including native RSE scripted prompts, while preserving follower move/type eligibility.
- Add reusable Gen 2/3 TMs, registered Gen 3 DexNav, and current-page instant text across all three generations.
- Preserve native Gen 3 battle terrain and select appropriate Gen 1/2 terrain/leader/League visuals.
- Use built-in engine LCD presets and retain PokéPC integration for Gen 1/2.
- Validate the real 0.3.91 loader and live runtime across all eleven games, including Gen 3 double battles, collection/evolution checks and Gen 1/2 battle presentation.

# Changelog

## 3.0.17 - 2026-08-31

- Applied Gold/Silver/Crystal's active object palette to the replacement trainer drawn on the real Surf Pokemon, fixing the gray, colorless rider while retaining the full-color mount.
- Composed around PokePC's private map-entry Surf purge so a lead follower that can FLY continues over water instead of appearing briefly and disappearing on the first step.
- Reserved the approved lead follower's formation cell throughout Surf transitions, preventing later followers from jumping forward or onto the mounted player while the lead entity is rebuilt.

## 3.0.16 - 2026-08-31

- Replaced Gen 2's generic Lapras Surf player sheet with the actual healthy party member that used SURF. The trainer is drawn riding that Pokemon using PokePC's installed follower artwork; the native Lapras remains the safe fallback if artwork is unavailable.
- Kept FLY-capable and other terrain-legal primary followers visible while surfing instead of inheriting PokePC's blanket Surf hide rule.
- Excluded the ridden SURF Pokemon from the follower formation and compacted trail slots dynamically, so hidden or mounted Pokemon cannot leave empty gaps between visible followers.

## 3.0.15 - 2026-08-31

- Made Gen 2 `BADGE CHECK` govern every native badge-gated field move as well as Free Fly. With it OFF, CUT, FLASH, SURF, FLY, STRENGTH, WHIRLPOOL, and WATERFALL use their normal terrain/location rules without requiring their badge; Move Editor knowledge remains sufficient on any species.
- Kept FREEFLY visible for a FLY user who is missing the Storm Badge. Selecting it now shows the normal badge-required refusal instead of silently hiding the action.
- Replaced oversized Gen 2 Pokemon action boxes with a six-row scrolling viewport, keeping FREEFLY and all field/editor actions reachable without drawing above the screen.
- Tightened airborne follower terrain filtering: a ground-only follower now hides over trees, walls, water, and other non-walkable cells, while FLY/SURF/hover-capable followers retain their appropriate travel behavior.

## 3.0.14 - 2026-08-31

- Added a generation-isolated Free Fly controller for Gold, Silver, and Crystal. A healthy Pokemon that knows FLY can take off outdoors; `BADGE CHECK` requires the Storm Badge for FLY and Fog Badge for water landings by default, while Move Editor knowledge remains authoritative for any species.
- Added the Gen 1 flight controls to Gen 2 Movement options: FLY BOOST, FLY HEIGHT, TRAINER SIGHT, STORY GATES, and BADGE CHECK. Flight suppresses encounters, warps, forced tiles, and trainer sight by default, supports legal land and Surf landings, and survives outdoor map connections.
- Extended the native Gen 2 follower controller with terrain-aware travel. FLY users and Flying types flap in the air, SURF users swim, Flying followers cross water, Psychic/Ghost followers hover, and followers without a legal travel style hide until the terrain permits them again.

## 3.0.13 - 2026-08-31

- Matched native Gen 2 extra-follower movement to PokePC's primary follower timing. Extras now commit when the player starts a step and burn the same first animation frame, removing the temporary one-cell gap while moving.

## 3.0.12 - 2026-08-31

- Fixed native Gen 2 extra followers disappearing on map changes by verifying that cached follower NPCs still exist in the newly rebuilt map.
- Replaced the shared destination queue with player path history so the primary PokePC follower and every SilverShadow extra remain one cell apart when the party stops.

## 3.0.11 - 2026-08-31

- Replaced the reused Gen 1 follower controller on Gold/Silver/Crystal with a small native Gen 2 controller. PokePC retains the primary follower and sprite ownership; SilverShadow adds extra healthy party members using Gold's native `Npc` and `Follower` APIs. Gen 1 remains unchanged.

## 3.0.10 - 2026-08-31

- Added a bounded, phase-labelled Gen 2 follower synchronization pass. If an incompatible Gold/Silver/Crystal runtime structure would otherwise spin forever, SilverShadow now disables only its expanded controller and safely falls back to the separately installed PokePC follower.

## 3.0.9 - 2026-08-31

- Fixed Gold/Silver/Crystal freezing at 100% CPU when loading a save with PokePC Followers and SilverShadow enabled together. Gen 2 now installs the expanded follower controller only after the live overworld has completed a world step; Gen 1 keeps its existing activation timing.

## 3.0.8 - 2026-08-31

- Restores `SILVERSHADOW` and `LCD DISPLAY` as the first two entries in the
  grouped Options screen for Red, Blue, Yellow, Gold, Silver, and Crystal.
- Makes Android L2/R2 trigger axes detectable in CONTROLS and routes their
  saved bindings through normal gameplay in both generations.
- Makes Gen 2 OUT zoom levels match the physical step size used by Gen 1 on
  high-DPI Android screens, so OUT1 no longer jumps disproportionately far.
- Activates SilverShadow's multi-follower controller against Gen 2's live
  `game.world`, while preserving the existing Gen 1 `game.overworld` path.
- Adds a pocket-aware free item editor to Gen 2's PACK: SELECT on CANCEL opens
  Items, Balls, or TM-only stock, while Key Items and HMs remain excluded.
- Re-audits Gen 2 status-move groups, including all recovery, screen/weather,
  stat-change, volatile-condition, and utility effects.

## 3.0.7 - 2026-08-31

- Fixed Blue's separated bag swallowing every controller button after the new
  physical L/R pocket shortcuts were added. A, B, Start, Select, D-pad, and
  all other unclaimed buttons now continue through Gen1Recomp's normal input
  mapping, while L/R alone are consumed for pocket changes.

## 3.0.6 - 2026-08-31

- Fixed Blue's separated overworld bag accepting D-pad pocket changes but not
  the physical L/R shoulder shortcuts shown in its footer. Bag L/R now changes
  pockets before Gen1Recomp's global speed shortcut can consume the press.
- Rebuilt Blue pocket rows against the live game data and bag order, keeping
  existing inventory visible across Red, Blue, and Yellow save variants.
- Fixed Gold/Silver/Crystal DEXNAV being registered in game data but never
  granted on a fresh boot because `game.ready` precedes overworld creation.
  It is now granted immediately and its field handler attaches after load or
  before the Start-menu Pack can be opened.

## 3.0.5 - 2026-08-31

- Fixed Poke Balls being hidden from Blue's in-battle item menu by the
  separated field-bag pockets.
- Blue battles now use the original complete battle inventory again, while
  the separated overworld bags and their item editor remain unchanged.
- Fixed Gold's Start-menu BOXES shortcut softlocking because the native PC
  screen had no close callback. SEE YA! and B now both exit normally.
- Added DEXNAV as a permanent Gold/Silver/Crystal Key Item. It can be used
  from the Pack or registered through its SEL action for the native SELECT
  shortcut, and searches the current map's current-time land or water table.
- Fixed the Gold Move Editor crashing while building FIRE and other type
  lists when numeric move-table metadata was mistaken for a move record.
- Audited the complete six-game move catalogue and enforced the original
  type-based split: Dark is Special and Steel is Physical in Gen 2.
- Shortened crowded Gold cheat labels so names and ON/OFF or choice values no
  longer overlap or disappear off the menu.

## 3.0.4 - 2026-08-31

- Fixed Blue's Oak escort becoming input-locked at the starter table when the
  default movement multiplier was enabled.
- Movement boosts now remain at the vanilla clock before the first party
  Pokémon and during scripted movement, dialog holds, warps, and transitions.
- Normal foot-speed boosting begins automatically when genuine free roam is
  available; bike, Surf, and Free Fly behavior is unchanged.

## 3.0.3 - 2026-08-31

- Fixed Blue new games remaining input-locked after Oak says to choose a
  Pokémon. SilverShadow now leaves PokéPC completely unwrapped until a valid
  party exists and the player reaches a safe, ordinary overworld step.
- Existing saves still activate the expanded follower controller when their
  map loads; new saves hand off only after the starter sequence is complete.
- Pre-activation follower checks are now read-only and never rebuild the
  overworld NPC/entity lists used by scripted movement callbacks.

## 3.0.2 - 2026-08-31

- Fixed new-game compatibility with PokéPC Followers. SilverShadow now waits
  until the starter/nickname script has fully returned to the overworld before
  activating its custom follower controller.
- Fixed Pokémon-front mode replacing the player with a fallback sprite before
  the first party Pokémon existed, which could prevent normal new-game movement.
- Left PokéPC's standalone spawn behavior in charge during the starter handoff
  and stopped overriding its party-selection helper.

## 3.0.1 - 2026-08-31

- Restored the original Red/Blue/Yellow and Gold/Silver/Crystal Pokemon box screens.
- Removed the custom box grid, box healing, and box cursor controls from the loaded modules and release payload.
- Kept PC Rare Candy unchanged and kept the Useful Bag's separated pockets; its cursor-wrap setting now appears as **BAG CURSOR WRAP** under Supplies.

## 3.0.0 - 2026-08-31

### Added

- One installable mod for Red, Blue, Yellow, Gold, Silver, and Crystal, with generation-specific module loading.
- Gen 2 battle cheats, healing tools, storage access, movement controls, Move Editor, and DV/EV Editor.
- All Pokemon Catchable 251 Dex Hunt for Gold, Silver, and Crystal, with an adjustable encounter interval.
- Single-player Gen 2 evolution paths for all ten trade evolutions, preserving Poliwhirl and Slowpoke's alternate branches.

### Changed

- Read Gen 2 `levelMoves`, `into` evolution links, live move categories, Dark and Steel types, and Whirlpool/Waterfall HM locks in the Move Editor.
- Restore optional 0-6 follower formations and trainer/Pokemon control modes for all six games by consuming the separately installed burgerslayer7 PokePCFollowers fork's public 251-sprite provider API; no provider artwork is bundled.
- Replace the legacy debug-upvalue follower spawn patch with Gen1Recomp's API 2 `setShouldSpawn` seam.
- Keep the smaller Gen 2 healing menu and omit redundant PC/heal-anywhere variants.

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
