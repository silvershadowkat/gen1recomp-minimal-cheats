local engineRoot = os.getenv("SILVERSHADOW_ENGINE") or "../engine"
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. package.path

-- Lupa's Lua 5.5 build has native bitwise operators but no legacy bit/bit32
-- table. The engine test SDK's streaming MD5 accepts either surface.
if not rawget(_G, "bit") and not rawget(_G, "bit32") then
  bit32 = assert(load([[
    local MASK = 0xffffffff
    local function fold(op, a, ...)
      local value = a or 0
      for i = 1, select('#', ...) do value = op(value, select(i, ...)) end
      return value & MASK
    end
    return {
      band = function(a, ...) return fold(function(x,y) return x & y end, a, ...) end,
      bor = function(a, ...) return fold(function(x,y) return x | y end, a, ...) end,
      bxor = function(a, ...) return fold(function(x,y) return x ~ y end, a, ...) end,
      bnot = function(a) return (~a) & MASK end,
      lshift = function(a, n) return (a << n) & MASK end,
      rshift = function(a, n) return (a & MASK) >> n end,
      lrotate = function(a, n)
        a, n = a & MASK, n % 32
        return ((a << n) | (a >> (32 - n))) & MASK
      end,
    }
  ]]))()
  package.preload["bit"] = function() return bit32 end
end

require("src.core.Version").engine = "0.3.91"
local GameVersion = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Evolution2 = require("src.core.gen2.Evolution")
local fixtures = require("tests.modkit.fixtures")
local sdk = require("tests.modkit.sdk")

local modPath = os.getenv("SILVERSHADOW_TEST_MOD") or "dist/silvershadow_mods"
local providerPath = "tests/fixtures/pokepc-provider"
local gen2Version = os.getenv("SILVERSHADOW_GEN2_VERSION") or "gold"

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[clone(key)] = clone(child) end
  return out
end

