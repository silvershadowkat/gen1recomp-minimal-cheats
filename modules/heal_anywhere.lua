-- Heal Anywhere: paid field heal with a real Poké Center machine sprite.
-- Voxel FX must be drawn while Voxel3D's overlay canvas is bound (inside
-- drawFx / just before endOverlay). Replacing ctx.fx.heal alone does nothing
-- — drawFx closes over the local fxHeal.
return function(mod, shared)
  local Strings = require("src.core.Strings")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local Pokemon = require("src.pokemon.Pokemon")
  local Music = require("src.core.Music")
  local Game = require("src.core.Game")
  local OverworldState = require("src.world.OverworldController")
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")
  local Zoom = require("src.render.Zoom")
  local Badges = require("src.inventory.Badges")

  -- First use after nurse = BASE[badges]; each extra use multiplies.
  -- Anchored to Gen 1 shop medicine (Potion 300 … Full Restore 3000).
  local BASE_BY_BADGES = {
    [0] = 250,
    [1] = 400,
    [2] = 600,
    [3] = 900,
    [4] = 1200,
    [5] = 1800,
    [6] = 2500,
    [7] = 3500,
    [8] = 5000,
  }

  local FIELD_BALL_XY = {
    { 8, 12 }, { 16, 12, true },
    { 8, 16 }, { 16, 16, true },
    { 8, 20 }, { 16, 20, true },
  }
  -- Monitor OAM on the machine face (a bit lower than stock 44,20 mapping).
  local MONITOR_XY = { 12, 4 }
  -- Nudge the field machine farther from the player (world pixels).
  local FIELD_AWAY_PX = 5
  local HEAL_FLASH_MAP = { [0] = 0, [1] = 2, [2] = 1, [3] = 3 }

  local machineImg, ballImg, ballQuad, monitorQuad

  local function loadImages(force)
    if not force and machineImg then return machineImg ~= false end
    machineImg, ballImg, ballQuad, monitorQuad = nil, nil, nil, nil
    local path = mod.path .. "/assets/field_heal_machine.png"
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
      pcall(img.setFilter, img, "nearest", "nearest")
      machineImg = img
    else
      machineImg = false
      mod.log:warn("heal machine image missing: %s", tostring(path))
    end
    local fx = Game and Game.data and Game.data.field and Game.data.field.overworldFx
    local bpath = fx and fx.healMachine and fx.healMachine.path
    if bpath then
      local ok2, img2 = pcall(love.graphics.newImage, bpath)
      if ok2 and img2 then
        ballImg = img2
        local w, h = img2:getWidth(), img2:getHeight()
        monitorQuad = love.graphics.newQuad(0, 0, 8, 8, w, h)
        ballQuad = love.graphics.newQuad(0, 8, 8, 8, w, h)
      end
    end
    return machineImg and true or false
  end

  local function currentCost(save)
    local uses = (save and save.healAnywhereUses) or 0
    local badges = 0
    if Game and Game.data and save then
      local ok, n = pcall(Badges.count, Game.data, save)
      if ok and type(n) == "number" then
        badges = math.max(0, math.min(8, math.floor(n)))
      end
    end
    local base = BASE_BY_BADGES[badges] or BASE_BY_BADGES[0]
    return base * (1 + uses)
  end

  local function frontCell(ow)
    local p = ow.player
    local f = p.facing or "down"
    local dx = f == "right" and 1 or f == "left" and -1 or 0
    local dy = f == "down" and 1 or f == "up" and -1 or 0
    local x, y = p.cellX + dx, p.cellY + dy
    if ow.map:inBounds(x, y) then return x, y end
    return p.cellX, p.cellY
  end

  local function awayPixels(facing)
    local f = facing or "down"
    local dx = f == "right" and FIELD_AWAY_PX or f == "left" and -FIELD_AWAY_PX or 0
    local dy = f == "down" and FIELD_AWAY_PX or f == "up" and -FIELD_AWAY_PX or 0
    return dx, dy
  end

  -- Cam-relative world pixels — same contract as stock fxHeal inside at().
  local function drawFieldHeal(ow, ha)
    if not ha or not ha.field then return end
    if not loadImages(false) then loadImages(true) end
    local cam = ow.camera
    if not cam then return end
    local mx = ha.mx or ((ha.px or 0) - 8)
    local my = ha.my or ((ha.py or 0) - 16)
    local ox = mx - math.floor(cam.x)
    local oy = my - math.floor(cam.y)

    local prevShader = love.graphics.getShader and love.graphics.getShader() or nil
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)

    if machineImg then
      love.graphics.draw(machineImg, ox, oy)
    end

    local flash = (ha.visible == false) and (ha.phase == "flash")
    local function withFlash(drawFn)
      if flash then
        local shader = PaletteFX.shader()
        if shader then
          PaletteFX.sendColors(shader,
            PaletteFX.permute(PaletteFX.GRAYS, HEAL_FLASH_MAP))
          love.graphics.setShader(shader)
        end
      else
        love.graphics.setShader()
      end
      drawFn()
      love.graphics.setShader()
    end

    if ballImg and monitorQuad then
      withFlash(function()
        love.graphics.draw(ballImg, monitorQuad,
          ox + MONITOR_XY[1], oy + MONITOR_XY[2])
      end)
    end

    if ballImg and ballQuad and (ha.lit or 0) > 0 then
      withFlash(function()
        for i = 1, math.min(ha.lit or 0, #FIELD_BALL_XY) do
          local b = FIELD_BALL_XY[i]
          if b[3] then
            love.graphics.draw(ballImg, ballQuad,
              ox + b[1] + 8, oy + b[2], 0, -1, 1)
          else
            love.graphics.draw(ballImg, ballQuad, ox + b[1], oy + b[2])
          end
        end
      end)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if prevShader then love.graphics.setShader(prevShader) end
  end

  -- Same projected transform stock drawFx `at()` uses for dust/heal.
  -- Returns true when something was actually painted.
  local function drawFieldHealProjected(ow, ha, project, scale)
    if not ha or not ha.field or not project then return false end
    local cam = ow.camera
    if not cam then return false end
    local wx = (ha.px or 0) + 8
    local wy = (ha.py or 0) + 16
    local sx, sy = project(wx, wy)
    if not sx then return false end
    scale = scale or 1
    local fx, fy = wx - cam.x, wy - cam.y
    love.graphics.push()
    love.graphics.scale(scale, scale)
    love.graphics.translate(sx / scale - fx, sy / scale - fy)
    love.graphics.setShader()
    drawFieldHeal(ow, ha)
    love.graphics.pop()
    return true
  end

  local function voxelScale()
    local fit = Game and Game.renderer and Game.renderer.fitScale
      and Game.renderer:fitScale() or 1
    return Zoom.scale and Zoom.scale(fit) or fit or 1
  end

  local function doHeal(game)
    local save = game.save
    local ow = game.overworld
    if not ow or not ow.player or not ow.map then
      game.stack:push(TextBox.new(game,
        Strings("Can't heal here\nright now.")))
      return
    end
    if ow.healAnim then
      game.stack:push(TextBox.new(game,
        Strings("Already healing!")))
      return
    end

    local cost = currentCost(save)
    if (save.money or 0) < cost then
      game.stack:push(TextBox.new(game,
        Strings("You don't have\nenough money!\fNeed ¥%d.", cost)))
      return
    end

    save.money = (save.money or 0) - cost
    save.healAnywhereUses = (save.healAnywhereUses or 0) + 1
    for _, mon in ipairs(save.party or {}) do
      Pokemon.heal(mon)
    end

    local cellX, cellY = frontCell(ow)
    local adx, ady = awayPixels(ow.player.facing)
    local mx = cellX * 16 - 8 + adx
    local my = cellY * 16 - 16 + ady
    save.lastHeal = {
      map = ow.map.id,
      x = ow.player.cellX,
      y = ow.player.cellY,
      field = true,
    }

    pcall(Music.stop)
    ow.player.inputLocked = true
    local nextCost = currentCost(save)
    loadImages(true)
    ow.healAnim = {
      balls = math.max(1, #(save.party or {})),
      lit = 0,
      timer = 0,
      visible = true,
      field = true,
      mx = mx,
      my = my,
      px = mx + 8,
      py = my + 16,
      onDone = function()
        ow.player.inputLocked = false
        game.stack:push(TextBox.new(game,
          Strings("Your POKéMON are\nfighting fit!\fPaid ¥%d.\fNext heal: ¥%d.",
            cost, nextCost)))
      end,
    }
  end

  if OverworldState.nurseHeal and not OverworldState._healAnywhereWrapped then
    local orig = OverworldState.nurseHeal
    function OverworldState:nurseHeal(onDone, npc)
      if Game and Game.save then
        Game.save.healAnywhereUses = 0
      end
      return orig(self, onDone, npc)
    end
    OverworldState._healAnywhereWrapped = true
  end

  -- Flat path: suppress stock OAM and paint after the world pass.
  if not OverworldState._healAnywhereDrawWrapped then
    local origDrawWorld = OverworldState.drawWorld
    function OverworldState:drawWorld(...)
      local ha = self.healAnim
      if ha and ha.field then
        local saved = self.healMachineImg
        self.healMachineImg = false
        origDrawWorld(self, ...)
        self.healMachineImg = saved
        if not Pipelines.worldPipeline() then
          drawFieldHeal(self, ha)
        end
      else
        origDrawWorld(self, ...)
      end
    end
    OverworldState._healAnywhereDrawWrapped = true
  end

  -- Voxel: suppress stock heal OAM in drawFx, then paint our machine just
  -- before endOverlay while the scene canvas is still bound.
  local drewVoxelHeal = false

  local function installDrawFxWrap()
    if Pipelines._healAnywhereDrawFxWrapped then return end
    local origPipe = Pipelines.drawWorld
    Pipelines._healAnywhereOrigDrawWorld = origPipe
    function Pipelines.drawWorld(id, ctx)
      if ctx and ctx.drawFx and ctx.state then
        local origDrawFx = ctx.drawFx
        local st = ctx.state
        ctx.drawFx = function(project, scale)
          drewVoxelHeal = false
          local ha = st.healAnim
          local savedAnim
          if ha and ha.field then
            savedAnim = ha
            st.healAnim = nil
          end
          origDrawFx(project, scale)
          if savedAnim then
            st.healAnim = savedAnim
            -- Prefer drawing here (correct project/scale from the pipeline).
            local ok, painted = pcall(drawFieldHealProjected, st, savedAnim,
              project, scale)
            drewVoxelHeal = ok and painted or false
          end
        end
      end
      return origPipe(id, ctx)
    end
    Pipelines._healAnywhereDrawFxWrapped = true
  end
  installDrawFxWrap()

  local function installEndOverlayWrap()
    local function bind(V3)
      if type(V3) ~= "table" or type(V3.endOverlay) ~= "function" then
        return false
      end
      if V3._healAnywhereEndWrapped then return true end
      local origEnd = V3.endOverlay
      V3._healAnywhereOrigEnd = origEnd
      function V3.endOverlay()
        pcall(function()
          if drewVoxelHeal then return end
          local ow = Game and Game.overworld
          local ha = ow and ow.healAnim
          if not (ha and ha.field and type(V3.project) == "function") then
            return
          end
          local cam = ow.camera
          if not cam then return end
          local scale = voxelScale()
          local wx = (ha.px or 0) + 8
          local wy = (ha.py or 0) + 16
          local sx, sy = V3.project(wx, 0, wy)
          if not sx then return end
          local fx, fy = wx - cam.x, wy - cam.y
          love.graphics.setShader()
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.push()
          love.graphics.scale(scale, scale)
          love.graphics.translate(sx / scale - fx, sy / scale - fy)
          drawFieldHeal(ow, ha)
          love.graphics.pop()
        end)
        drewVoxelHeal = false
        return origEnd()
      end
      V3._healAnywhereEndWrapped = "1.2.1"
      return true
    end

    local function tryBind()
      for _, id in ipairs({ "DRAMATIC_SHAPE", "DRAMATIC_SHAPE_SEAMLESS" }) do
        local ds = mod:find(id)
        local lib = ds and ds.exports and ds.exports.lib
        if lib and type(lib.require) == "function" then
          local ok, V3 = pcall(lib.require, "Voxel3D")
          if ok and bind(V3) then return true end
        end
      end
      return false
    end
    tryBind()
    return tryBind
  end

  local rebindEnd = installEndOverlayWrap()

  shared.registerStartItem("heal", 30, function(game)
    local cost = currentCost(game.save)
    return {
      label = Strings("HEAL ¥%d", cost),
      onSelect = function()
        local c = currentCost(game.save)
        game.stack:push(TextBox.new(game,
          Strings("Call a healing\nmachine for ¥%d?", c), function()
          game.stack:push(ChoiceBox.new(game, function(yes)
            if yes then doHeal(game) end
          end))
        end))
      end,
    }
  end)

  mod.events:on("game.ready", function()
    loadImages(true)
    installDrawFxWrap()
    -- Dramatic Shape may load after us; retry the endOverlay bind.
    if rebindEnd then rebindEnd() end
  end)

  mod.exports.version = "1.0.0"
  mod.exports.healAnywhereCost = currentCost
  mod.log:info("HEAL_ANYWHERE 1.0.0")
end
