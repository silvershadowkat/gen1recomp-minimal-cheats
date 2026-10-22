"""Build fixed habitat/progression placements from the user's imported metadata.
No ROM graphics, sounds, scripts, or moves are copied into the mod.
"""
from pathlib import Path
import sys, zlib, json, statistics, argparse
from lupa.luajit21 import LuaRuntime
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine",type=Path,required=True,help="Engine checkout with imported game metadata")
args=parser.parse_args()
ENGINE=args.engine.resolve()
REPO=Path(__file__).resolve().parents[1]
L=LuaRuntime()
def read(p):
    b=p.read_bytes()
    try: b=zlib.decompress(b)
    except zlib.error: pass
    return L.execute(b.decode("utf8"))
def walk(t):
    if not hasattr(t,"items"): return
    yield t
    for _,v in t.items():
        if hasattr(v,"items"): yield from walk(v)
PK=ENGINE/"firered/data/generated/gba/pokemon"
national=read(PK/"national.lua")
names=read(PK/"names.lua")
types=read(PK/"types.lua")
raw=read(PK/"pokedex/categories.lua")
groups={k:[[national["toNational"][sp] for _,sp in page.items()] for _,page in pages.items()] for k,pages in raw.items()}
habitats={n:k for k,pages in groups.items() for page in pages for n in page}
legends=set([144,145,146,150,151,243,244,245,249,250,251,*range(377,387)])
source={}
for version in ["gold","silver","crystal","ruby","sapphire","emerald"]:
    root=ENGINE/version/"data/generated"
    gen2=version in ["gold","silver","crystal"]
    defs=read(root/"pokemon.lua") if gen2 else None
    encounter=read(root/("encounters.lua" if gen2 else "gba/encounters.lua"))
    # Gen 2's imported timeFishGroups also contains unused raw ROM entries
    # (including impossible species/level pairs). Use ordinary walking/Surf
    # tables for progression rather than treating every imported row as active.
    normal=[encounter["grass"],encounter["water"]] if gen2 else [encounter]
    for row in (row for table in normal for row in walk(table)):
        sp=row["species"]
        level=row["level"] or row["minLevel"]
        if sp is None or not isinstance(level,(int,float)) or not 1<=level<=100: continue
        n=defs[sp]["dex"] if gen2 and defs[sp] else national["toNational"][sp] if not gen2 else None
        if n: source[n]=min(source.get(n,100),int(level))
# For species without a normal wild appearance, infer a reasonable evolution
# level rather than placing a final evolution on a starter route.
evos=read(PK/"evolutions.lua")
for _ in range(4):
    for sp,entries in evos.items():
        parent=national["toNational"][sp]
        for _,e in entries.items():
            target=national["toNational"][e["target"] or e[3]]
            method=e["method"] or e[1]
            param=e["param"] or e[2]
            if target and target not in source:
                if method in [4,8,9,10,11,12,13,14]: level=param
                elif method in [5,6]: level=40
                else: level=max(20,source.get(parent,5)+15)
                source[target]=min(60,max(2,level or 20))
