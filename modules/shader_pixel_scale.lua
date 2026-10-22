-- Gen1Recomp 0.3.91 sizes ShaderFX crops and pass targets in source/output
-- pixels. LOVE otherwise inherits the window DPI (2 on Nova), doubling those
-- textures and then resampling them on the final blit. LCD phase boundaries
-- become inconsistent across the two triangles used to draw the image.
-- Limit this override to the synchronous ShaderFX render, restoring it even
-- on failure. Gameplay/world/UI canvases retain their original DPI handling.
local FX=require('src.render.ShaderFX')
if FX._silverPixelScale then return end
FX._silverPixelScale=true
-- retro-v3 slightly stretches UVs (1.0001) to avoid an edge in its original
-- host. Here that shifts the LCD phase across the screen and thins grid lines.
-- Correct the loaded translation, including cached presets, without rewriting
-- user shader files or changing coordinates for any other preset.
local load=FX.load
FX.load=function(entry,...)
 local state,err=load(entry,...)
 if state and entry.name=='retro-v3.slangp' then
  for _,pass in ipairs(state.preset.passes)do
   if type(pass.vertex)=='string'then
    pass.vertex=pass.vertex:gsub('TexCoord%s*%*%s*(1%.%d+)',function(scale)
     if scale=='1.0001'or scale=='1.00010001659393310546875'then return 'TexCoord'end
     return 'TexCoord * '..scale
    end)
   end
  end
 end
 return state,err
end
local render=FX.render
local function alignedRender(canvas,rect,source,...)
 -- Fill layouts (including the 304x228 custom battle) can use fractional
 -- physical scales. A hard LCD mask cannot repeat evenly at 4.2105 pixels.
 -- Give retro-v3 the nearest whole-pixel sampling lattice; keep the output
 -- rectangle unchanged and leave integer-scaled overworld frames untouched.
 local entry=FX.activeEntry and FX.activeEntry('main')
 local s=rect and tonumber(rect.scale)
 if entry and entry.name=='retro-v3.slangp'and s and s>=1 and s~=math.floor(s) then
  local r,src={},{}
  for k,v in pairs(rect)do r[k]=v end
  for k,v in pairs(source)do src[k]=v end
  r.scale=math.max(1,math.floor(s+.5))
  src.w,src.h=r.w/r.scale,r.h/r.scale
  return render(canvas,r,src,...)
 end
 return render(canvas,rect,source,...)
end
local depth=0
FX.render=function(...)
 if depth>0 then return alignedRender(...)end
 local create=love.graphics.newCanvas
 love.graphics.newCanvas=function(w,h,settings,...)
  if type(w)=='number'and type(h)=='number'then
   local opts={}
   for k,v in pairs(settings or {})do opts[k]=v end
   opts.dpiscale=1
   return create(w,h,opts,...)
  end
  return create(w,h,settings,...)
 end
 depth=depth+1
 local ok,err=pcall(alignedRender,...)
 depth=depth-1
 love.graphics.newCanvas=create
 if not ok then error(err,0)end
end
