local mod, shared = ...

shared.registerStartItem("boxes", 10, function(game)
  return {
    label = "BOXES",
    onSelect = function()
      mod.ui.push(game, "Gen2PcMenu", {
        onClose = function() game.stack:pop() end,
      })
    end,
  }
end)
