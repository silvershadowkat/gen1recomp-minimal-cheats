local calls={}
local source={ww=640,wh=480,pw=1280,ph=960,vx=0,vy=0,vux=0,vuy=0,vuw=640,vuh=480,
  dpiX=2,dpiY=2,uiw=160,uih=144,Up=960/144,Ux=960/144/2,Uy=960/144/2,lift=0}
local R={canvas={},uiFill=true,frameRects=function()
  local r={};for k,v in pairs(source)do r[k]=v end;return r
end,blitCanvas=function(...)calls[#calls+1]={...};return 'native'end}
local Intro,Title,Yellow={},{},{}
local state=setmetatable({phase=3},Intro)
local game={stack={states={state}}}
local active={name='retro-v3.slangp'}
local locked=false
package.loaded['src.render.Renderer']=R
package.loaded['src.render.ShaderFX']={activeEntry=function()return active end}
package.loaded['src.core.Game']=game
package.loaded['src.ui.IntroMovie']=Intro
package.loaded['src.ui.TitleState']=Title
package.loaded['src.ui.YellowIntro']=Yellow
package.loaded['src.core.FaithfulRes']={scaleCap=function()return locked end}
love={graphics={newCanvas=function()end}}
assert(loadfile('modules/boot_presentation.lua'))({}, {generation=1})
local r=R:frameRects()
assert(r.Up==6 and r.Ux==3 and r.Uy==3)
assert(r.uox==80 and r.uoy==24 and r.uvpw==480 and r.uvph==432)
assert(source.Up==960/144,'original geometry mutated')
local zones={};local result=R:blitCanvas(R.canvas,3,3,zones,3,3,80,24,80,24,480,432,2,2)
assert(result=='native' and #calls==3)
assert(calls[1][10]==0 and calls[1][11]==0 and calls[1][12]==640 and calls[1][13]==120)
assert(calls[2][10]==0 and calls[2][11]==360 and calls[2][12]==640 and calls[2][13]==120)
assert(calls[1][5]==zones and calls[2][5]==zones,'intro fade palettes lost')
locked=true;calls={};R:blitCanvas(R.canvas,3,3,zones,3,3,80,24)
assert(#calls==1,'faithful viewport changed')
locked=false;setmetatable(state,Title);calls={};R:blitCanvas(R.canvas,3,3,zones,3,3,80,24)
assert(#calls==1 and R:frameRects().Up==6,'title inherited intro bands')
setmetatable(state,Yellow);assert(R:frameRects().Up==6)
setmetatable(state,{});assert(R:frameRects().Up==source.Up,'world geometry changed')
setmetatable(state,Title);active={name='other.slangp'}
assert(R:frameRects().Up==source.Up,'another preset changed')
local shared={};assert(loadfile('modules/type_colors.lua'))({},shared)
local types={'NORMAL','FIGHTING','FLYING','POISON','GROUND','ROCK','BUG','GHOST','STEEL',
  'UNKNOWN','FIRE','WATER','GRASS','ELECTRIC','PSYCHIC','ICE','DRAGON','DARK'}
for i,name in ipairs(types)do
  assert(shared.moveTypeColor(i-1)==shared.moveTypeColor(name))
  assert(shared.moveTypeColor(name..'_TYPE')==shared.moveTypeColor(name))
end
assert(shared.moveTypeColor('STEEL')~=shared.moveTypeColor('NORMAL'))
print('PASS boot: integer source pixels, full-width native fade bands, isolated title/Yellow/world/other shaders; shared type palette')
