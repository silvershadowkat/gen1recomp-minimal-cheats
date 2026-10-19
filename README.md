# SilverShadow Mods

SilverShadow Mods supports all eleven Gen 1–3 games in [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire, and Emerald. Version 3.1.0 targets engine 0.3.91 and keeps the internal mod ID minimal_cheats, preserving existing settings.

The entry point selects a generation-safe module set at runtime. Red, Blue, and Yellow retain the compatible original suite. Gold, Silver, and Crystal use the generation-native battle, editor, movement, healing, and catch/evolution implementations. The engine's original Pokemon boxes are preserved in both generations.

## Install

Download silvershadow-mods-v3.1.0.zip from Releases and choose **Import mod .zip** in Gen1Recomp. Alternatively, copy the extracted silvershadow_mods folder into Gen1Recomp's mods directory. Do not use GitHub's automatically generated source archive.

## Gen 3

Open **START → SILVERSHADOW**. Gen 3 uses native menus and data structures, independently of the older modules.

- **Battle:** EXP and damage multipliers, OHKO, infinite HP/PP, unlimited balls, always hit/critical/first/escape, guaranteed catch, and no random encounters. Both allied slots in double battles are handled. Link battles bypass gameplay cheats; normal game restrictions outside a hook (such as trainer capture restrictions) remain.
- **Healing/items:** heal now, heal after battles/map changes/catches, perfect-IV catches, 99 Rare Candies, max money/coins, and perfect party IVs.
- **Party editor:** level, individual IVs, EVs (510 total cap), and all 354 move choices for each slot. The move editor can replace HMs.
- **Summon:** all 386 National Dex species at level 25, using the game's party/PC placement. **Items/TMs** fills a chosen non-key item to 99, subject to native bag limits. **Pokemon PC** opens native storage anywhere.
- **Followers:** 0–6 healthy party followers, including Hoenn species and shiny art. Pokemon mode replaces the trainer's visual with the first healthy party Pokemon; an optional trainer trails behind. These sprites are bundled, so Gen 3 needs no PokéPC provider. Keep your existing PokéPC provider enabled only for Gen 1/2.
- **Free Fly:** take off/land from the movement menu; move over obstacles within the current map. Landing requires clear ground. RETURN TO GROUND restores the takeoff location. Saving is blocked while airborne. Crossing map boundaries, the older badge/story-gate options, and Gen 1/2 DexNav/evolution/extended-level features are not ported to Gen 3. Gen 3 levels remain capped at 100.

L/R page through long catalogues. Battle cheats default off; follower count defaults to one. Settings remain scoped by the engine's mod-save system.

Engine 0.3.91 includes **Shader FX** with LCD presets; the separate SilverShadow LCD mod is optional and should be disabled when using a built-in LCD preset.

### Compatibility validation

The headless suite loads the packaged mod through the real 0.3.91 loader for Gold, Silver, Crystal and all five Gen 3 profiles. Gen 3 checks cover battle hooks, real HP adapters, ball consumption, link exclusions and flight recovery. Live LÖVE tests with locally supplied ROMs exercise followers, Pokemon control, menus/editors, flight, and an actual double battle in FireRed, LeafGreen, Ruby, Sapphire and Emerald. Blue and Gold are also checked with copied existing saves and the installed PokéPC 0.8.3 provider. No ROM data is included in the mod archive.

The archive has manifest.json, main.lua, modules/, and assets/ at its root. No game ROMs are included. Gen 3 follower artwork and its upstream credits are included under assets/gen3_followers. The manifest retains the GitHub update metadata introduced in 2.0.2.

For Gen 1/2 followers, separately install [burgerslayer7/PokePCFollowers](https://github.com/burgerslayer7/PokePCFollowers). SilverShadow detects its `PokePCFollowers_VoxelMerge` mod ID and uses its public sprite-provider API. Gen 3 uses the separately credited bundled sprite sheets.

## Generation support

- **Gen 1:** All Pokemon Catchable 151, level replacements for the four trade evolutions, Useful Bag with separated pockets, original Pokemon boxes, DexNav, HM Anywhere, Free Fly, Moves Manager, DV/EV Editor, Battle Move Info, reusable machines, free TM shop, Heal, Summon, display tools, optional 0-6 followers, and the full cheat menu.
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

Gen 1 keeps its Useful Bag catalogue and separated pockets, editable PC items, extended player-owned levels, Free Fly, DexNav, and field tools. The custom box grid, box healing, and box cursor settings are retired; PC and Start-menu shortcuts open the original engine box screens. Cheats remain inert during link play in both generations.

## Compatibility and safety

- **Link/PvP:** gameplay cheats are disabled during link battles and sessions. affects_link remains false.
- **Standalone Free Fly:** do not enable it alongside SilverShadow. SilverShadow now contains generation-native Free Fly implementations for both Gen 1 and Gen 2.
- **Dramatic Shape:** remains an optional Gen 1 integration for compatible display and input behavior.
- **SilverShadow Touchpad:** virtual SELECT uses the normal input path and reaches SilverShadow menus and Gen 1 DexNav.
- **Gen 1/2 followers:** optional. Install the burgerslayer7 PokePCFollowers fork separately; it supplies all 251 six-frame sheets while SilverShadow supplies formation and travel controls. Missing or disabled PokePC leaves the Gen 1/2 follower menu hidden and does not affect other features. Gen 3 followers work without this provider.

No PokePC code, Stadium models, Dramatic Shape assets, or game ROMs are bundled. See the third-party notices for the Gen 3 follower artwork.

## Development

Runtime files are selected by runtime-files.txt and packaged with python tools/package.py. Run the headless Lua suites against the matching current Gen1Recomp engine before publishing a release.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for references and license attribution.

## Disclaimer

This unofficial community mod is not affiliated with or endorsed by Nintendo, The Pokemon Company, Game Freak, or the Gen1Recomp developers.
