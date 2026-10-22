local root=os.getenv('SILVERSHADOW_ENGINE')or'../engine'
package.path=root..'/?.lua;'..package.path
local canvas={}
local rects={};local shifted=0
love={graphics={newCanvas=function()end,getCanvas=function()return canvas end,
 rectangle=function(...)rects[#rects+1]={...}end,getColor=function()return 0,0,0,1 end,
 translate=function(x,y)shifted=shifted+y end}}
local g=love.graphics
local nativeRectangle=g.rectangle
local menu=false;local fail=false;local playing=true
local renderer={canvas=canvas,setUISize=function(self,w,h)self.w,self.h=w,h end,
 beginFrame=function()end}
local battle={isActive=function()return playing end,draw=function()
 g.rectangle('fill',0,0,240,80);g.rectangle('fill',0,80,240,80)
end}
local display={present=function()
 renderer:setUISize(240,160);renderer.uiFill=false;renderer:beginFrame()
 battle.draw({},240,160)
 if fail then error('intentional rendering failure')end
 return true
end}
local chrome={drawTerrain=function()end,drawPanel=function()end,
 menuFrameRects=function()return {{1,15,18,4},{21,15,8,4}}end}
local coords={idOf=function(k)return k end,coords=function()return{x=176,y=40}end}
local ui={bounceOffset=function()return 0 end}
package.loaded['src.core.game3.display']=display
package.loaded['src.render.Renderer']=renderer
package.loaded['src.core.game3.battle']=battle
package.loaded['src.ui.game3.battle_chrome']=chrome
package.loaded['src.core.game3.battle.ui']=ui
package.loaded['src.core.game3.battle.anim']={stage=function()return {}end}
package.loaded['src.core.game3.battle.anim_coords']=coords
package.loaded['src.core.game3.battle.healthbox']={draw=function()end}
package.loaded['src.ui.game3.screens']={get=function()return{isOpen=function()return menu end}end}
package.loaded['src.ui.game3.help_system']={isOpen=function()return false end}
local shared={bool=function()return true end}
assert(loadfile('modules/gen3_battle_presentation.lua'))({},shared)
assert(display.present({}))
assert(renderer.w==256 and renderer.h==192 and renderer.uiFill)
assert(shifted==32 and g.rectangle==nativeRectangle)
assert(rects[1][2]==-8 and rects[1][3]==-32 and rects[1][4]==256 and rects[1][5]==96)
assert(rects[2][2]==-8 and rects[2][3]==64 and rects[2][4]==256 and rects[2][5]==96)
menu=true;rects={};shifted=0
assert(display.present({}))
assert(renderer.w==240 and renderer.h==160 and not renderer.uiFill and shifted==0)
assert(rects[1][2]==0 and rects[1][4]==240)
menu=false;fail=true
local ok=pcall(display.present,{})
assert(not ok and g.rectangle==nativeRectangle and not shared.gen3BattlePresentation.active())
playing=false;fail=false;shifted=0
assert(display.present({})and renderer.w==240 and shifted==0)
print('PASS Gen3 4:3 geometry: full wipe coverage, native menu takeover, field isolation and error cleanup')
