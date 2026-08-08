-- HM Anywhere for Gen1Recomp
-- Owning an HM item is enough to use its field action.
-- CUT, SURF and STRENGTH are contextual A-button actions.
-- FLASH and FLY are exposed through Start -> HM.

local PATCH_KEY = "__hm_anywhere_dispatch_v2"

local HM_BADGES = {
  CUT = "CASCADEBADGE",
  FLY = "THUNDERBADGE",
  SURF = "SOULBADGE",
  STRENGTH = "RAINBOWBADGE",
  FLASH = "BOULDERBADGE",
}

local FIELD_HMS = {
  CUT = true,
  FLY = true,
  SURF = true,
  STRENGTH = true,
  FLASH = true,
}

local function hasCount(value)
  if type(value) == "number" then return value > 0 end
  return value == true
end

local function knowsMove(mon, moveId)
  for _, move in ipairs((mon and mon.moves) or {}) do
    if (type(move) == "table" and move.id or move) == moveId then return true end
  end
  return false
end

local function partyKnower(game, moveId)
  for _, mon in ipairs(game and game.save and game.save.party or {}) do
    if knowsMove(mon, moveId) then return mon end
  end
  return nil
end

local function ownedHM(game, moveId)
  local inventory = game and game.save and game.save.inventory or {}
  local items = game and game.data and game.data.items or {}
  for itemId, count in pairs(inventory) do
    if hasCount(count) then
      local def = items[itemId]
      local machine = def and def.machine
      if machine and machine.kind == "HM" and machine.move == moveId then
        return itemId, def
      end
    end
  end
  return nil
end

local function fieldCapable(game, moveId)
  return ownedHM(game, moveId) ~= nil or partyKnower(game, moveId) ~= nil
end

local function hasBadge(game, moveId)
  local badge = HM_BADGES[moveId]
  if not badge then return true end
  local inventory = game and game.save and game.save.inventory or {}
  return hasCount(inventory[badge])
end

local function travelBadgeAllowed(game, shared, moveId)
  return not shared.bool("fly_badge_checks", true) or hasBadge(game, moveId)
end

local function fieldHelper(game)
  local party = game and game.save and game.save.party or {}
  for _, mon in ipairs(party) do
    if (mon.hp or 0) > 0 then return mon end
  end
  return party[1]
end

local function pushText(game, text, onDone)
  local TextBox = require("src.render.TextBox")
  game.stack:push(TextBox.new(game, text, onDone))
end

local function badgeRequired(game)
  return game.data.text._NewBadgeRequiredText
    or "A new BADGE is\nrequired."
end

local function noLandingText(game)
  return game.data.text._SurfingNoPlaceToGetOffText
    or "No place to get\noff here!"
end

local function tryStrength(game, ow)
  if not ownedHM(game, "STRENGTH") then return false end
  local Map = require("src.world.Map")
  local player = ow.player
  local fx, fy = player:facingCell()
  local npc = ow:npcAtCell(fx, fy)
  if not (npc and npc.def and Map.isPushable(npc.def)) then return false end

  if not hasBadge(game, "STRENGTH") then
    pushText(game, badgeRequired(game))
    return true
  end

  local function pushNow()
    if not (ow.map and ow.player) then return end
    ow.strengthActive = true
    -- Vanilla requires a first collision to arm BIT_TRIED_PUSH_BOULDER and a
    -- second one to move. A contextual A press performs both attempts.
    ow.boulderTried = nil
    ow:checkBoulderPush(player.facing)
    ow:checkBoulderPush(player.facing)
  end

  if not ow.strengthActive then
    ow.strengthActive = true
    pushText(game,
      "The HM device used\nSTRENGTH!\fBoulders can now\nbe moved.", pushNow)
  else
    pushNow()
  end
  return true
end

local function tryCut(game, ow)
  if not ownedHM(game, "CUT") then return false end
  local reason = ow:useCutFieldMove()
  if reason ~= "ok" then return false end
  if not hasBadge(game, "CUT") then
    pushText(game, badgeRequired(game))
    return true
  end
  local fx, fy = ow.player:facingCell()
  ow:tryCut(fx, fy)
  return true
