local mod, shared = ...

local function hasLabel(items, label)
  for _, item in ipairs(items or {}) do
    if tostring(item.label or ""):upper() == tostring(label):upper() then return true end
  end
  return false
end

-- One coordinated owner for the shared Start-menu seam.
mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
  local out = next(game, items)
  if type(out) ~= "table" then return out end
  for _, entry in ipairs(shared.sortedStartItems()) do
    local ok, item = pcall(entry.factory, game, out)
    if not ok then
      mod.log:warn("start item %s failed: %s", entry.id, tostring(item))
    elseif item and not hasLabel(out, item.label) then
      mod.ui.insertBefore(out, "SAVE", item)
    end
  end
  return out
end)

-- One coordinated owner for MOVES, DV/EV, HM cleanup and optional FOLLOWER.
mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
  local out = next(game, items, mon, ctx)
  if type(out) ~= "table" then out = items or {} end
  for _, entry in ipairs(shared.sortedPartyDecorators()) do
    local ok, result = pcall(entry.decorate, game, out, mon, ctx)
    if ok and type(result) == "table" then
      out = result
    elseif not ok then
      mod.log:warn("party decorator %s failed: %s", entry.id, tostring(result))
    end
  end
  return out
end)

-- Physical PCs route to the same integrated storage screens as Start -> PC.
mod.hooks:wrap("ui.pc.items", function(next, game, items)
  local out = next(game, items)
  if type(out) ~= "table" then return out end
  if shared.decoratePcItems then return shared.decoratePcItems(game, out) end
  return out
end)