for n in [1,4,7,152,155,158,252,255,258]: source[n]=5
for n in range(1,387): source.setdefault(n,5)
dest={
 "frlg":{
  "grassland":["ROUTE_1","ROUTE_2","ROUTE_3","ROUTE_5","ROUTE_8","ROUTE_14","ROUTE_23"],
  "forest":["VIRIDIAN_FOREST","ROUTE_6","ROUTE_25","ROUTE_15"],
  "waters_edge":["ROUTE_22","ROUTE_6","ROUTE_12","ROUTE_24","ROUTE_25"],
  "sea":["ROUTE_19","ROUTE_20","ROUTE_21_NORTH","SEAFOAM_ISLANDS_B3F"],
  "cave":["MT_MOON_1F","MT_MOON_B2F","ROCK_TUNNEL_B1F","VICTORY_ROAD_1F"],
  "mountain":["MT_MOON_1F","ROUTE_9","ROCK_TUNNEL_1F","VICTORY_ROAD_1F"],
  "rough_terrain":["ROUTE_3","ROUTE_9","ROUTE_10","ROUTE_23"],
  "urban":["ROUTE_5","ROUTE_7","POWER_PLANT","POKEMON_MANSION_1F"],
  "fire":["ROUTE_7","ROUTE_8","POKEMON_MANSION_1F","MT_EMBER_EXTERIOR"],
  "ice":["SEAFOAM_ISLANDS_B3F"],"ghost":["POKEMON_TOWER_3F","POKEMON_TOWER_5F","FIVE_ISLAND_LOST_CAVE_ROOM1"],
  "legend":["CERULEAN_CAVE_B1F"],
 },
 "johto":{
  "grassland":["ROUTE_29","ROUTE_32","ROUTE_35","ROUTE_38","ROUTE_43","SILVER_CAVE_OUTSIDE"],
  "forest":["ILEX_FOREST","NATIONAL_PARK","ROUTE_30","ROUTE_37"],
  "waters_edge":["ROUTE_30","ROUTE_32","ROUTE_35","ROUTE_42","ROUTE_44"],
  "sea":["ROUTE_40","ROUTE_41","WHIRL_ISLAND_SW"],
  "cave":["DARK_CAVE_VIOLET_ENTRANCE","MOUNT_MORTAR_1F_OUTSIDE","ICE_PATH_1F"],
  "mountain":["ROUTE_45","MOUNT_MORTAR_1F_INSIDE","ROUTE_46"],
  "rough_terrain":["ROUTE_33","ROUTE_44","ROUTE_45"],
  "urban":["BURNED_TOWER_1F","ROUTE_34","ROUTE_38"],
  "fire":["BURNED_TOWER_B1F"],"ice":["ICE_PATH_1F"],"ghost":["BURNED_TOWER_1F"],
  "legend":["SILVER_CAVE_ROOM_2"],
 },
 "rse":{
  "grassland":["ROUTE101","ROUTE102","ROUTE110","ROUTE117","ROUTE120","ROUTE121"],
  "forest":["PETALBURG_WOODS","ROUTE104","ROUTE119","ROUTE123"],
  "waters_edge":["ROUTE102","ROUTE114","ROUTE117","ROUTE120"],
  "sea":["ROUTE105","ROUTE109","ROUTE124","ROUTE125"],
  "cave":["GRANITE_CAVE_B1F","METEOR_FALLS_1F_1R","SHOAL_CAVE_LOW_TIDE_INNER_ROOM"],
  "mountain":["GRANITE_CAVE_1F","FIERY_PATH","JAGGED_PASS","VICTORY_ROAD_1F"],
  "rough_terrain":["ROUTE111","ROUTE113","ROUTE114"],
  "urban":["ROUTE110","NEW_MAUVILLE_INSIDE","MT_PYRE_1F"],
  "fire":["FIERY_PATH","JAGGED_PASS"],"ice":["SHOAL_CAVE_LOW_TIDE_ICE_ROOM"],
  "ghost":["MT_PYRE_1F"],"legend":["SKY_PILLAR_1F"],
 },
}
bird=set([16,17,18,21,22,83,84,85,163,164,177,178,198,276,277,333,334])
homes={}
for family,locations in dest.items():
    version={"frlg":"firered","johto":"crystal","rse":"emerald"}[family]
    p=ENGINE/version/"data/generated"
    enc=read(p/("encounters.lua" if family=="johto" else "gba/encounters.lua"))
    roster={}
    for n in range(1,252 if family=="johto" else 387):
        habitat=habitats[n]
        terrain="water" if habitat in ["sea","waters_edge"] else "land"
        sp=national["toSpecies"][n]
        typ=types[sp]
        ts=set(v for _,v in typ.items()) if hasattr(typ,"items") else set()
        if habitat=="rare": habitat="cave"
        if n in bird: habitat="grassland";terrain="land"
        if n in [280,281,282]: habitat="grassland";terrain="land"
        if terrain=="land":
            if 7 in ts: habitat="ghost"
            elif 15 in ts: habitat="ice"
            elif 10 in ts: habitat="fire"
        if n in legends: habitat="legend";terrain="land"
        candidates=[]
        maps=["SEAFOAM_ISLANDS_B3F"] if family=="frlg" and terrain=="water" and 15 in ts else locations[habitat]
        for mapid in maps:
            group=enc["water" if terrain=="water" else "grass"][mapid] if family=="johto" else enc[mapid] and enc[mapid][terrain]
            assert group is not None,(family,mapid,terrain)
            levels=[int(r["level"] or r["minLevel"]) for r in walk(group) if r["species"] is not None and (r["level"] or r["minLevel"])]
            assert levels,(family,mapid,terrain,"empty")
            center=statistics.median(levels)
            # Early freshwater species still inhabit early ponds even where
            # the original Surf encounter table happens to have high levels.
            if terrain=="water" and habitat=="waters_edge":
                rank=locations[habitat].index(mapid)
                center=[5,12,20,28,35][rank]
            candidates.append((abs(source[n]-center),mapid,min(levels),max(levels)))
        candidates.sort()
        best=[c for c in candidates if c[0]==candidates[0][0]]
        _,mapid,low,high=best[n%len(best)]
        # Don't turn an evolved species into a level-3 novelty merely because
        # its habitat has few destination maps. Preserve its native first level.
        low=max(low,min(65,source[n]))
        high=max(high,low+2)
        # Starter families use early appropriate terrain, not a late fire room.
        if family=="frlg" and n in [152,155,252,255]:
            mapid={152:"ROUTE_2",155:"ROUTE_3",252:"VIRIDIAN_FOREST",255:"ROUTE_3"}[n];low,high=4,7
        if n in legends: low,high=50,70
        roster[n]={"map":mapid,"terrain":terrain,"minLevel":low,"maxLevel":high,"legendary":n in legends}
    homes[family]=roster
