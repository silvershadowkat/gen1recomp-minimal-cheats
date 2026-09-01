# SilverShadow Mods

SilverShadow Mods is one gameplay and quality-of-life mod for all six games supported by [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): Red, Blue, Yellow, Gold, Silver, and Crystal. It keeps the internal mod ID minimal_cheats, so existing settings remain attached when upgrading to 3.x.

The entry point selects a generation-safe module set at runtime. Red, Blue, and Yellow retain the compatible original suite. Gold, Silver, and Crystal use the generation-native battle, editor, movement, healing, and catch/evolution implementations. The engine's original Pokemon boxes are preserved in both generations.

## Install

Download silvershadow-mods-v3.0.17.zip from Releases and choose **Import mod .zip** in Gen1Recomp. Alternatively, copy the extracted silvershadow_mods folder into Gen1Recomp's mods directory. Do not use GitHub's automatically generated source archive.

The archive has manifest.json, main.lua, and modules/ at its root. It contains no ROM data or Pokemon artwork. The manifest retains the GitHub update metadata introduced in 2.0.2.

For followers, separately install [burgerslayer7/PokePCFollowers](https://github.com/burgerslayer7/PokePCFollowers). SilverShadow detects its `PokePCFollowers_VoxelMerge` mod ID and uses its public sprite-provider API; no PokePC code or artwork is copied into the SilverShadow archive.

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
- **Followers:** optional. Install the burgerslayer7 PokePCFollowers fork separately; it supplies all 251 six-frame sheets while SilverShadow supplies formation and travel controls. Missing or disabled PokePC leaves the follower menu hidden and does not affect other features.

No PokePC, Stadium, follower, Dramatic Shape, or ROM-derived assets are bundled.

## Development

Runtime files are selected by runtime-files.txt and packaged with python tools/package.py. Run the headless Lua suites against the matching current Gen1Recomp engine before publishing a release.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for references and license attribution.

## Disclaimer

This unofficial community mod is not affiliated with or endorsed by Nintendo, The Pokemon Company, Game Freak, or the Gen1Recomp developers.
