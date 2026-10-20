# SilverShadow Mods

SilverShadow Mods supports all eleven Gen 1–3 games in [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire, and Emerald. Version 3.1.4 targets engine 0.3.91 and keeps the internal mod ID minimal_cheats, preserving existing settings.

The entry point selects a generation-safe module set at runtime. Red, Blue, and Yellow retain the compatible original suite. Gold, Silver, and Crystal use the generation-native battle, editor, movement, healing, and catch/evolution implementations. The engine's original Pokemon boxes are preserved in both generations.

## Install

Use the packaged silvershadow-mods-v3.1.4.zip and choose **Import mod .zip** in Gen1Recomp. Alternatively, copy the extracted silvershadow_mods folder into Gen1Recomp's mods directory. Build the package with `python tools/package.py` when using an unreleased branch. Do not use GitHub's automatically generated source archive.

## Gen 3

Open **START → SILVERSHADOW**. Gen 3 uses native menus and data structures, independently of the older modules.

- **Battle:** EXP and damage multipliers, OHKO, infinite HP/PP, unlimited balls, always hit/critical/first/escape, guaranteed catch, and no random encounters. Both allied slots in double battles are handled. Link battles bypass gameplay cheats; normal game restrictions outside a hook (such as trainer capture restrictions) remain. Trainer catching stays blocked, and balls do not bypass the native restriction while two wild opponents remain.
- **Healing/items:** heal now, heal after battles/map changes/catches, perfect-IV catches, 99 Rare Candies, max money/coins, and perfect party IVs.
- **Party editor:** level, individual IVs, EVs (510 total cap), and move choices for each slot. The default list contains current-level level-up moves, including prior evolutions, plus current moves. SELECT switches to all 354 moves grouped by physical/special type and status category. The move editor can replace HMs; valid moves can be assigned to any species.
- **Summon:** all 386 National Dex species at level 25, using the game's party/PC placement. **Items/TMs** fills a chosen non-key item to 99, subject to native bag limits. **Pokemon PC** opens native storage anywhere.
- **Followers:** 0–6 healthy party followers, including Hoenn species and shiny art. Water types and taught SURF users swim; Flying types and taught FLY users can travel through the air. Ineligible followers hide over water. These travel abilities are independent of the HM device. Pokemon mode replaces the trainer's visual with the first healthy party Pokemon; an optional trainer trails behind. These sprites are bundled, so Gen 3 needs no PokéPC provider. Keep your existing PokéPC provider enabled only for Gen 1/2.
- **Collection:** Dex Hunt replaces every 20th ordinary wild encounter with an uncaught species from the 386-species registry, including version exclusives. Its interval is configurable. DexNav queues an area, uncaught, or chosen National Dex species for the next ordinary encounter, preserving its native level. Roaming, scripted, Safari, and link encounters are excluded. All twelve trade evolutions have level-up alternatives; held-item evolutions still require their original item, available from Items/TMs. Evolution consumes the item only after successful evolution and retains native restrictions such as FireRed/LeafGreen National Dex gates.
- **Free Fly:** take off/land from the movement menu; move over obstacles within the current map. BADGE CHECK and STORY GATES default on. The native Fly badge and either the Fly HM device with a healthy party helper or a healthy Fly user are required; landing must be clear and reachable from the takeoff point through ordinary ground without crossing warps, active event triggers, water, or blocking terrain. This is deliberately conservative around story barriers. RETURN TO GROUND restores the takeoff location. Saving is blocked while airborne. Map-boundary flight and levels above 100 are not supported in Gen 3.

L/R page through long catalogues. Battle cheats default off; follower count defaults to one. Settings remain scoped by the engine's mod-save system.

Version 3.1.2 keeps Shader FX intermediate canvases at explicit pixel resolution on high-DPI devices, avoiding uneven LCD grids and triangular shading from implicit DPI upscaling. It also removes retro-v3's tiny coordinate stretch from the loaded shader to keep grid-line thickness consistent. These corrections apply to all three generations and leave shader selection and parameters under your control; they do not add blur or modify preset files.

Engine 0.3.91 includes **Shader FX** with LCD presets; the separate SilverShadow LCD mod is optional and should be disabled when using a built-in LCD preset.

## Field tools and quality of life

- **No HM move-slot requirement:** owning the appropriate HM lets a healthy party helper perform its field action without teaching it. Badge and native story checks still apply. Gen 1 already supplies contextual Cut/Strength/Surf plus START → HM for Flash/Fly. Gen 2 adds START → HM TOOLS, including Rock Smash when its TM is owned. Gen 3 uses the native tree/rock/water prompts; Flash and destination Fly are in START → SILVERSHADOW → FIELD TOOLS / QOL. RSE scripted field checks, including Dive, use the same HM helper. This never adds moves to a Pokemon.
- **Follower travel stays separate:** a Water type or actual Surf user can swim, and a Flying type or actual Fly user can fly. Teaching those moves to Caterpie works; merely owning the HM does not give Caterpie those travel styles.
- **Portable Pokemon PC:** Gen 1's PC shortcut and Gen 2's BOXES open native Pokemon storage, and Gen 3 has POKEMON PC in SILVERSHADOW. These are not limited to the item PC.
- **Reusable TMs:** Gen 1 retains its existing implementation; Gen 2/3 default on. Successful teaching and move replacement retain the TM. Tossing, giving, PC transfers and ordinary inventory removal remain native.
- **Instant text:** defaults on, with INSTANT TEXT in Battle options. It reveals the current text page while keeping page advances, choices and scripted pauses. Ruby/Sapphire's separate field printer is covered too.
- **DexNav shortcut:** Gen 1 retains overworld SELECT. Gen 2 retains its registerable DEXNAV key item (choose SEL). Gen 3 adds DEXNAV to Key Items; register it normally or use FIELD TOOLS / QOL → REGISTER DEXNAV ON SELECT. Ruby/Sapphire use the item's REGISTER action because SELECT inside their Bag reorders items. Existing registered items are never automatically replaced. The key searches for an uncaught local species; the collection menu provides area, uncaught and all-species pickers.
- **Inventory compatibility:** each generation keeps its native Bag/Pack and item operations. The Gen 1 item editor is separate, Gen 2 keeps its pocket editor, and Gen 3 uses its original Bag artwork. The Gen 1/2 Bag layout is not converted into the Gen 3 inventory implementation.

## Gen 1/2 battle presentation

Battle → **MODERN HUD** defaults on and uses a full 4:3 composition. When an imported FireRed or LeafGreen cache exists, the mod reads its battle backgrounds, HP panels, text windows, fonts, Pokemon sprites, and matching trainer portraits directly at runtime. Those ROM assets are not bundled. Gen 1 uses Red's full Gen 3 back sprite; shared trainer classes and Kanto characters use matching Gen 3 portraits. Johto-only characters, Silver, and DV-specific Unown forms retain their original artwork.

Terrain follows outdoor, water, cave and indoor contexts, with matching Kanto leader/League themes where available. Gen 3 battle backgrounds and their native scenario selection are unchanged.

Both HP bars, numeric player HP, EXP, status, and the wild-only caught Pokeball are displayed. The move grid uses type-colored names, PP, and the native type chart's effectiveness multiplier. Status and special-damage moves are labeled separately. Native battle rules, input, text paging, and animation timing remain in control. Special Gen 2 prompts retain their native layout. Turn MODERN HUD off for the original presentation. Without a compatible imported cache, the mod uses a basic HUD and native sprites.

Yellow's native starter Pikachu retains its original ownership identity, happiness, dialogue and availability checks alongside the additional followers.

### Compatibility validation

The live QoL driver also checks HM ownership and badge gates, the RSE script-command path, Surf/Fly Caterpie travel classification, native DexNav registration and SELECT, TM teaching/replacement/removal, and multipage instant text.

The headless suite loads the packaged mod through the real 0.3.91 loader for Gold, Silver, Crystal and all five Gen 3 profiles. Gen 3 checks cover battle hooks, real HP adapters, ball consumption, link exclusions and flight recovery. Live LÖVE tests with locally supplied ROMs exercise followers, Pokemon control, menus/editors, flight, and an actual double battle in FireRed, LeafGreen, Ruby, Sapphire and Emerald. Blue and Gold are also checked with copied existing saves and the installed PokéPC 0.8.3 provider. Additional live checks cover the modern battle menu, move navigation, type matchups, a battle turn and HUD toggle in all six Gen 1/2 games, plus Yellow starter-Pikachu identity/happiness checks. This is scripted regression coverage, not a complete playthrough of every story and battle animation. No ROM data is included in the mod archive.

The archive has manifest.json, main.lua, modules/, and assets/ at its root. No game ROMs are included. Gen 3 follower artwork and its upstream credits are included under assets/gen3_followers. The manifest retains the GitHub update metadata introduced in 2.0.2.

For Gen 1/2 followers, separately install [burgerslayer7/PokePCFollowers](https://github.com/burgerslayer7/PokePCFollowers). SilverShadow detects its `PokePCFollowers_VoxelMerge` mod ID and uses its public sprite-provider API. Gen 3 uses the separately credited bundled sprite sheets.

## Generation support

- **Gen 1:** All Pokemon Catchable 151, level replacements for the four trade evolutions, native Bag with a separate additive item editor, original Pokemon boxes, DexNav, HM Anywhere, Free Fly, Moves Manager, DV/EV Editor, Battle Move Info, reusable machines, free TM shop, Heal, Summon, display tools, optional 0-6 followers, and the full cheat menu.
- **Gen 2:** All Pokemon Catchable 251 Dex Hunt and a registerable Area DexNav Key Item, single-player alternatives for all trade evolutions, native separated Pack pockets and original Pokemon boxes, Free Fly, Moves Manager, DV/EV Editor, audited healing and movement controls, optional 0-6 followers, and generation-native battle cheats.

The Gen 2 Dex Hunt replaces every 20th ordinary wild encounter by default with a Pokemon the current save has not caught. It uses the active 251-species registry, so it works identically from Gold, Silver, or Crystal without replacing their different maps and time-of-day tables. Bug Contest, scripted, and roaming encounters stay vanilla. The rate can be changed to 1/10 or 1/50, or turned off.

Gold, Silver, and Crystal also receive a permanent **DEXNAV** in the Key Items pocket. Use it directly for an uncaught Pokemon from the current map's current-time land table (or water table while surfing). To assign the native shortcut, highlight DEXNAV, press A, and choose **SEL**; overworld SELECT then uses DexNav exactly like a registered Bicycle or rod. This does not replace the separate automatic Dex Hunt option.

The Gen 2 Pack also has a pocket-aware free item editor. Highlight **CANCEL**
and press **SELECT** in Items, Poke Balls, or TM/HM to open it. The resulting
catalogue is limited to that pocket, excludes HMs and all Key Items, and adds
the chosen quantity through the normal Gen 2 bag-capacity rules.

Gen 2 any-trade evolutions occur at level 42 for Kadabra, Graveler, and Haunter, and level 45 for Machoke. Held-item trade evolutions occur at level 40 while holding the original item, which is consumed. Poliwhirl keeps its Water Stone branch and Slowpoke keeps its level-37 Slowbro branch.

## Options and editors

Normal Options contains one SILVERSHADOW OPEN row. Gen 2 exposes only the audited groups:

- **Battle:** EXP and damage multipliers, OHKO, Infinite HP/PP, Unlimited Balls, Always Hit/Crit/First/Escape, Guaranteed Catch, and No Encounters.
- **Pokemon:** Dex Hunt 251 and its rate, PC Rare Candy, and Max Coins. Pokemon storage uses each game's original box screens.
- **Healing:** Perfect Catch DVs, Heal Catch, Heal After Battle, Heal on Map Change, and Heal Party Now.
- **Movement:** x1.5/x2/x3/x4 with separate foot, bicycle, surf, and Free Fly behavior; adjustable flight height; optional trainer sight; and default-on Story Gate and Badge Check restrictions.
- **Followers:** trainer- or Pokemon-front formations, optional trainer trail, and 0-6 visible Pokemon when the separately installed PokePC provider is present.

In Gold, Silver, and Crystal, a healthy party member that knows FLY receives a **FREEFLY** party action outdoors. `BADGE CHECK` requires the Storm Badge for takeoff and the Fog Badge for a water landing; teaching FLY or SURF with the Move Editor is valid on any species but does not silently disable those progression checks. Press A to land. Flying followers flap over land or water, SURF users swim, Psychic/Ghost followers hover, and an incapable follower hides while the current terrain cannot support it.

Redundant PC Heal and multiple heal-anywhere variants are not included in the Gen 2 menu.

The Moves Manager reads the active game's live move, learnset, evolution, type, and category registries. Gold, Silver, and Crystal therefore include all Gen 2 moves and Gen 2 physical/special rules automatically. Whirlpool and Waterfall receive HM protection along with the Gen 1 HMs. The DV/EV Editor uses Gen 2's split Special Attack and Special Defense stat calculation while preserving the shared Special DV and Stat Experience used by those games.

On high-DPI Android devices, Gen 2 survey zoom uses physical-pixel steps so
OUT1 matches Gen 1 instead of jumping twice as far. L2 and R2 analog trigger
axes are also exposed to the Controls screen as bindable L2/R2 buttons.

Gen 1 retains its native Bag and PC deposit/withdraw screens. The free item editor is separate: Options → SilverShadow → Supplies → EDIT BAG ITEMS, or EDIT BAG ITEMS in the PC menu. Existing quantities and expanded capacities are preserved. Extended player-owned levels, Free Fly, DexNav, and field tools remain available. The custom box grid, box healing, and box cursor settings are retired; PC and Start-menu shortcuts open the original engine box screens. Cheats remain inert during link play in both generations.

## Compatibility and safety

- **Link/PvP:** gameplay cheats are disabled during link battles and sessions. affects_link remains false.
- **Standalone Free Fly:** do not enable it alongside SilverShadow. SilverShadow now contains generation-native Free Fly implementations for all three generations.
- **Dramatic Shape:** remains an optional Gen 1 integration for compatible display and input behavior.
- **SilverShadow Touchpad:** virtual SELECT uses the normal input path and reaches SilverShadow menus and Gen 1 DexNav.
- **Gen 1/2 followers:** optional. Install the burgerslayer7 PokePCFollowers fork separately; it supplies all 251 six-frame sheets while SilverShadow supplies formation and travel controls. Missing or disabled PokePC leaves the Gen 1/2 follower menu hidden and does not affect other features. Gen 3 followers work without this provider.

No PokePC code, Stadium models, Dramatic Shape assets, or game ROMs are bundled. See the third-party notices for the Gen 3 follower artwork.

## Development

Runtime files are selected by runtime-files.txt and packaged with python tools/package.py. Run the headless Lua suites against the matching current Gen1Recomp engine before publishing a release. The engine driver scripts in tests/engine_* run with POKEPORT_DRIVER against locally imported ROM caches and private test saves; they contain no ROM payloads. Set SILVERSHADOW_SHOTS to an existing screenshot directory for the visual drivers.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for references and license attribution.

## Disclaimer

This unofficial community mod is not affiliated with or endorsed by Nintendo, The Pokemon Company, Game Freak, or the Gen1Recomp developers.

### Battle and menu presentation in 3.1.2

Gen 1/2 modern battles and Gen 3 4:3 battles use a 256×192 logical canvas (exactly 5× on the 1280×960 Nova). Gen 2 Party/Pack panels reflow to that canvas; Gen 3 Party/Bag backgrounds extend their own background artwork while retaining native font, icon and control sizes. Other screens keep their authored layouts. The Gen 2 shader receives the actual active layout scale, preventing a 6× LCD grid from resampling 5× battle artwork.

Gen 3 **MOVE TYPE INFO** adds colored move labels and a read-only type matchup. It is a type preview, not a damage prediction. Double battles follow the selected opponent; mixed spread matchups show VARIES. Native scenario backgrounds, battle rules and trainer-catching restrictions are preserved.

### Title pixels and move-editor colors in 3.1.3

Gen 1 boot/title art uses a whole physical-pixel scale when retro-v3 is selected. This prevents the rounded LCD sampling grid from discarding thin strokes in the Red/Blue version ribbon. The original Red/Blue cinematic bars extend across the surround, using the original palette and fade. Yellow retains its own intro and title artwork.

All three generations use one shared type palette for battle move names and move-editor lists. Known/eligible moves, full categorized lists and type labels are colored; PP, controls and unrelated text keep their normal colors. Gen 1/2 recolor the native glyph ink without replacing the font. Gen 3 uses its native list foreground-color support. Move eligibility, teaching and stats are unchanged.

### Follower transitions in 3.1.4

Door warps gather the group at your arrival tile; followers then fan out along your actual steps. Connected routes retain the existing trail and animation progress across all three generations. Yellow keeps its native special Pikachu. Surf/Fly eligibility and follower artwork remain governed by the existing travel rules.

Validation: the ROM-free transition regression plus all version integration suites pass. Device checks on engine 0.3.91 covered Blue and Yellow at Pallet/Route 1, Crystal at New Bark/Route 29, and FireRed/Emerald north connections. Blue’s house entry/exit was also inspected visually. These checks do not claim exhaustive coverage of every map or scripted warp.
