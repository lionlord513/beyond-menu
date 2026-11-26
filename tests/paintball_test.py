from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
class PaintballTests(unittest.TestCase):
 def setUp(self):
  self.lua=LuaRuntime(unpack_returned_tuples=True)
  self.lua.globals().P=self.lua.execute((ROOT/'mod/BeyondMenu/Scripts/paintball/physics.lua').read_text())
 def check(self,code): self.lua.execute(code)
 def test_swept_collision(self):
  self.check('''local b=P.launch(P.v(0,0,0),P.v(1,0,0),{1,0,0},1)
   local hit=P.advance(b,.1,function(a,z,r) if a.X<=10 and z.X>=10 then return {at=P.v(10,0,0)} end end)
   assert(hit and b.at.X==10,'Fast paintballs passed through a thin wall')''')
 def test_ballistic_drop_and_drag(self):
  self.check('''local b=P.launch(P.v(0,0,0),P.v(1,0,0),{1,0,0},1)
   for i=1,10 do P.advance(b,.05,function()end)end
   assert(b.at.Z< -100 and b.at.Z> -140);assert(b.velocity.X<P.speed and b.velocity.X>6000)''')
 def test_conservation_and_slope(self):
  self.check('''local wall=P.impact(P.v(0,0,0),P.v(1,0,0),{1,0,0},42)
   local floor=P.impact(P.v(0,0,0),P.v(0,0,1),{1,0,0},42)
   for i=1,9 do P.accumulate(wall,{0,0,1});P.accumulate(floor,{0,0,1})end
   assert(wall.volume==10 and math.abs(wall.color[1]-.1)<1e-9 and math.abs(wall.color[3]-.9)<1e-9)
   assert(wall.drip>0 and wall.pool==0);assert(floor.pool>0 and floor.drip==0)''')
 def test_geometry_valid_unique_deterministic(self):
  self.check('''local seen={}
   for seed=1,100 do
    local p=P.impact(P.v(0,0,0),P.v(0,0,1),{1,.2,.1},seed);local g=P.geometry(p,4);local again=P.geometry(p,4)
    local signature='';for i=2,8 do signature=signature..('%0.4f,'):format(g.vertices[i].X);assert(g.vertices[i].X==again.vertices[i].X)end
    assert(not seen[signature]);seen[signature]=true
    for _,n in ipairs(g.triangles)do assert(n>=0 and n<#g.vertices and n%1==0)end
    assert(#g.triangles%3==0 and #g.vertices==#g.normals)
   end''')
 def test_snapshot_roundtrip_and_reject_damage(self):
  self.lua.globals().ROOT=str(ROOT/'mod/BeyondMenu').replace('\\','/')
  self.check('''RegisterHook=function()return 1,2 end
   local B={root=ROOT,valid=function()return false end}
   local J=dofile(ROOT..'/Scripts/paintball/journal.lua')(B,P)
   J.items['11111111:22222222:33333333:44444444']={kind='pod',count=50,color={.1,.2,.3}}
   local p=P.impact(P.v(123,456,789),P.v(0,0,1),{.1,.2,.3},1234);p.owner='g:abc';p.component='some%09component';p.bone='None';J.marks={p}
   local encoded=J.encode();local items,marks=J.decode(encoded);assert(#marks==1 and marks[1].component==p.component and marks[1].at.Z==789)
   J.items=items;J.marks=marks;assert(encoded==J.encode())
   marks[1].angle=-1.5;marks[1].imprints={{x=-6.3,y=11,radius=3.9,seed=4294967295}}
   local extended=J.encode();local _,reloaded=J.decode(extended);assert(reloaded[1].angle==-1.5 and reloaded[1].imprints[1].seed==4294967295)
   assert(not pcall(J.decode,encoded:gsub('\\t50\\t','\\t51\\t')))
   assert(not pcall(J.decode,'print(123)'))''')
 def test_overlapping_shots_build_visible_wet_paint(self):
  self.check('''local floor=P.impact(P.v(0,0,0),P.v(0,0,1),{1,0,0},19)
   local nearby=P.impact(P.v(9,0,.2),floor.normal,{0,0,1},20)
   assert(P.depositOffset(floor,nearby));assert(not P.depositOffset(floor,nearby,P.v(4,4,4)))
   nearby.at.Z=5;assert(not P.depositOffset(floor,nearby));nearby.at.Z=.2;floor.wet=60;assert(not P.depositOffset(floor,nearby))
   P.accumulate(floor,nearby.color);assert(floor.pool>=floor.radius+4 and floor.drip==0)
   local wall=P.impact(P.v(0,0,0),P.v(0,1,0),{1,0,0},21)
   P.accumulate(wall,{0,0,1});assert(wall.drip>=wall.radius+8 and wall.pool==0)''')

if __name__=='__main__':unittest.main(verbosity=2)
