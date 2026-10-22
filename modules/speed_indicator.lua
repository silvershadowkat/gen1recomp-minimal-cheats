-- Window-space status, after scene scaling and LCD shaders in every generation.
local _, S = ...
local Game = require(S.generation == 3 and "src.core.Game3"
  or S.generation == 2 and "src.core.Game2" or "src.core.Game")
local glyphs = {
  ["0"]={"111","101","101","101","111"},
  ["1"]={"010","110","010","010","111"},
  ["2"]={"111","001","111","100","111"},
  ["3"]={"111","001","111","001","111"},
  ["4"]={"101","101","111","001","001"},
  ["5"]={"111","100","111","001","111"},
  ["6"]={"111","100","111","101","111"},
  ["7"]={"111","001","010","010","010"},
  ["8"]={"111","101","111","101","111"},
  ["9"]={"111","101","111","001","111"},
  ["."]={"000","000","000","000","010"},
  ["x"]={"000","101","010","101","000"},
}
local function label(game)
  return string.format("%.2f", game:logicSpeed()):gsub("0+$", ""):gsub("%.$", "") .. "x"
end
local function draw(game)
  local g = love.graphics
  local text = label(game)
  local dpi = g.getDPIScale and g.getDPIScale() or 1
  -- Whole physical pixels keep the tiny bitmap sharp even at fractional DPI.
  local pixel = math.max(1, math.floor(2 * dpi + .5)) / dpi
  local pad, inset = pixel * 2, pixel * 3
  local w, h = (#text * 4 - 1) * pixel + pad * 2, 5 * pixel + pad * 2
  local x = math.floor((g.getWidth() - inset - w) * dpi) / dpi
  local y = inset
  g.push("all")
  g.origin(); g.setShader(); g.setScissor(); g.setBlendMode("alpha")
  g.setColor(0, 0, 0, .35); g.rectangle("fill", x, y, w, h)
  g.setColor(1, 1, 1, 1)
  for i = 1, #text do
    for row, bits in ipairs(glyphs[text:sub(i, i)] or glyphs["x"]) do
      for col = 1, 3 do
        if bits:sub(col, col) == "1" then
          g.rectangle("fill", x + pad + ((i - 1) * 4 + col - 1) * pixel,
            y + pad + (row - 1) * pixel, pixel, pixel)
        end
      end
    end
  end
  g.pop()
end
S.speedIndicator = {label=label, draw=draw}
local original = Game.draw
Game.draw = function(self, ...)
  original(self, ...)
  draw(self)
end