end

local function dismountSurf(game, ow)
  local player = ow.player
  player.surfing = false
  require("src.core.Music").setSurfing(game.data, false)
  local Transition = require("src.render.Transition")
  game.stack:push(Transition.whiteFlash(game, nil, function()
    ow:stepForwardOrCrossEdge(player.facing)
  end))
end

local function trySurf(game, ow, shared)
  if not fieldCapable(game, "SURF") then return false end
  local reason = ow:useSurfFieldMove()
  if reason == "no_water" or reason == "forced_bike" or reason == "current" then
    return false
  end
  if not travelBadgeAllowed(game, shared, "SURF") then
    pushText(game, badgeRequired(game))
    return true
  end
  if reason == "ok" then
    local fx, fy = ow.player:facingCell()
    ow:trySurf(fx, fy)
    return true
  elseif reason == "dismount" then
    dismountSurf(game, ow)
    return true
  elseif reason == "no_place" then
    pushText(game, noLandingText(game))
    return true
  end
  return false
end

local function bestRod(game)
  local inventory = game and game.save and game.save.inventory or {}
  for _, id in ipairs({ "SUPER_ROD", "GOOD_ROD", "OLD_ROD" }) do
    if hasCount(inventory[id]) then return id end
  end
  return nil
end

-- A owns the water interaction. It resolves available actions first, skips
-- needless prompts for a single action, and delegates fishing to goFishing so
-- the engine's real rod/map tables and bite rules remain authoritative.
local function tryWater(game, ow, shared)
  if not (ow and ow.player and ow.map) then return false end
  local reason = ow:useSurfFieldMove()
  if reason == "dismount" or reason == "no_place" then
    return trySurf(game, ow, shared)
  end

  local fx, fy = ow.player:facingCell()
  if not ow.map:inBounds(fx, fy) or not ow.map:isWaterCell(fx, fy) then
    return false
  end

  local rod = bestRod(game)
  local surfCapable = fieldCapable(game, "SURF")
  local surfBadgeOk = travelBadgeAllowed(game, shared, "SURF")
  local surfAvailable = surfCapable and surfBadgeOk and reason == "ok"
  local fishAvailable = rod ~= nil

  if surfAvailable and fishAvailable then
    local Menu = require("src.ui.Menu")
    game.stack:push(Menu.new(game, {
      { label = "SURF", onSelect = function() trySurf(game, ow, shared) end },
      { label = "FISH", onSelect = function() ow:goFishing(rod) end },
      { label = "CANCEL" },
    }, { tx = 11, ty = 8, tw = 9, th = 8 }))
    return true
  end
  if surfAvailable then return trySurf(game, ow, shared) end
  if fishAvailable then ow:goFishing(rod); return true end
  if surfCapable and not surfBadgeOk then
    pushText(game, badgeRequired(game))
    return true
  end
  return false
end

local function contextualInteract(game, baseInteract, ow, shared, ...)
  if not (ow and ow.player and ow.map) then return baseInteract(ow, ...) end

  -- Exact contextual targets win before vanilla interaction. A pushable
  -- boulder is an NPC object, so STRENGTH must run before talkTo.
  if tryStrength(game, ow) then return end
  if tryCut(game, ow) then return end
  if tryWater(game, ow, shared) then return end

  -- NPCs, signs, hidden items, scripts and bookshelves keep vanilla priority.
  return baseInteract(ow, ...)
end

local function isOutside(game, ow)
  if not (ow and ow.map and ow.map.def) then return false end
  local Map = require("src.world.Map")
  local FieldDefaults = require("src.world.FieldDefaults")
  return Map.isOutside(ow.map.def,
    FieldDefaults.field(game.data, "outsideTilesets"))
end

