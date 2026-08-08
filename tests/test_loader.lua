package.path = "references/gen1recomp/?.lua;references/gen1recomp/?/init.lua;" .. package.path

require("src.core.Version").engine = "0.1.75"
require("src.core.GameVersion").set("blue")
local fixtures = require("tests.modkit.fixtures")
local sdk = require("tests.modkit.sdk")
local data = fixtures.fresh()
local withPokePC = os.getenv("SILVERSHADOW_WITH_POKEPC") == "1"
if withPokePC then
  love = require("tests.love_stub")
  -- The control layer only probes this externally-owned sheet at install
  -- time. Runtime sheets remain in PokePC; SilverShadow packages none.
  love.filesystem.write(
    "mods/PokePCFollowers_VoxelMerge/assets/sprites/follower_CHARMANDER.png",
    "external-test-asset")
end

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[clone(key)] = clone(child) end
  return out
end

-- The ROM-free fixture deliberately has only FIXMON_A/B/C. Seed schema-valid
-- stand-ins for species referenced by the All-151 patch so the merge test can
-- distinguish a broken module from the fixture's intentionally tiny catalog.
local source = assert(io.open("modules/content_151.lua", "rb")):read("*a")
local template = assert(data.pokemon.FIXMON_A)
local ids = {}
for id in source:gmatch('species%s*=%s*"([A-Z0-9_]+)"') do ids[id] = true end
for id in source:gmatch('pokemon:patch%(%s*"([A-Z0-9_]+)"') do ids[id] = true end
for id in pairs(ids) do
  if not data.pokemon[id] then
    data.pokemon[id] = clone(template)
    data.pokemon[id].id = id
    data.pokemon[id].name = id
    data.pokemon[id].evolutions = {}
  end
end

local path = os.getenv("SILVERSHADOW_TEST_MOD") or "dist/silvershadow_mods"
local run
if withPokePC then
  run = sdk.loadMods({ "references/pokepc-followers", path },
    { data = data, root = ".", dev = true })
else
  run = sdk.loadMod(path, { data = data, root = ".", dev = true })
