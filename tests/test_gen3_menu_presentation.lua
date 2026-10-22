local canvas={};local draws,clip={},nil;local enabled=true;local menu=true;local fail=false
local tx,ty=0,0
local rectangles={}
local image={getDimensions=function()return 240,160 end}
local g={newCanvas=function()end,getCanvas=function()return canvas end,
 newQuad=function(...)return {...}end,origin=function()tx,ty=0,0 end,
 translate=function(x,y)tx,ty=tx+x,ty+y end,
 draw=function(img,q,x,y)draws[#draws+1]={q,x,y}end,
 getColor=function()return 0,0,0,1 end,
 rectangle=function(...)rectangles[#rectangles+1]={...}end,setScissor=function(...)clip={...}end,
 getScissor=function()if clip then return unpack(clip)end end,
 intersectScissor=function(...)clip={...}end}
love={graphics=g}
local original={origin=g.origin,draw=g.draw,rectangle=g.rectangle,setScissor=g.setScissor,
 getScissor=g.getScissor,intersectScissor=g.intersectScissor}
local renderer={canvas=canvas,setUISize=function(self,w,h)self.w,self.h=w,h end,
 beginFrame=function()end,endFrame=function()g.origin();assert(tx==0 and ty==0)end}
local display={present=function()
 renderer:setUISize(240,160);renderer.uiFill=false;renderer:beginFrame()
 g.origin();g.draw(image,0,1)
 g.rectangle('fill',0,0,240,80);g.rectangle('fill',0,80,240,80)
 g.intersectScissor(20,24,64,16)
 if menu and enabled then
  assert(tx==8 and ty==16 and clip[1]==28 and clip[2]==40,'native text clip missed its translation')
  local x,y=g.getScissor();assert(x==20 and y==24)
 end
 if fail then error('intentional draw failure')end
 renderer:endFrame();return true
end}
package.loaded['src.core.game3.display']=display
package.loaded['src.render.Renderer']=renderer
package.loaded['src.ui.game3.screens']={get=function(name)return{isOpen=function()return name~='summary'and menu end}end}
assert(loadfile('modules/gen3_menu_presentation.lua'))({},{gameVersion='ruby',bool=function()return enabled end})
assert(display.present({})and renderer.w==256 and renderer.h==192 and renderer.uiFill)
assert(#draws>1,'Ruby background at y=1 was not extended')
assert(rectangles[1][2]==-8 and rectangles[1][3]==-16 and rectangles[1][4]==256 and rectangles[1][5]==96)
assert(rectangles[2][3]==80 and rectangles[2][5]==96,'closed wipe leaves a strip uncovered')
for k,v in pairs(original)do assert(g[k]==v,'graphics override leaked: '..k)end
fail=true;assert(not pcall(display.present,{}))
for k,v in pairs(original)do assert(g[k]==v,'failed draw leaked: '..k)end
fail=false;menu=false;draws={};assert(display.present({})and renderer.w==240 and #draws==1)
print('PASS Gen3 menu: background extension, native text clipping, world isolation and error cleanup')
