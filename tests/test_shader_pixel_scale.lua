local calls={}
local original=function(w,h,settings)calls[#calls+1]={w=w,h=h,settings=settings};return calls[#calls]end
love={graphics={newCanvas=original}}
local FX={render=function()
 love.graphics.newCanvas(256,192)
 love.graphics.newCanvas(1280,960,{format='rgba16f',readable=true,dpiscale=2})
end}
local vertex='LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;'
FX.load=function(entry)
 if entry.fail then return nil,'load failed'end
 return {preset={passes={{vertex=entry.vertex or vertex}}}},'preserved'
end
package.loaded['src.render.ShaderFX']=FX
dofile('modules/shader_pixel_scale.lua')
FX.render()
assert(#calls==2 and calls[1].settings.dpiscale==1)
assert(calls[2].settings.dpiscale==1 and calls[2].settings.format=='rgba16f'and calls[2].settings.readable)
assert(love.graphics.newCanvas==original,'canvas constructor leaked outside shader rendering')
love.graphics.newCanvas(20,20,{dpiscale=3})
assert(calls[3].settings.dpiscale==3,'world/UI canvas DPI changed')
local wrapped=FX.render
dofile('modules/shader_pixel_scale.lua')
assert(FX.render==wrapped,'patch installed twice')
local state,note=FX.load({name='retro-v3.slangp'})
assert(state.preset.passes[1].vertex=='LIBRA_VARYING_0 = TexCoord;')
assert(note=='preserved')
state=FX.load({name='retro-v3.slangp',vertex='v = TexCoord * 1.0001;'})
assert(state.preset.passes[1].vertex=='v = TexCoord;')
state=FX.load({name='other.slangp'})
assert(state.preset.passes[1].vertex==vertex,'another preset was changed')
state=FX.load({name='retro-v3.slangp',vertex='v = TexCoord * 1.00015;'})
assert(state.preset.passes[1].vertex=='v = TexCoord * 1.00015;','unrelated scale changed')
state,note=FX.load({name='retro-v3.slangp',fail=true})
assert(state==nil and note=='load failed','load failure not preserved')
FX={render=function()error('intentional test failure')end}
package.loaded['src.render.ShaderFX']=FX
dofile('modules/shader_pixel_scale.lua')
local ok,err=pcall(FX.render)
assert(not ok and tostring(err):find('intentional test failure'))
assert(love.graphics.newCanvas==original,'constructor not restored on failure')
print('PASS shader pixel scale: physical targets, scoped override, error cleanup, exact retro-v3 phase, other presets unchanged')