end
assert(run.loader.mods.minimal_cheats, "SilverShadow was not discovered")
assert(#run.errors == 0, "loader errors: " .. table.concat(run.errors, "; "))
assert(run.loader.exports.minimal_cheats, "SilverShadow exports were not published")
assert(run.loader.exports.minimal_cheats.silvershadow.version == "2.0.5",
  "wrong runtime export version")
assert(run.loader.mods.minimal_cheats.manifest.github
    == "silvershadowkat/gen1recomp-minimal-cheats",
  "GitHub update repository metadata was not loaded")
assert(run.data.constants.bagSize == 999, "distinct bag-type capacity was not merged")
assert(run.data.field.pcItemCap == 999, "PC item-stack capacity was not merged")
assert(run.data.pokemon.KADABRA.evolutions[1].species == "ALAKAZAM"
  and run.data.pokemon.KADABRA.evolutions[1].level == 42,
  "All-151 impossible evolution patch was not merged")
assert(run.data.encounters.VIRIDIAN_FOREST
  and #run.data.encounters.VIRIDIAN_FOREST.grass.slots == 10,
  "All-151 encounter patch was not merged")
assert(run.loader.exports.minimal_cheats.boxScreen,
  "Gen 3 box screen was not exported")
assert(run.loader.exports.minimal_cheats.usefulBag.perItemCap == 99,
  "normal per-item quantity cap changed")
assert(type(run.loader.exports.minimal_cheats.freeFly) == "table"
    and type(run.loader.exports.minimal_cheats.freeFly.isFlying) == "function",
  "SilverShadow Free Fly API was not packaged")
if withPokePC then
  assert(run.loader.mods.PokePCFollowers_VoxelMerge,
    "PokePC Followers optional dependency was not discovered")
  assert(run.loader.exports.minimal_cheats.followersIntegration.available(),
    "SilverShadow did not expose the optional Followers menu integration")
  assert(type(run.loader.exports.minimal_cheats.setControlMode) == "function"
    and type(run.loader.exports.minimal_cheats.setFollowerCount) == "function",
    "SilverShadow follower control/trailer API was not installed")
  assert(run.loader.exports.minimal_cheats.freeFlyAware == true,
    "SilverShadow followers did not claim ownership of airborne formations")
  local appearanceDirty =
    run.loader.exports.minimal_cheats._trailerCompositionDirty
  assert(type(appearanceDirty) == "function",
    "SilverShadow follower appearance refresh check was not installed")
  local evolved = { species = "KAKUNA", dvs = {} }
  assert(appearanceDirty({ {
    pokepcTrailerKind = "mon", pokepcMon = evolved,
    pokepcSpecies = "WEEDLE", pokepcShiny = false,
  } }, { { kind = "mon", mon = evolved } }),
    "an in-place evolution must invalidate the old follower sprite")
  assert(not appearanceDirty({ {
    pokepcTrailerKind = "mon", pokepcMon = evolved,
    pokepcSpecies = "KAKUNA", pokepcShiny = false,
  } }, { { kind = "mon", mon = evolved } }),
    "an unchanged follower appearance must keep its existing NPC")
  assert(appearanceDirty({ {
    pokepcTrailerKind = "mon", pokepcMon = evolved,
    pokepcSpecies = "KAKUNA", pokepcShiny = false,
  } }, { { kind = "mon", mon = evolved, travelStyle = "hover" } }),
    "entering a travel formation must rebuild the follower pose")
  assert(not appearanceDirty({ {
    pokepcTrailerKind = "mon", pokepcMon = evolved,
    pokepcSpecies = "KAKUNA", pokepcShiny = false,
    pokepcTravelStyle = "hover",
  } }, { { kind = "mon", mon = evolved, travelStyle = "hover" } }),
    "an unchanged travel formation must keep its follower NPC")
  local travelFormation = run.loader.exports.minimal_cheats._travelFormation
  assert(type(travelFormation) == "function",
    "travel-aware follower formation planner was not installed")
  local mount = { species = "PIDGEY", level = 10, hp = 20 }
  local grounded = { species = "CATERPIE", level = 5, hp = 10 }
  local flyer = { species = "BUTTERFREE", level = 12, hp = 25 }
  local swimmer = { species = "SQUIRTLE", level = 12, hp = 25 }
  local travelGame = { save = { pokepcFollowerCount = 2,
      inventory = { HM03 = 1 } }, data = {
    items = { HM03 = { machine = { kind = "HM", move = "SURF" } } },
    pokemon = {
      PIDGEY = { types = { "NORMAL", "FLYING" } },
      CATERPIE = { types = { "BUG" } },
      BUTTERFREE = { types = { "BUG", "FLYING" } },
      SQUIRTLE = { types = { "WATER" } },
    },
  } }
  local travelOw = { player = { freeFlying = true,
      silverTravelMount = mount },
    map = { isWaterCell = function() return true end } }
  local candidates = {
    { kind = "mon", mon = mount }, { kind = "mon", mon = grounded },
    { kind = "mon", mon = flyer }, { kind = "mon", mon = swimmer },
  }
  local formation = travelFormation(travelGame, travelOw, candidates, "follow")
  assert(#formation == 1 and formation[1].mon == flyer
      and formation[1].travelStyle == "air",
    "trainer-front count reserves one visible slot for the main mount")
  formation = travelFormation(travelGame, travelOw, candidates, "pack")
  assert(#formation == 2 and formation[1].mon == flyer
      and formation[2].mon == swimmer
      and formation[2].travelStyle == "surf",
    "travel formation skips ground-only members and fills later safe slots")
else
  assert(not run.loader.exports.minimal_cheats.followersIntegration.available(),
    "Followers integration should stay hidden when PokePC is absent")
end
run.release()
print("SilverShadow packaged Mod API loader test"
  .. (withPokePC and " with PokePC detection" or "") .. ": passed")
