"""Validate every fixed destination against all eight imported Gen 2/3 games."""
from pathlib import Path
import argparse, zlib
from lupa.luajit21 import LuaRuntime

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine",type=Path,required=True)
args=parser.parse_args()
lua=LuaRuntime()
shared=lua.table()
source=Path(__file__).resolve().parents[1]/"modules/collection_habitats.lua"
lua.execute(source.read_text(encoding="utf8"),None,shared)
def read(path):
    data=path.read_bytes()
    try: data=zlib.decompress(data)
    except zlib.error: pass
    return lua.execute(data.decode("utf8"))
for version in ["gold","silver","crystal","firered","leafgreen","ruby","sapphire","emerald"]:
    family="johto" if version in ["gold","silver","crystal"] else "frlg" if version in ["firered","leafgreen"] else "rse"
    gen2=family=="johto"
    root=args.engine/version/"data/generated"
    tables=read(root/("encounters.lua" if gen2 else "gba/encounters.lua"))
    roster=shared.collectionHomes[family]
    count=251 if gen2 else 386
    assert len(roster)==count,(version,"incomplete species coverage")
    for nat in range(1,count+1):
        row=roster[nat]
        assert row and 1<=row.minLevel<=row.maxLevel<=100,(version,nat,"invalid level")
        group=tables["water" if row.terrain=="water" else "grass"][row.map] if gen2 else tables[row.map] and tables[row.map][row.terrain]
        assert group and group.slots,(version,nat,row.map,"missing native encounter terrain")
        if gen2 and row.terrain=="land":
            assert any(rate>0 for _,rate in group.rates.items()),(version,nat,"zero encounter rate")
        else:
            assert (group.rate or 0)>0,(version,nat,"zero encounter rate")
        if family=="frlg" and row.legendary:
            assert row.map=="CERULEAN_CAVE_B1F",(version,nat,"legendary outside endgame cave")
    print(version+": "+str(count)+" species destinations valid")
