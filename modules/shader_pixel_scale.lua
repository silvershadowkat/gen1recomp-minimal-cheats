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
local depth=0
FX.render=function(...)
 if depth>0 then return render(...)end
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
 local ok,err=pcall(render,...)
 depth=depth-1
 love.graphics.newCanvas=create
 if not ok then error(err,0)end
end
