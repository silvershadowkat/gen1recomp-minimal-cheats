local engineRoot=os.getenv("SILVERSHADOW_ENGINE") or "../engine"
package.path=engineRoot.."/?.lua;"..engineRoot.."/?/init.lua;"..package.path
love=require("tests.love_stub")
local Version=require("src.core.GameVersion")
local version=os.getenv("SILVERSHADOW_GEN3_VERSION") or "firered"
Version.set(version)
require("src.core.Version").engine="0.3.91"
local sdk=require("tests.modkit.sdk")
local Runtime=require("src.mods.Runtime")
local run=sdk.loadMod(os.getenv("SILVERSHADOW_TEST_MOD") or "dist/silvershadow_mods",
  {data=sdk.gen3Data(),root=".",generation=3,dev=true})
assert(#run.errors==0,table.concat(run.errors,"; "))
local shared=assert(run.loader.exports.minimal_cheats).silvershadow
assert(shared.generation==3)
local checks=0
local function eq(a,b,label) assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b));checks=checks+1 end
local function hook(name,base,...) return Runtime.call(name,base,...) end
local function emit(name,e) Runtime.emit(name,e) end
local State=require("src.core.game3.battle.state")
local Adapter=require("src.core.game3.battle.adapter")
local Bag=require("src.core.game3.bag")
local Items=require("src.core.game3.items_data")
Items.installPack({items={[4]={name="POKE BALL",pocket="POKE_BALLS"},[68]={name="RARE CANDY",pocket="ITEMS"}}})
local Field=require("src.core.game3.field")
local Player=require("src.core.game3.player")
local Collision=require("src.core.game3.collision")
local function battler(side,hp)
 return {side=side,mon={species=4,hp=hp,maxHp=100,pp={20,15,10,5},moves={1,2,3,4}}}
end
local p,p2,e=battler("player",80),battler("player",70),battler("enemy",60)
local session={party={p.mon,p2.mon},bag={pockets={POKE_BALLS={{id=4,qty=5}}},stacks={}},map="TEST",x=3,y=3}
local st={player=p,enemy=e,battlers={[0]=p,[1]=e,[2]=p2},double=true,session=session,absent={},turn=1}
local game={session=session,input={isDown=function()return false end}}
shared.game=game; Field._session=session
emit("battle.started",{battle=st})
shared.set("damage_multiplier","OHKO")
eq(hook("battle.damage",function()return 12,{}end,{battle=st,user=p2,target=e}),60,"double ally OHKO")
eq(hook("battle.damage",function()return 12,{}end,{battle=st,user=p,target=p2}),12,"friendly fire not boosted")
shared.set("infinite_hp",true)
local a=Adapter.new(st,function()end)
eq(a:applyHpLoss(p2,500),0,"residual/fixed HP loss prevented")
eq(p2.mon.hp,70,"partner HP preserved")
a:setHp(p,0);eq(p.mon.hp,80,"direct HP loss prevented")
eq(a:applyHpLoss(e,10),10,"enemy still takes damage")
for _,spec in ipairs({{"battle.accuracy","always_hit","user"},{"battle.crit","always_crit","attacker"}}) do
 shared.set(spec[2],true)
 eq(hook(spec[1],function()return false end,{battle=st,[spec[3]]=p2}),true,spec[2])
 eq(hook(spec[1],function()return false end,{battle=st,[spec[3]]=e}),false,"enemy "..spec[2])