local function readAll(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end

local function contains(rows, wanted)
  for _, value in ipairs(rows or {}) do
    if value == wanted then return true end
  end
  return false
end

local function loadGen1()
  GameVersion.set("blue")
  local data = fixtures.fresh()

  -- The ROM-free fixture deliberately has only FIXMON_A/B/C. Seed schema-valid
  -- stand-ins for species referenced by the curated All-151 module.
  local source = readAll("modules/content_151.lua")
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

  local run = sdk.loadMod(modPath, {
    data = data, root = ".", dev = true, generation = 1,
  })
  assert(run.loader.mods.minimal_cheats, "SilverShadow Gen 1 was not discovered")
  assert(#run.errors == 0, "Gen 1 loader errors: " .. table.concat(run.errors, "; "))
  local exports = assert(run.loader.exports.minimal_cheats,
    "SilverShadow Gen 1 exports were not published")
  assert(exports.silvershadow.version == "3.2.0", "wrong Gen 1 runtime version")
  assert(run.loader.mods.minimal_cheats.manifest.github
      == "silvershadowkat/gen1recomp-minimal-cheats",
    "GitHub update repository metadata was not loaded")
  assert(run.data.constants.bagSize == 999, "distinct bag capacity was not merged")
  assert(run.data.field.pcItemCap == 999, "PC item capacity was not merged")
  assert(run.data.pokemon.KADABRA.evolutions[1].species == "ALAKAZAM"
      and run.data.pokemon.KADABRA.evolutions[1].level == 42,
    "All-151 impossible evolution patch was not merged")
  assert(run.data.encounters.VIRIDIAN_FOREST
      and #run.data.encounters.VIRIDIAN_FOREST.grass.slots == 10,
    "All-151 encounter patch was not merged")
  assert(not exports.boxScreen, "retired custom box screen was exported")
  assert(run.data.screens.Gen3Box == nil,
    "retired custom box screen was registered in Gen 1")
  assert(exports.usefulBag.perItemCap == 99, "normal item cap changed")
  assert(exports.followersIntegration
      and not exports.followersIntegration.available(),
    "follower integration should remain optional when PokePC is absent")
  run.release()
end

local function seedGen2()
  local data = fixtures.fresh()
  data.pokemon.growthRates = {
    MEDIUM_FAST = { id = "MEDIUM_FAST", numerator = 1, denominator = 1,
      squared = 0, linear = 0, constant = 0 },
  }
  local template = assert(data.pokemon.FIXMON_A)
  local species = {
    "KADABRA", "ALAKAZAM", "GRAVELER", "GOLEM", "HAUNTER", "GENGAR",
    "MACHOKE", "MACHAMP", "POLIWHIRL", "POLIWRATH", "POLITOED",
    "SLOWPOKE", "SLOWBRO", "SLOWKING", "ONIX", "STEELIX",
    "SCYTHER", "SCIZOR", "SEADRA", "KINGDRA", "PORYGON", "PORYGON2",
  }
  for dex, id in ipairs(species) do
    local def = clone(template)
    def.id, def.name, def.dex, def.index = id, id, dex, dex
    def.evolutions, def.levelMoves, def.level1Moves = {}, {}, nil
    def.types = { "NORMAL" }
    def.growthRate = "MEDIUM_FAST"
    data.pokemon[id] = def
  end

  local itemTemplate = assert(data.items.FIX_POTION)
  for _, id in ipairs({
    "WATER_STONE", "KINGS_ROCK", "METAL_COAT", "DRAGON_SCALE", "UP_GRADE",
  }) do
    local item = clone(itemTemplate)
    item.id, item.name = id, id
    data.items[id] = item
  end
  local function item(id, pocket, index, extra)
    local def = clone(itemTemplate)
    def.id, def.name, def.pocket, def.index = id, id, pocket, index
    for key, value in pairs(extra or {}) do def[key] = value end
    data.items[id] = def
  end
  item("POKE_BALL", "BALL", 5)
  item("GREAT_BALL", "BALL", 4)
  item("ULTRA_BALL", "BALL", 3)
  item("MASTER_BALL", "BALL", 1)
  item("POTION", "ITEM", 20)
  item("SUPER_POTION", "ITEM", 19)
  item("HYPER_POTION", "ITEM", 18)
  item("TM_DYNAMICPUNCH", "TM_HM", 100, {
    tmNumber = 1, tmLabel = "TM01", teaches = "FIX_MOVE",
  })
  item("HM_CUT", "TM_HM", 200, {
    tmLabel = "HM01", teaches = "FIX_MOVE",
  })
  item("BICYCLE", "KEY_ITEM", 6)
  return data
end

local function loadGen2()
  GameVersion.set(gen2Version)
  local data = seedGen2()
  local run = sdk.loadMods({ providerPath, modPath }, {
    data = data, root = ".", dev = true, generation = 2,
  })
  assert(run.loader.mods.minimal_cheats, "SilverShadow Gen 2 was not discovered")
  assert(run.loader.mods.PokePCFollowers_VoxelMerge,
    "PokePC provider fixture was not discovered")
  assert(#run.errors == 0, "Gen 2 loader errors: " .. table.concat(run.errors, "; "))

  local exports = assert(run.loader.exports.minimal_cheats,
    "SilverShadow Gen 2 exports were not published")
  local shared = assert(exports.silvershadow)
  assert(shared.version == "3.2.0" and shared.generation == 2,
    "wrong Gen 2 runtime branch")
  local freeFly = assert(exports.freeFly,
    "Gen 2 Free Fly API was not exported")
  assert(freeFly.generation == 2 and type(freeFly.classify) == "function"
      and type(freeFly._start) == "function"
      and type(freeFly._tick) == "function",
    "Gen 2 Free Fly did not expose its isolated controller")

  local flyMon = { species = "FIXMON_A", hp = 20, moves = { { id = "FLY" } } }
  local surfMon = { species = "FIXMON_B", hp = 20, moves = { { id = "SURF" } } }
  local groundMon = { species = "FIXMON_C", hp = 20, moves = {} }
  run.data.pokemon.FIXMON_A.types = { "NORMAL" }
  run.data.pokemon.FIXMON_B.types = { "WATER" }
  run.data.pokemon.FIXMON_C.types = { "NORMAL" }
  assert(freeFly.classify({ data = run.data }, flyMon, "fly", true, false)
      == "air", "move-editor FLY knowledge was not authoritative")
  assert(freeFly.classify({ data = run.data }, surfMon, "surf", true, false)
      == "surf", "SURF follower was not classified as a swimmer")
  assert(freeFly.classify({ data = run.data }, flyMon, "surf", true, false)
      == "air", "Flying follower did not overfly water")
  assert(freeFly.classify({ data = run.data }, groundMon, "fly", true, false)
      == nil, "ground-only follower remained over water")
  assert(freeFly.classify({ data = run.data }, groundMon, "fly", false, true)
      == "ground", "ground follower disappeared over legal land")

  shared.set("fly_badge_checks", true)
  local flightPlayer = { cellX = 5, cellY = 5, px = 80, py = 80,
    facing = "down", moving = false }
  local collision = 0
  local flightMap = {
    id = "FIX_ROUTE", def = { environment = "ROUTE" },
    cellCollision = function() return collision end,
    isWalkableCell = function() return collision == 0 end,
  }
  local flightWorld = {
    player = flightPlayer, map = flightMap, entities = { flightPlayer },
    npcs = {}, playerState = "normal",
    busy = function() return false end,
    applyPlayerState = function(self, value) self.playerState = value end,
    setMapMusic = function() end,
    showText = function(self, value) self.lastText = value end,
  }
  local flightGame = {
    data = run.data, world = flightWorld,
    save = { party = { flyMon, surfMon }, player = { badges = {} } },
  }
  flightWorld.game = flightGame
  shared.game = flightGame
  assert(not freeFly._badgeAllowed(flightGame, "FLY"),
    "BADGE CHECK did not require the Storm Badge")

  -- The row stays visible and gives the native refusal instead of vanishing
  -- when the badge gate is active.
  local flyDecorator
  for _, entry in ipairs(shared.partyDecorators) do
    if entry.id == "gen2_free_fly" then flyDecorator = entry.decorate break end
  end
  local flyRows = assert(flyDecorator)(flightGame, {}, flyMon,
    { battle = false, overworld = flightWorld })
  assert(flyRows[1] and flyRows[1].label == "FREEFLY",
    "badge-gated FREEFLY row was hidden")
  flyRows[1].onSelect(flyMon, flightGame)
  assert(flightWorld.lastText ~= nil and not freeFly.isFlying(),
    "badge-gated FREEFLY did not show a refusal")

  -- BADGE CHECK is shared by native menu and contextual field-move paths,
  -- including every badge-gated Gen 2 HM rather than only Free Fly.
  local FieldMoves = require("src.world.gen2.FieldMoves")
  local surfCtx = {
    save = flightGame.save, mon = surfMon, environment = "ROUTE",
    playerState = "normal", alwaysOnBike = false,
    facing = "down", facingColl = 0x20, playerColl = 0,
  }
  assert(not FieldMoves.flyFromMenu({ save = flightGame.save,
      environment = "ROUTE" }).ok,
    "native FLY ignored BADGE CHECK while enabled")
  assert(not FieldMoves.surfFromMenu(surfCtx).ok,
    "native SURF ignored BADGE CHECK while enabled")
  shared.set("fly_badge_checks", false)
  assert(FieldMoves.flyFromMenu({ save = flightGame.save,
      environment = "ROUTE" }).ok,
    "native FLY remained badge-locked with BADGE CHECK off")
  assert(FieldMoves.surfFromMenu(surfCtx).ok,
    "native SURF remained badge-locked with BADGE CHECK off")
  local surfOwCtx = {
    save = flightGame.save, data = run.data,
    party = { flyMon, surfMon }, playerState = "normal",
    alwaysOnBike = false, facing = "down",
    facingColl = 0x20, playerColl = 0,
  }
  assert(FieldMoves.trySurfOW(surfOwCtx).ok,
    "contextual shoreline SURF remained badge-locked with BADGE CHECK off")
  for _, badge in pairs(FieldMoves.BADGE) do
    assert(FieldMoves.hasBadge(flightGame.save, badge),
      "BADGE CHECK off did not bypass " .. tostring(badge))
  end
  shared.set("fly_badge_checks", true)
  flightGame.save.player.badges.STORM = true
  assert(freeFly._badgeAllowed(flightGame, "FLY"),
    "Storm Badge did not unlock Free Fly")
  flightWorld.playerState = "bike"
  assert(not freeFly._start(flightGame, flyMon),
    "Gen 2 Free Fly started without dismounting the Bicycle")
  flightWorld.playerState = "normal"
  assert(freeFly._start(flightGame, flyMon) and flightPlayer.freeFlying,
    "edited FLY user could not start Gen 2 Free Fly")
  assert(require("src.world.gen2.World").playerCollision(flightWorld) == 0,
    "Free Fly did not neutralize forced terrain under the player")
  assert(Runtime.call("movement.collision", function(value) return value end,
      false, { mover = flightPlayer, reason = "tile", toX = 6, toY = 5 }),
    "Free Fly did not bypass scenery collision")
  flightWorld.entities[2] = {
    cellX = 6, cellY = 5, def = { trainer = { class = 1, member = 1 } },
  }
  assert(Runtime.call("movement.collision", function(value) return value end,
      false, { mover = flightPlayer, reason = "entity", toX = 6, toY = 5 }),
    "Free Fly could not pass a trainer with STORY GATES on")
  flightWorld.entities[2] = { cellX = 6, cellY = 5, def = {} }
  assert(not Runtime.call("movement.collision", function(value) return value end,
      false, { mover = flightPlayer, reason = "entity", toX = 6, toY = 5 }),
    "STORY GATES did not retain a non-trainer guard")
  flightWorld.entities[2] = nil
  freeFly._state.phase, freeFly._state.altitude = "flying", 0
  require("src.world.gen2.World").interact(flightWorld)
  for _ = 1, 120 do
    freeFly._tick(flightWorld, 1 / 60)
    if not flightPlayer.freeFlying then break end
  end
  assert(not flightPlayer.freeFlying and flightWorld.playerState == "normal",
    "Free Fly did not land safely on a walkable tile: "
      .. tostring(freeFly._state.phase) .. "/" .. tostring(freeFly._state.altitude)
      .. "/" .. tostring(flightPlayer.freeFlying)
      .. "/" .. tostring(flightWorld.playerState))

  collision = 0x20
  flightGame.save.player.badges.FOG = nil
  assert(freeFly._landingKind(flightGame, flightWorld) == nil,
    "water landing ignored the Fog Badge")
  flightGame.save.player.badges.FOG = true
  assert(freeFly._start(flightGame, flyMon),
    "Free Fly could not restart for water-landing coverage")
  assert(freeFly._landingKind(flightGame, flightWorld) == "water",
    "SURF knowledge did not make water a legal landing")
  freeFly._state.phase, freeFly._state.altitude = "landing", 0
  freeFly._tick(flightWorld, 1 / 60)
  assert(flightWorld.playerState == "surf" and flightPlayer.surfing,
    "water landing did not enter Gen 2's native Surf state")
  assert(freeFly.surfMount(flightWorld) == surfMon
      and flightPlayer.silverSurfMount == surfMon,
    "water landing did not retain the actual SURF Pokemon as its mount")
  collision = 0
  flightWorld:applyPlayerState("normal")
  flightPlayer.surfing = false
  flightPlayer.silverSurfMount = nil

  local movementScreen = assert(run.data.screens.SilverShadowGen2Movement,
    "Gen 2 Movement options screen was not registered")
  local movementMenu = movementScreen.new({ input = {} })
  local movementLabels = {}
  for _, row in ipairs(movementMenu.items or {}) do movementLabels[row.label] = true end
  for _, label in ipairs({ "FLY BOOST", "FLY HEIGHT", "TRAINER SIGHT",
      "STORY GATES", "BADGE CHECK" }) do
    assert(movementLabels[label], "Gen 2 Movement is missing " .. label)
  end
  local partyScroll = assert(exports.gen2PartyScroll,
    "Gen 2 scrolling Pokemon submenu was not installed")
  local oversized = { items = {}, index = 1 }
  for i = 1, 10 do oversized.items[i] = { label = "ROW" .. i } end
  assert(partyScroll.visibleRows == 6 and partyScroll.syncWindow(oversized) == 1,
    "Gen 2 submenu did not start at its first six rows")
  oversized.index = 10
  assert(partyScroll.syncWindow(oversized) == 5,
    "Gen 2 submenu did not scroll to its last row")
  assert(exports.followersIntegration.available(),
    "installed PokePC provider was not detected")
  assert(type(exports.followersIntegration.activate) == "function",
    "deferred follower activation seam was not exported")
  local editor = assert(exports.gen2ItemEditor,
    "Gen 2 pocket item editor was not exported")
  local balls = editor.catalogue({ data = run.data }, "BALL")
  assert(balls[1].id == "POKE_BALL" and balls[2].id == "GREAT_BALL"
      and balls[3].id == "ULTRA_BALL" and balls[4].id == "MASTER_BALL",
    "Gen 2 Ball stock is not ordered weakest to strongest")
  local tms = editor.catalogue({ data = run.data }, "TM_HM")
  assert(#tms == 1 and tms[1].id == "TM_DYNAMICPUNCH",
    "Gen 2 TM stock included an HM")
  assert(#editor.catalogue({ data = run.data }, "KEY_ITEM") == 0,
    "Gen 2 editor exposed Key Items")
  local PackMenu = require("src.ui.gen2.PackMenu")
  local fakePack = setmetatable({ rows = {}, index = 1, pocketIndex = 1 }, PackMenu)
  assert(fakePack:description() == "SEL: Add Item",
    "Gen 2 Items CANCEL row lacks its editor hint")
  fakePack.pocketIndex = 3
  assert(fakePack:description() == nil,
    "Gen 2 Key Items CANCEL row exposed the editor")
  fakePack.pocketIndex = 4
  assert(fakePack:description() == "SEL: Add Item",
    "Gen 2 TM CANCEL row lacks its TM-only editor hint")
  local activationCollision = 0
  local activationOw = {
    player = { cellX = 5, cellY = 5, facing = "down" },
    map = {
      id = "FIX_MAP", def = { tileset = "FIX", environment = "ROUTE" },
      inBounds = function() return true end,
      isWalkableCell = function() return activationCollision == 0 end,
      cellCollision = function() return activationCollision end,
      cellTile = function() return 0 end,
    },
    npcs = {}, entities = {},
    runner = { isRunning = function() return false end },
  }
  activationOw.entities[1] = activationOw.player
  local activationGame = {
    save = { party = {} },
    data = run.data, world = activationOw,
    stack = { top = function() return activationOw end },
  }
  assert(not exports.followersIntegration.activate(activationGame),
    "follower controller installed before the first Pokemon existed")
  assert(not exports.followersIntegration.engine()._followersExControlEngine,
    "pre-starter game mutated PokÃƒÆ’Ã‚Â©PC's standalone controller")
  activationGame.save.party[1] = { species = "FIXMON_A", hp = 20 }
  local savedLove = love
  love = { graphics = {
    newImage = function()
      return { getDimensions = function() return 16, 96 end }
    end,
    newQuad = function() return {} end,
  } }
  assert(exports.followersIntegration.activate(activationGame),
    "follower controller did not activate on a settled existing save")
  local followerApi = assert(exports.followersIntegration.engine(),
    "SilverShadow follower control engine did not load")
  assert(followerApi._followersExControlEngine and followerApi.nativeGen2
      and type(followerApi.setFollowerCount) == "function"
      and type(followerApi.setControlMode) == "function"
      and type(followerApi.syncAll) == "function"
      and type(followerApi._integrationReady) == "function",
    "SilverShadow 0-6 follower control API was not installed")
  activationGame.save.party[2] = { species = "FIXMON_B", hp = 20 }
  followerApi.setFollowerCount(2)
  followerApi.syncAll(activationGame, activationOw)
  assert(type(activationOw.silverGen2Followers) == "table"
      and #activationOw.silverGen2Followers == 1,
    "native Gen 2 multi-follower controller did not spawn an extra trailer")
  local firstExtra = activationOw.silverGen2Followers[1]
  assert(firstExtra.cellX ~= activationOw.player.cellX
      or firstExtra.cellY ~= activationOw.player.cellY,
    "native Gen 2 extra follower spawned on top of the player")
  activationOw.player.cellY = activationOw.player.cellY + 1
  followerApi._step(activationGame)
  assert((firstExtra.targetX ~= nil or firstExtra.targetY ~= nil)
      and firstExtra.progress == 1,
    "native Gen 2 extra follower did not receive a spaced trail goal")
  local staleExtra = firstExtra
  activationOw.map.id = "FIX_MAP_2"
  activationOw.npcs, activationOw.entities = {}, { activationOw.player }
  followerApi.syncAll(activationGame, activationOw)
  assert(#activationOw.silverGen2Followers == 1
      and activationOw.silverGen2Followers[1] ~= staleExtra,
    "native Gen 2 extra follower was not rebuilt after a map change")

  -- Travel filtering is applied to the Gen 2 controller only. An edited FLY
  -- user remains airborne over water, an incapable follower hides, and an
  -- edited SURF user reappears with the swimming animation style.
  activationGame.save.party[1].moves = { { id = "FLY" } }
  activationGame.save.party[2].moves = {}
  local waterTypes=run.data.pokemon.FIXMON_B.types
  run.data.pokemon.FIXMON_B.types={"NORMAL"}
  activationOw.player.freeFlying = true
  activationOw.player.silverTravelAltitude = 56
  activationCollision = 0x20
  followerApi._step(activationGame)
  assert(followerApi._travelStyle(activationGame, activationOw,
      activationGame.save.party[1], activationOw.player) == "air",
    "Gen 2 FLY follower did not receive an airborne travel style")
  assert(#activationOw.silverGen2Followers == 0,
    "incapable Gen 2 follower did not hide over water")
  activationGame.save.party[2].moves = { { id = "SURF" } }
  run.data.pokemon.FIXMON_B.types=waterTypes
  followerApi._step(activationGame)
  assert(#activationOw.silverGen2Followers == 1
      and activationOw.silverGen2Followers[1].silverTravelStyle == "surf",
    "edited SURF follower did not reappear swimming")
  activationGame.save.party[2].moves = {}
  activationCollision = 0x80
  followerApi._step(activationGame)
  assert(#activationOw.silverGen2Followers == 0,
    "ground-only Gen 2 follower remained over a tree/wall cell")
  activationOw.player.freeFlying = nil
  activationOw.player.silverTravelAltitude = nil
  activationCollision = 0
  activationGame.save.party[1].moves = nil
  activationGame.save.party[2].moves = nil
  followerApi.syncAll(activationGame, activationOw)
  assert(#activationOw.silverGen2Followers == 1,
    "normal Gen 2 follower composition did not return after flight")

  -- PokePC's stock rule hides every primary follower in Surf state. The
  -- SilverShadow travel controller must replace that blanket rule with its
  -- terrain classifier, reserve no slot for the ridden Pokemon, and keep the
  -- remaining visible chain compact.
  activationGame.save.party[1].moves = { { id = "FLY" } }
  activationGame.save.party[2].moves = { { id = "SURF" } }
  activationGame.save.party[3] = {
    species = "FIXMON_C", hp = 20, moves = { { id = "FLY" } },
  }
  activationOw.sprites = run.data.gen2Sprites or run.data.sprites
  activationOw.sprites.SPRITE_CHRIS = {
    id = "SPRITE_CHRIS", image = "fixture_chris.png",
    frames = 6, walker = true,
  }
  activationOw.playerSpriteName = function() return "SPRITE_CHRIS" end
  local trainerPaletteApplied = false
  activationOw.applySpritePalette = function(_, entity)
    trainerPaletteApplied = entity and entity.sprite ~= nil
      and entity.spriteDef ~= nil
  end
  assert(freeFly._trainerSprite(activationOw) and trainerPaletteApplied,
    "replacement Surf trainer did not receive Gen 2's active OBJ palette")
  activationOw.playerState = "surf"
  activationOw.player.surfing = true
  activationOw.player.silverSurfMount = activationGame.save.party[2]
  activationCollision = 0x20
  local NativeFollower = require("src.world.gen2.Follower")
  NativeFollower.onMapEntered(activationGame, activationOw)
  assert(activationOw.follower ~= nil
      and followerApi._primaryEligible(activationGame, activationOw),
    "FLY-capable primary follower inherited PokePC's blanket Surf hide rule")
  followerApi.setFollowerCount(3)
  followerApi.syncAll(activationGame, activationOw)
  assert(followerApi._travelMount(activationOw) == activationGame.save.party[2],
    "Gen 2 controller did not identify the actual SURF mount")
  assert(#activationOw.silverGen2Followers == 1
      and activationOw.silverGen2Followers[1].pokepcMon
        == activationGame.save.party[3],
    "ridden SURF Pokemon was duplicated in the trailing formation")
  assert(activationOw.silverGen2FollowerLeadSlots == 1,
    "visible primary follower did not own exactly one compact trail slot")
  local surfExtra = activationOw.silverGen2Followers[1]
  assert(math.abs(surfExtra.cellX - activationOw.player.cellX)
      + math.abs(surfExtra.cellY - activationOw.player.cellY) == 2,
    "Surf formation retained an empty slot between visible followers")
  activationOw.playerState = "normal"
  activationOw.player.surfing = false
  activationOw.player.silverSurfMount = nil
  activationGame.save.party[3] = nil
  followerApi.setFollowerCount(2)
  activationOw.npcs, activationOw.entities = {}, { activationOw.player }
  NativeFollower.onMapEntered(activationGame, activationOw, {}, true)
  followerApi.syncAll(activationGame, activationOw)
  assert(activationOw.follower.cellX == activationOw.player.cellX
      and activationOw.follower.cellY == activationOw.player.cellY,
    "Gen 2 primary did not gather at the warp arrival")
  assert(#activationOw.silverGen2Followers == 1)
  for _, npc in ipairs(activationOw.silverGen2Followers) do
    assert(npc.cellX == activationOw.player.cellX
        and npc.cellY == activationOw.player.cellY,
      "Gen 2 warp invented a trail through the destination building")
  end
  love = savedLove

  -- A fresh game must not activate SilverShadow's controller just because the
  -- starter was inserted into the party. The give/nickname script and any UI
  -- it opens must finish first. Existing saves latch immediately once their
  -- ordinary overworld becomes idle, and remain latched through later dialogs.
  local busy = false
  local ow = {
    player = {}, map = {},
    runner = { isRunning = function() return busy end },
  }
  local top = ow
  local fresh = {
    save = { party = {} }, world = ow,
    stack = { top = function() return top end },
  }
  assert(not followerApi._integrationReady(fresh, ow),
    "follower controller activated before the starter existed")
  fresh.save.party[1] = { species = "FIXMON_A", hp = 20 }
  busy = true
  assert(not followerApi._integrationReady(fresh, ow),
    "follower controller activated during the starter script")
  busy = false
  top = { isOverworld = false }
  assert(not followerApi._integrationReady(fresh, ow),
    "follower controller activated under the nickname screen")
  top = ow
  assert(followerApi._integrationReady(fresh, ow),
    "follower controller did not activate after the starter flow")
  busy = true
  assert(followerApi._integrationReady(fresh, ow),
    "established followers disappeared during an ordinary dialog")
  assert(run.loader.exports.PokePCFollowers_VoxelMerge.setControlMode == nil,
    "SilverShadow must not mutate the separately installed provider's exports")
  assert(run.data.screens.SilverShadowGen2Followers,
    "Gen 2 follower options screen was not registered")
  assert(run.data.screens.Gen3Box == nil,
    "retired custom box screen was registered in Gen 2")
  local dexItem = assert(run.data.items.DEXNAV,
    "Gen 2 DEXNAV Key Item was not registered")
  assert(dexItem.pocket == "KEY_ITEM" and dexItem.canSelect == true
      and dexItem.canToss == false,
    "DEXNAV is not a registerable, permanent Key Item")
  local dexApi = assert(exports.gen2DexNav, "Gen 2 DexNav API was not exported")
  local dexGame = {
    data = run.data,
    save = { inventory = {}, party = { { hp = 10 } },
      pokedex = { caught = {} } },
  }
  local dexWorld = {
    map = { id = "FIX_ROUTE" }, player = { surfing = false }, tod = "DAY",
    wildTables = function()
      return { grass = { FIX_ROUTE = { rates = { DAY = 20 }, slots = {
        DAY = { { species = "FIXMON_A", level = 4 } },
      } } } }
    end,
  }
  assert(dexApi.ensureItem(dexGame) and dexGame.save.inventory.DEXNAV == 1,
    "DEXNAV was not granted to a Gen 2 save")
  local dexRows = dexApi.candidates(dexGame, dexWorld)
  assert(#dexRows == 1 and dexRows[1].species == "FIXMON_A",
    "DEXNAV did not read the current-time Gen 2 area table")

  local menuStack = { states = {} }
  function menuStack:push(state) self.states[#self.states + 1] = state end
  function menuStack:pop() return table.remove(self.states) end
  function menuStack:top() return self.states[#self.states] end
  local boxGame = {
    data = run.data, input = {}, stack = menuStack,
    save = { party = { { species = "FIXMON_A", hp = 10 } }, boxes = {},
      inventory = {} },
  }
  local startRows = Runtime.call("ui.start_menu.items",
    function(_, rows) return rows end, boxGame,
    { { id = "save", label = "SAVE" } })
  assert(boxGame.save.inventory.DEXNAV == 1,
    "opening Gen 2 START did not grant the permanent DEXNAV Key Item")
  local boxesRow
  for _, row in ipairs(startRows) do
    if row.label == "BOXES" then boxesRow = row break end
  end
  assert(boxesRow and boxesRow.onSelect,
    "Gold Start menu did not expose the BOXES shortcut")
  boxesRow.onSelect()
  local pc = menuStack:top()
  assert(pc and pc.entries and pc.entries[#pc.entries].id == "seeya",
    "BOXES did not open Gold's original PC menu")
  pc.index = #pc.entries
  pc:choose()
  assert(menuStack:top() == nil,
    "Gold PC SEE YA did not close the Start-menu shortcut")

  -- All ten trade replacements, including both split-family alternatives.
  local expected = {
    KADABRA = { into = "ALAKAZAM", level = 42 },
    GRAVELER = { into = "GOLEM", level = 42 },
    HAUNTER = { into = "GENGAR", level = 42 },
    MACHOKE = { into = "MACHAMP", level = 45 },
    ONIX = { into = "STEELIX", level = 40, item = "METAL_COAT" },
    SCYTHER = { into = "SCIZOR", level = 40, item = "METAL_COAT" },
    SEADRA = { into = "KINGDRA", level = 40, item = "DRAGON_SCALE" },
    PORYGON = { into = "PORYGON2", level = 40, item = "UP_GRADE" },
  }
  for from, wanted in pairs(expected) do
    local row = assert(run.data.pokemon[from].evolutions[1], from .. " has no evolution")
    assert(row.into == wanted.into and row.level == wanted.level
        and row.item == wanted.item,
      from .. " single-player evolution is wrong")
  end
  local poli = run.data.pokemon.POLIWHIRL.evolutions
  assert(#poli == 2 and poli[1].into == "POLIWRATH"
      and poli[1].item == "WATER_STONE"
      and poli[2].into == "POLITOED" and poli[2].item == "KINGS_ROCK",
    "Poliwhirl alternate branches were not preserved")
  local slow = run.data.pokemon.SLOWPOKE.evolutions
  assert(#slow == 2 and slow[1].into == "SLOWBRO" and slow[1].level == 37
      and slow[2].into == "SLOWKING" and slow[2].item == "KINGS_ROCK",
    "Slowpoke alternate branches were not preserved")

  local methodId = "SILVERSHADOW_LEVEL_ITEM"
  local method = assert(run.data.gen2EvolutionMethods[methodId],
    "custom held-item evolution method was not merged")
  local held = { method = methodId, level = 40, item = "METAL_COAT",
    into = "STEELIX" }
  assert(not method.check(held, { level = 39, item = "METAL_COAT" }, {}),
    "held-item evolution ignored its level")
  assert(not method.check(held, { level = 40, item = "KINGS_ROCK" }, {}),
    "held-item evolution ignored its item")
  local ok, _, consumes = method.check(
    held, { level = 40, item = "METAL_COAT" }, {})
  assert(ok and consumes == true, "held-item evolution did not request consumption")
  local plan = Evolution2.plan(run.data, {
    { species = "ONIX", level = 40, item = "METAL_COAT" },
  }, { [1] = true }, {})
  assert(#plan == 1 and plan[1].into == "STEELIX"
      and plan[1].consumesHeldItem == true,
    "engine evolution plan did not accept the custom method")
  local evolved = { species = "STEELIX", item = "METAL_COAT" }
  Runtime.emit("pokemon.evolved", { mon = evolved, via = methodId })
  assert(evolved.item == nil, "successful custom evolution did not consume its item")

  -- Dex Hunt selects uncaught local species on every ordinary encounter;
  -- it never imports an uncaught species from a different area.
  local caught={}
  for id,def in pairs(run.data.pokemon)do if tonumber(def.dex)then caught[id]=true end end
  caught.SCIZOR=nil
  local localSpecies="SCIZOR"
  local world={map={id="FIX_ROUTE"},player={surfing=false},tod="DAY",
    wildTables=function()return {grass={FIX_ROUTE={rates={DAY=20},slots={DAY={
      {species=localSpecies,level=17}}}}}}end}
  local game={data=run.data,world=world,save={pokedex={caught=caught}}}
  shared.game=game;shared.set("all_251_catchable",true)
  shared.set("catch_all_interval",50) -- obsolete saved interval cannot delay hunting
  local function encounter(kind)
    return Runtime.call("encounter.species",function(row)return row end,
      {species="KADABRA",level=17},{kind=kind,data=run.data,rng=function()return 1 end})
  end
  for _,kind in ipairs({"contest","script","sweet_scent"})do
    assert(encounter(kind).species=="KADABRA",kind.." must stay native")
  end
  for _=1,3 do assert(encounter("wild").species=="SCIZOR","local hunt must work immediately")end
  caught.SCIZOR=true;caught.PORYGON2=nil
  assert(encounter("wild").species=="KADABRA","hunt leaked another area's species")
  localSpecies="PORYGON2"
  assert(encounter("wild").species=="PORYGON2","local table update ignored")
  shared.set("all_251_catchable",false)
  assert(encounter("wild").species=="KADABRA","uncaught preference toggle ignored")
  local oldTables=run.data.gen2Encounters
  local home=shared.collectionHomes.johto[212]
  run.data.gen2Encounters={
    grass={[home.map]={rates={DAY=20},slots={DAY={{species="KADABRA",level=17}}}}},
    timeFishGroups={{species="SCIZOR",level=209}},
  }
  local found=false
  for _,row in ipairs(shared.gen2AreaRows(game,{
    map={id=home.map},player={surfing=false},tod="DAY",
  }))do if row.species=="SCIZOR"then found=true end end
  assert(found,"unused imported fishing data suppressed an obtainable species")
  run.data.gen2Encounters=oldTables

  -- Move Manager follows Gen 2 levelMoves and into evolution links and uses
  -- the active move registry, including Dark/Steel and both Gen 2 HMs.
  run.data.pokemon.TEST_BABY = {
    id = "TEST_BABY", name = "TEST BABY", dex = 240, types = { "DARK" },
    evolutions = { { method = "EVOLVE_LEVEL", level = 12, into = "TEST_FINAL" } },
    levelMoves = {
      { level = 5, move = "DARK_TEST" },
      { level = 30, move = "LATE_TEST" },
    },
  }
  run.data.pokemon.TEST_FINAL = {
    id = "TEST_FINAL", name = "TEST FINAL", dex = 241, types = { "STEEL" },
    evolutions = {},
    levelMoves = { { level = 15, move = "STEEL_TEST" } },
  }
  for _, id in ipairs({
    "DARK_TEST", "LATE_TEST", "STEEL_TEST", "CURRENT_TEST",
    "WHIRLPOOL", "WATERFALL",
  }) do
    run.data.moves[id] = {
      id = id, name = id, pp = 10, type = id == "STEEL_TEST" and "STEEL" or "DARK",
      power = id == "CURRENT_TEST" and 0 or 40,
      category = id == "CURRENT_TEST" and "status" or "physical",
    }
  end
  local mon = {
    species = "TEST_FINAL", level = 20,
    moves = { { id = "CURRENT_TEST", pp = 10 } },
  }
  local learned = exports.learnedMoves(game, mon)
  assert(contains(learned, "DARK_TEST") and contains(learned, "STEEL_TEST")
      and contains(learned, "CURRENT_TEST") and not contains(learned, "LATE_TEST"),
    "Move Manager did not reconstruct Gen 2 move history")
  local changed = exports.replaceMove(game, mon, 1, "STEEL_TEST")
  assert(changed and mon.moves[1].id == "STEEL_TEST",
    "Move Manager did not read the live Gen 2 move registry")
  local hmMon = { moves = { { id = "WATERFALL", pp = 10 } } }
  local hmOk, hmReason = exports.replaceMove(game, hmMon, 1, "WHIRLPOOL")
  assert(not hmOk and hmReason == "hm_locked",
    "Gen 2 Waterfall/Whirlpool HM protection is missing")
  assert(contains(exports.allMoves.physicalTypes, "STEEL")
      and contains(exports.allMoves.specialTypes, "DARK"),
    "Gen 2 Dark/Steel type categories are missing")
  run.data.moves.generation = 2
  local darkRows = exports.allMoves.rows(game, "special", "DARK")
  local steelRows = exports.allMoves.rows(game, "physical", "STEEL")
  assert(contains((function()
      local ids = {}; for _, row in ipairs(darkRows) do ids[#ids + 1] = row.id end
      return ids
    end)(), "DARK_TEST"),
    "Gen 2 Dark moves were not kept in the Special type split")
  assert(contains((function()
      local ids = {}; for _, row in ipairs(steelRows) do ids[#ids + 1] = row.id end
      return ids
    end)(), "STEEL_TEST"),
    "Gen 2 Steel moves were not kept in the Physical type split")
  assert(exports.allMoves.coverage(game),
    "Gen 2 numeric move-table metadata entered the move editor")

  run.release()
end

loadGen1()
loadGen2()
GameVersion.set("blue")
print("SilverShadow Gen 1/" .. gen2Version .. " packaged loader tests: passed")
