local mod = ...
local T = {}

function T.shiftCell(cell, dx, dy)
  if not cell then return end
  cell.x, cell.y = cell.x + dx, cell.y + dy
end

function T.restore(world, followers, dx, dy)
  local function include(list, npc)
    for _, item in ipairs(list) do if item == npc then return end end
    list[#list + 1] = npc
  end
  for _, npc in ipairs(followers or {}) do
    npc.mapId = world.map.id
    npc.cellX, npc.cellY = npc.cellX + dx, npc.cellY + dy
    npc.px, npc.py = npc.px + dx * 16, npc.py + dy * 16
    for _, key in ipairs({ "targetX", "goalX" }) do
      if npc[key] then npc[key] = npc[key] + dx end
    end
    for _, key in ipairs({ "targetY", "goalY" }) do
      if npc[key] then npc[key] = npc[key] + dy end
    end
    -- Keep the same entity and animation clock across the seam.
    include(world.npcs, npc)
    include(world.entities, npc)
  end
end

function T.stack(anchor, count)
  local cells = {}
  for i = 1, count do cells[i] = { x = anchor.cellX, y = anchor.cellY } end
  return cells
end

mod.exports.followerTransitions = T
