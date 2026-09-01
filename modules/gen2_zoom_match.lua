local mod, shared = ...

-- Gen 1 computes its zoom ladder in physical framebuffer pixels. Gen 2's
-- playfield dimensions are logical LÖVE units, so subtracting one whole unit
-- for OUT1 becomes a two-physical-pixel jump on a 2x-density Android screen.
-- Scale the offset by the display density so each named step has the same
-- physical size in both generations. FIT remains exactly native Gen 2.
local function matchedScale(fit, offset, dpi, original)
  fit = math.max(1, tonumber(fit) or 1)
  offset = tonumber(offset) or 0
  dpi = math.max(1, tonumber(dpi) or 1)
  if offset == 0 or dpi == 1 then return original end
  return math.max(0.25, fit + offset / dpi)
end

local function displayDensity()
  if love and love.window and love.window.getDPIScale then
    local ok, dpi = pcall(love.window.getDPIScale)
    dpi = tonumber(dpi)
    if ok and dpi and dpi >= 1 then return dpi end
  end
  if love and love.graphics and love.graphics.getDimensions
      and love.graphics.getPixelDimensions then
    local okLogical, lw = pcall(love.graphics.getDimensions)
    local okPhysical, pw = pcall(love.graphics.getPixelDimensions)
    lw, pw = tonumber(lw), tonumber(pw)
    if okLogical and okPhysical and lw and pw and lw > 0 then
      return math.max(1, pw / lw)
    end
  end
  return 1
end

shared.gen2MatchedZoomScale = matchedScale

local okWorld, World = pcall(require, "src.world.gen2.World")
local okZoom, Zoom = pcall(require, "src.render.Zoom")
if okWorld and okZoom and type(World) == "table"
    and type(World.zoomScale) == "function"
    and not World._silverShadowPhysicalZoom then
  local originalZoomScale = World.zoomScale
  World.zoomScale = function(self)
    local original = originalZoomScale(self)
    return matchedScale(self:fitScale(), Zoom.offset, displayDensity(), original)
  end
  World._silverShadowPhysicalZoom = true
end
