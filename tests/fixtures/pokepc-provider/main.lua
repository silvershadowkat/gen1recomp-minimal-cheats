return function(mod)
  local Follower = require("src.world.PikachuFollower")

  local function pathFor(species)
    return mod.path .. "/assets/follower_"
      .. tostring(species or "CHARMANDER"):upper() .. ".png"
  end

  local sprite = {
    image = pathFor("CHARMANDER"),
    frames = 6,
    walker = true,
    trueColor = true,
  }
  if mod.content.sprites:get("SPRITE_PIKACHU") then
    mod.content.sprites:patch("SPRITE_PIKACHU", sprite)
  else
    mod.content.sprites:register("SPRITE_PIKACHU", sprite)
  end

  mod.exports.supported = true
  mod.exports.assetPath = pathFor
  mod.exports.resolveFollowerSprite = function(opts)
    local species = type(opts) == "table" and opts.species or opts
    if type(species) ~= "string" or species == "" then return nil end
    return {
      image = pathFor(species),
      frames = 6,
      walker = true,
      trueColor = true,
      providerId = mod.id,
    }
  end
  -- Mirror PokePC's private Gen 2 map-entry Surf purge. Its public setter can
  -- be replaced by SilverShadow, but this closed-over check is exactly the
  -- compatibility seam that previously deleted an approved flying follower.
  local function stockShouldSpawn(_, world)
    return not (world and ((world.player and world.player.surfing)
      or world.playerState == "surf" or world.playerState == "surf_pika"))
  end
  mod.exports.shouldSpawn = stockShouldSpawn

  local originalOnMapEntered = Follower.onMapEntered
  if type(originalOnMapEntered) == "function" then
    Follower.onMapEntered = function(game, world, ...)
      local result = originalOnMapEntered(game, world, ...)
      if not stockShouldSpawn(game, world) and world then
        local follower = world.follower
        for i = #(world.npcs or {}), 1, -1 do
          if world.npcs[i] == follower then table.remove(world.npcs, i) end
        end
        for i = #(world.entities or {}), 1, -1 do
          if world.entities[i] == follower then table.remove(world.entities, i) end
        end
        world.follower = nil
      end
      return result
    end
  end
end
