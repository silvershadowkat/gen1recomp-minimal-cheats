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
assert(run.loader.exports.minimal_cheats.silvershadow.version == "2.0.1",
  "wrong runtime export version")
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
if withPokePC then
  assert(run.loader.mods.PokePCFollowers_VoxelMerge,
    "PokePC Followers optional dependency was not discovered")
  assert(run.loader.exports.minimal_cheats.followersIntegration.available(),
    "SilverShadow did not expose the optional Followers menu integration")
  assert(type(run.loader.exports.minimal_cheats.setControlMode) == "function"
    and type(run.loader.exports.minimal_cheats.setFollowerCount) == "function",
    "SilverShadow follower control/trailer API was not installed")
else
  assert(not run.loader.exports.minimal_cheats.followersIntegration.available(),
    "Followers integration should stay hidden when PokePC is absent")
end
run.release()
print("SilverShadow packaged Mod API loader test"
  .. (withPokePC and " with PokePC detection" or "") .. ": passed")
