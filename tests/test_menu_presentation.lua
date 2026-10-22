local root=os.getenv('SILVERSHADOW_ENGINE')or'../engine'
package.path=root..'/?.lua;'..package.path
local calls={};local fail=false
local function record(kind,... )calls[#calls+1]={kind,...}end
love={graphics={newCanvas=function()end}}
local chrome={playfieldRect=function(w,h)return 0,0,w,h end,
 printThrough=function(s,x,y)record('text',s,x,y)end,
 cursor=function(x,y)record('cursor',x,y)end,cursorThrough=function()end,
 clear=function()record('native-clear')end,paletteFill=function(...)record('fill',...)end,
 box=function(...)record('box',...)end}
chrome.print=function(...)return chrome.printThrough(...)end
local party={drawWidescreen=function()end,drawIcon=function()end,drawHpBar=function()end,
 drawSubmenu=function()chrome.box(11,11,9,7);chrome.print('SWITCH',13,12)end}
party.drawPanel=function(self)
 chrome.clear()
 for i=1,6 do
  chrome.print('NAME',3,1+(i-1)*2);chrome.print('HP',13,1+(i-1)*2)
 end
 chrome.box(0,14,20,4);chrome.print('PROMPT',1,16)
 if fail then error('intentional menu failure')end
 self:drawSubmenu()
end
local pack={drawWidescreen=function()end,drawPanel=function()end}
local game={frameFit=function()return 3,80,24,2,1280,960 end}
package.loaded['src.ui.gen2.Chrome']=chrome
package.loaded['src.ui.gen2.PartyMenu']=party
package.loaded['src.ui.gen2.PackMenu']=pack
package.loaded['src.core.Game2']=game
local on=true
local shared={generation=2,bool=function()return on end}
assert(loadfile('modules/gen2_menu_presentation.lua'))({},shared)
local p=setmetatable({party={}},{__index=party});setmetatable(p,party);party.__index=party
p:drawPanel()
assert(calls[1][4]==256 and calls[1][5]==192)
local lastName,footer,prompt,sub
for _,c in ipairs(calls)do
 if c[1]=='text'and c[2]=='NAME'then lastName=c end
 if c[1]=='box'and c[2]==0 then footer=c end
 if c[1]=='text'and c[2]=='PROMPT'then prompt=c end
 if c[1]=='text'and c[2]=='SWITCH'then sub=c end
end
assert(lastName[4]*8+16<=footer[3]*8,'sixth row overlaps footer')
assert(footer[4]==32 and prompt[4]==22)
assert(sub[3]==25 and sub[4]==18,'submenu not moved as a unit')
local top=p;local instance=setmetatable({stack={top=function()return top end}},{__index=game})
assert(instance:frameFit(640,480)==2.5,'menu shader does not use the drawn 5x lattice')
top={};assert(instance:frameFit(640,480)==3,'world fit changed')
fail=true;assert(not pcall(p.drawPanel,p));calls={};chrome.print('outside',1,2)
assert(calls[1][3]==1 and calls[1][4]==2,'failed menu leaked coordinate remapping')
print('PASS Gen2 menu: six rows fit, footer/submenu bounds, exact LCD fit, world isolation and error cleanup')