lines=["-- Fixed habitat/progression placements; National Dex IDs, never internal IDs.",
       "-- Early-route species use early routes; aquatic species use water.",
       "local _,S=...","S.collectionHomes={"]
for family,roster in homes.items():
    lines.append("  "+family+"={")
    for n,h in roster.items():
        lines.append('    [%d]={map="%s",terrain="%s",minLevel=%d,maxLevel=%d%s},'%(
          n,h["map"],h["terrain"],h["minLevel"],h["maxLevel"],",legendary=true" if h["legendary"] else ""))
    lines.append("  },")
lines+=["}",'''function S.collectionMapId(map)
  return tostring(map or ""):gsub("^FR_",""):gsub("^LG_",""):gsub("^RU_","")
    :gsub("^SA_",""):gsub("^EM_",""):gsub("ROUTE_(%d)","ROUTE%1")
end
function S.collectionAddedSpecies(family,map,terrain,present,max)
  local list={}
  map=S.collectionMapId(map)
  for nat=1,max do
    local h=S.collectionHomes[family][nat]
    -- Give every Johto/Hoenn species a Kanto home after the native unlock,
    -- including species also found on the Sevii Islands.
    if h and (h.legendary or not present[nat] or (family=="frlg" and nat>151))
        and S.collectionMapId(h.map)==map and (not terrain or h.terrain==terrain)then
      list[#list+1]=nat
    end
  end
  return list
end''']
(REPO/"modules/collection_habitats.lua").write_text("\n".join(lines)+"\n",encoding="utf8")
print("Built fixed placements:",{k:len(v) for k,v in homes.items()})
print("FRLG examples:",{n:homes["frlg"][n]["map"] for n in [152,161,163,252,261,263,270,280,382]})