local function removeVanillaHMRows(items)
  local out = {}
  for _, item in ipairs(items or {}) do
    local label = tostring(item.label or ""):upper()
    if not FIELD_HMS[label] then out[#out + 1] = item end
  end
  return out
end

local function flashFromMenu(game, reopen)
  local ow = game.overworld
  if not (ow and ow.map and ow.player) then
    pushText(game, "FLASH can't be\nused right now.", reopen)
    return
  end
  if not hasBadge(game, "FLASH") then
    pushText(game, badgeRequired(game), reopen)
    return
  end
  if not ow.dark then
    pushText(game, "It is already\nbright here.", reopen)
    return
  end

  game.save.flashLit = true
  pushText(game,
    game.data.text._FlashLightsAreaText
      or "A blinding FLASH\nlights the area!",
    function()
      local Transition = require("src.render.Transition")
      game.stack:push(Transition.whiteFlash(game, nil, function()
        if ow.setDark then ow:setDark(false) else ow.dark = false end
      end))
    end)
end

local function flyBadgeAllowed(game, shared)
  return travelBadgeAllowed(game, shared, "FLY")
end

local function flyFromMenu(game, mod, shared, reopen)
  local ow = game.overworld
  if not flyBadgeAllowed(game, shared) then
    pushText(game, badgeRequired(game), reopen)
    return
  end
  if not isOutside(game, ow) then
    pushText(game, "FLY can't be used\nhere.", reopen)
    return
  end

  local current = ow
  mod.ui.push(game, "TownMap", {
    fly = true,
    onFly = function(mapId)
      if current and current.flyTo then current:flyTo(mapId) end
    end,
  })
end

local function closeToOverworld(game)
  while game.stack:top() and not game.stack:top().isOverworld do
    game.stack:pop()
  end
end

local function surfFromParty(game, shared)
  if not travelBadgeAllowed(game, shared, "SURF") then
    pushText(game, badgeRequired(game))
    return
  end
  local ow = game.overworld
  if not (ow and ow.player and ow.map) then
    pushText(game, "SURF can't be used\nright now.")
    return
  end
  local reason = ow:useSurfFieldMove()
  if reason == "ok" then
    local fx, fy = ow.player:facingCell()
    ow:trySurf(fx, fy, function() closeToOverworld(game) end)
    return
  end
  if reason == "dismount" then
    closeToOverworld(game)
    dismountSurf(game, ow)
    return
  end
  if reason == "no_place" then
    pushText(game, noLandingText(game), function() closeToOverworld(game) end)
    return
  end
  local key = ({
    forced_bike = "_CyclingIsFunText",
    current = "_CurrentTooFastText",
  })[reason] or "_NoSurfingHereText"
  local text = game.data.text[key] or "No SURFing here!"
  pushText(game, text)
end

local function openHMMenu(game, mod, shared)
  local Menu = require("src.ui.Menu")
  local Screens = require("src.ui.Screens")

  local function reopen()
    openHMMenu(game, mod, shared)
  end

  local items = {}
  if ownedHM(game, "FLASH") then
    items[#items + 1] = {
      label = "FLSH",
      onSelect = function() flashFromMenu(game, reopen) end,
    }
  end
  if ownedHM(game, "FLY") then
    items[#items + 1] = {
      label = "FLY",
      onSelect = function() flyFromMenu(game, mod, shared, reopen) end,
    }
  end

  -- The Start-menu hook only creates HM when at least one entry exists.
  -- Keep a defensive fallback for inventories changed by another mod while
  -- the menu is already open.
  if #items == 0 then
    pushText(game, "No usable HM is\nin the BAG.", function()
      Screens.push(game, "StartMenu")
    end)
    return
  end

  game.stack:push(Menu.new(game, items, {
    tx = 11,
    ty = 0,
    tw = 9,
    onCancel = function()
      Screens.push(game, "StartMenu")
    end,
  }))
end

return function(mod, shared)
  mod.events:on("game.ready", function(event)
    local game = event and event.game
    local OverworldState = game and game.overworld
    if not (game and type(OverworldState) == "table") then
      mod.log:warn("HM Anywhere could not install: game.ready had no overworld; restart with the mod enabled")
      return
    end
    if type(OverworldState.interact) ~= "function"
       or type(OverworldState.partyKnows) ~= "function" then
      mod.log:warn("HM Anywhere could not find the expected overworld field-move methods; check game compatibility")
      return
    end

    local dispatch = rawget(_G, PATCH_KEY)
    if not dispatch then
      dispatch = {
        baseInteract = OverworldState.interact,
        basePartyKnows = OverworldState.partyKnows,
      }
      rawset(_G, PATCH_KEY, dispatch)

      OverworldState.interact = function(self, ...)
        local handler = dispatch.interact
        if handler then return handler(self, ...) end
        return dispatch.baseInteract(self, ...)
      end

      OverworldState.partyKnows = function(self, moveId, ...)
        local handler = dispatch.partyKnows
        if handler then
          local mon = handler(self, moveId, ...)
          if mon then return mon end
        end
        return dispatch.basePartyKnows(self, moveId, ...)
      end
    end

    dispatch.interact = function(ow, ...)
      return contextualInteract(game, dispatch.baseInteract, ow, shared, ...)
    end
    dispatch.partyKnows = function(_, moveId)
      if FIELD_HMS[moveId] and ownedHM(game, moveId) then
        return fieldHelper(game)
      end
      if (moveId == "FLY" or moveId == "SURF")
          and travelBadgeAllowed(game, shared, moveId) then
        return partyKnower(game, moveId)
      end
      return nil
    end

    mod.log:info("HM Anywhere installed: contextual CUT/SURF/STRENGTH and Start-menu FLASH/FLY are active")
  end)

  -- Remove redundant field-action rows from each Pokemon's submenu. The
  -- moves remain teachable and usable in battle.
  shared.registerPartyDecorator("field_moves", 10, function(game, out, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end
    out = removeVanillaHMRows(out)
    local ow = ctx and ctx.overworld
    if not ow then return out end

    local function insertAfter(label, item)
      for i, existing in ipairs(out) do
        if tostring(existing.label or ""):upper() == label then
          table.insert(out, i + 1, item)
          return
        end
      end
      table.insert(out, 1, item)
    end

    if knowsMove(mon, "FLY") and isOutside(game, ow)
        and flyBadgeAllowed(game, shared) then
      insertAfter("FREEFLY", {
        label = "FLY",
        onSelect = function(_, selectedGame)
          -- Recheck here as well as at row construction so changing BADGE
          -- CHECK while this submenu is open cannot bypass the setting.
          if not flyBadgeAllowed(selectedGame, shared) then
            pushText(selectedGame, badgeRequired(selectedGame))
            return
          end
          local current = selectedGame.overworld
          if not isOutside(selectedGame, current) then
            pushText(selectedGame, "FLY can't be used\nhere.")
            return
          end
          closeToOverworld(selectedGame)
          mod.ui.push(selectedGame, "TownMap", {
            fly = true,
            onFly = function(mapId)
              if current and current.flyTo then current:flyTo(mapId) end
            end,
          })
        end,
      })
    end

    if knowsMove(mon, "SURF")
        and travelBadgeAllowed(game, shared, "SURF") then
      local surfItem = {
        label = "SURF",
        onSelect = function(_, selectedGame)
          surfFromParty(selectedGame, shared)
        end,
      }
      local hasFly = false
      for _, existing in ipairs(out) do
        if tostring(existing.label or ""):upper() == "FLY" then
          hasFly = true
          break
        end
      end
      insertAfter(hasFly and "FLY" or "FREEFLY", surfItem)
    end
    return out
  end)

  -- FLASH and FLY share one Start-menu HM submenu. The parent entry appears
  -- only when a corresponding HM item is actually in the Bag. Move Editor
  -- knowledge remains available from the Pokemon's own field-action submenu.
  shared.registerStartItem("hm", 20, function(game)
    if not (ownedHM(game, "FLASH") or ownedHM(game, "FLY")) then return nil end
    return {
      label = "HM",
      onSelect = function()
        openHMMenu(game, mod, shared)
      end,
    }
  end)

  mod.exports.ownedHM = function(game, moveId)
    return ownedHM(game, moveId) ~= nil
  end
  mod.exports.hasBadge = hasBadge
  mod.exports.bestRod = bestRod
  mod.exports.fieldCapable = fieldCapable
  mod.exports.useEditedSurf = function(game, ow)
    return trySurf(game, ow, shared)
  end
  shared.travelBadgeAllowed = function(game, moveId)
    return travelBadgeAllowed(game, shared, moveId)
  end
end