end
shared.set("always_first",true)
eq(hook("battle.turn_order",function()return true end,e,nil,p2,nil,{battle=st}),false,"reverse pair order")
eq(hook("battle.turn_order",function()return false end,p,nil,p2,nil,{battle=st}),false,"ally order unchanged")
shared.set("guaranteed_catch",true)
local caught,shakes=hook("catch.rate",function()return false,0 end,"POKE_BALL",e.mon,{}, {battle=st})
eq(caught,true);eq(shakes,4,"Gen 3 shakes")
shared.set("exp_multiplier",8)
eq(hook("exp.gain",function()return 25 end,{battle=st}),200)
shared.set("infinite_pp",true)
emit("battle.turn_started",{battle=st})
p.mon.pp[1]=18;p2.mon.pp[3]=8
emit("battle.move_used",{battle=st,user=p2})
eq(p.mon.pp[1],20);eq(p2.mon.pp[3],10,"partner pressure PP restored")
shared.set("unlimited_balls",true)
eq(Bag.remove(session.bag,4,1),true)
eq(Bag.get(session.bag,4),5,"ball not consumed")
st.link=true
eq(hook("battle.damage",function()return 12,{}end,{battle=st,user=p,target=e}),12,"link damage unchanged")
eq(a:applyHpLoss(p2,10),10,"link HP loss normal")
eq(hook("exp.gain",function()return 25 end,{battle=st}),25,"link EXP normal")
eq(hook("catch.rate",function()return false,0 end,"POKE_BALL",e.mon,{}, {battle=st}),false,"link catch normal")
st.link=false
emit("battle.ended",{battle=st})
eq(Bag.remove(session.bag,4,1),true);eq(Bag.get(session.bag,4),4,"outside battle consumption normal")
shared.gen3Perfect(p.mon)
for _,k in ipairs({"hp","atk","def","spe","spa","spd"}) do eq(p.mon.ivs[k],31,"IV "..k) end
-- Actual map collision and player code: stay in bounds; never save airborne.
Collision._widthCells,Collision._heightCells=8,8
Collision._grid={};for i=1,64 do Collision._grid[i]=0 end
Player.reset(3,3,"down"); Field.locked=false
game.data={maps={TEST={mapType=1,coordEvents={}}}}
shared.set("fly_badge_check",false)
eq(shared.gen3ToggleFly(),true,"take off")
eq(shared.gen3Flying,true)
Player.update(game,{isDown=function(_,key)return key=="right"end})
for i=1,4 do Player.update(game,{isDown=function()return false end}) end
eq(Player.cellX,4,"flight step")
eq(hook("save.write",function()return true end,game),false,"airborne save blocked")
shared.gen3ReturnToGround();eq(Player.cellX,3,"return to takeoff")
eq(shared.gen3Flying,false);eq(hook("save.write",function()return true end,game),true,"landed save allowed")
local def=game.data.maps.TEST
Collision._mapDef=def
eq(shared.gen3FlightReachable({x=3,y=3},5,3),true,"walkable flight landing")
for y=0,7 do def.coordEvents[#def.coordEvents+1]={x=4,y=y,scriptKey="STORY_GATE"}end
eq(shared.gen3FlightReachable({x=3,y=3},5,3),false,"active story trigger barrier")
def.coordEvents={}
for y=0,7 do Collision._warps[y*1024+4]={}end
eq(shared.gen3FlightReachable({x=3,y=3},5,3),false,"flight cannot skip a warp boundary")
Collision._warps={}
eq(shared.gen3FlightReachable({x=3,y=3},5,3),true,"cleared story gate permits landing")
Collision._mapDef=nil
local rows=hook("ui.start_menu.items",function(_,rows)return rows end,game,{})
eq(rows[1].id,"silvershadow","menu entry")
shared.openGen3Options()
eq(require("src.ui.game3.stack").top().id,"silvershadow_gen3","native menu stack")
-- Read-only move previews: no damage roll, RNG consumption or battle mutation.
local Moves=require('src.core.game3.battle.moves')
local oldGet=Moves.get
local rows={
 {id='SCRATCH',power=40,type=0,target=0,pp=35},
 {id='GROWL',power=0,type=0,target=8,pp=40},
 {id='EMBER',power=40,type=10,target=0,pp=25},
 {id='SURF',power=95,type=11,target=8,pp=15},
 {id='HIDDEN_POWER',power=1,type=0,target=0,pp=15},
 {id='WEATHER_BALL',power=50,type=0,target=0,pp=10},
 {id='SEISMIC_TOSS',power=1,type=1,target=0,pp=20},
}
Moves.get=function(i)return assert(rows[i])end
local user={mon={moves={1,2,3,4},hp=20,pp={35,40,25,15}}}
local foe={type1=12,type2=12,mon={hp=20}}
local second={type1=10,type2=10,mon={hp=20}}
local preview={player=user,enemy=foe,battlers={[0]=user,[1]=foe,[3]=second}}
local info=assert(shared.gen3MoveInfo)
eq(info(preview,user,3).effect,'TYPE 2x','Fire into Grass')
eq(info(preview,user,2).effect,'STATUS','Growl is not damaging')
foe.type2=5;eq(info(preview,user,3).effect,'TYPE 1x','dual-type product')
preview.double=true
eq(info(preview,user,3).effect,'PICK FOE','no guessed target in doubles')
eq(info(preview,user,3,3).effect,'TYPE 1/2x','selected right target')
foe.type1,foe.type2=5,5
eq(info(preview,user,4).effect,'TYPE 2x','spread identical matchups')
foe.type1,foe.type2=12,12;eq(info(preview,user,4).effect,'VARIES','spread different matchups')
second.ability='WATER_ABSORB';eq(info(preview,user,4,3).effect,'IMMUNE','absorbing ability')
preview.double=false;foe.type1,foe.type2=7,7
eq(info(preview,user,1).effect,'TYPE 0x','Normal into Ghost')
foe.expIdentified=true;eq(info(preview,user,1).effect,'TYPE 1x','Foresight')
user.mon.moves[1]=5;user.mon.ivs={hp=31,atk=31,def=31,spe=31,spa=31,spd=31}
eq(info(preview,user,1).type,17,'Hidden Power from actual IVs')
user.mon.moves[1]=6;preview.weather='RAIN'
eq(info(preview,user,1).type,11,'Weather Ball in rain')
second.ability='CLOUD_NINE';eq(info(preview,user,1).type,0,'weather suppression')
user.mon.moves[1]=7;eq(info(preview,user,1).effect,'SPECIAL','fixed damage has no false multiplier')
eq(user.mon.hp,20,'preview never changes HP');eq(user.mon.pp[1],35,'preview never spends PP')
Moves.get=oldGet
print("SilverShadow "..version.." engine integration: "..checks.." checks passed")

