from pathlib import Path
import shutil
import tempfile
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
 def test_brush_only_touches_the_contact_surface(self):
  self.check('''local m=P.impact(P.v(0,0,0),P.v(1,0,0),{1,0,0},9)
   local function stroke(offset,n) return P.brushWear(m,offset,m.normal,m.gravity,n,1) end
   assert(stroke(P.v(0,0,0),m.normal)==1)
   assert(not stroke(P.v(0,0,0),P.v(-1,0,0)) and not stroke(P.v(5,0,0),m.normal))
   assert(not stroke(P.v(0,0,-28),m.normal));m.drip=40;assert(stroke(P.v(0,0,-28),m.normal))
   m.remaining=.1;assert(not stroke(P.v(0,0,-28),m.normal))''')
 def test_world_paint_survives_restart_rollback_and_torn_tail(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=Path(tmp);(base/'state').mkdir();shutil.copytree(ROOT/'mod/BeyondMenu/Scripts/paintball',base/'Scripts/paintball')
   self.lua.globals().ROOT=base.as_posix()
   self.check('''RegisterHook=function()return 1,2 end;StaticFindObject=function()return {}end
    local B={root=ROOT,valid=function(o)return o~=nil end};local create=dofile(ROOT..'/Scripts/paintball/journal.lua')
    local function guid(a)return {A=a,B=1,C=3,D=4}end
    local function slot(world,revision)return {IsA=function()return true end,SaveGameMetadata={SaveName={Guid=guid(world),GuidUnique=guid(revision),Iterator=1}}}end
    local old,new,other=slot(15,1),slot(15,2),slot(16,1)
    local function open(s)local j=create(B,P);j.load(s);assert(j.ready);return j end
    local j=open(old);local m=P.impact(P.v(41,3,8),P.v(0,0,1),{.1,.2,.3},25);m.owner='';m.component='WorldOrigin';m.bone='None'
    j.marks[1]=m;j.persist(m);j.capture(old)
    local extra=P.impact(P.v(7,-2,5),P.v(1,0,0),{0,1,0},47);extra.owner='p:fixture';extra.component='Panel';extra.bone='None'
    extra.anchor={class='Panel_C',at=P.v(1e6,2,8),normal=P.v(1,0,0)};j.marks[2]=extra;j.persist(extra)
    j=open(old);assert(#j.marks==2 and j.marks[2].anchor.class=='Panel_C');j.capture(new)
    j.marks[1].remaining=.41;j.persist(j.marks[1]);j.persist(j.marks[2],true);table.remove(j.marks,2)
    j=open(new);assert(#j.marks==1 and j.marks[1].remaining==.41);j.capture(new)
    local key=j.key(old);local path=ROOT..'/state/paint-world-'..key:sub(1,32)..'.log'
    local f=assert(io.open(path,'ab'));f:write('U\\t123\\tP\\tinterrupted');f:close()
    j=open(old);assert(#j.marks==1 and j.marks[1].remaining==.41)
    j.persist(j.marks[1],true);j.marks={};assert(#open(other).marks==0);assert(#open(old).marks==0 and #open(new).marks==0)''')

 def test_middle_tap_holsters_while_drag_hold_and_item_changes_cancel(self):
  self.lua.globals().ROOT=str(ROOT/'mod/BeyondMenu').replace('\\','/')
  self.check('''local now=0
   FName=function(s)return s end
   StaticFindObject=function()return{GetRealTimeSeconds=function()return now end}end
   local gun={GetAddress=function()return 11 end};local other={GetAddress=function()return 12 end}
   local B={root=ROOT,valid=function(v)return v~=nil end,host=function()return true end,ui={},H={IsPauseMenu=function()return false end}}
   local R={isGun=function(v)return v==gun end}
   local I=dofile(ROOT..'/Scripts/paintball/interaction.lua')(B,R)
   local p={ItemEquiped=gun,drops=0,RemoveEquipedItem=function(p)p.drops=p.drops+1;p.ItemEquiped=nil end}
   local pc={HUD={ChatUI={}},WasInputKeyJustPressed=function(pc)return pc.press end,
    WasInputKeyJustReleased=function(pc)return pc.release end,IsInputKeyDown=function(pc)return pc.down end,
    GetInputAnalogKeyState=function(pc,key)return key.KeyName=='MouseX'and pc.dx or 0 end}
   local function frame(t,press,down,release,dx)
    now=t;pc.press=press;pc.down=down;pc.release=release;pc.dx=dx or 0;I.middleFrame(p,pc)
   end
   frame(0,true,false,true);assert(p.drops==1,'same-frame tap missed')
   p.ItemEquiped=gun;frame(1,true,true,false);frame(1.045,false,false,true);assert(p.drops==2)
   p.ItemEquiped=gun;frame(2,true,true,false);frame(2.26,false,false,true);assert(p.drops==2,'long hold unequipped')
   frame(3,true,true,false);frame(3.02,false,true,false,2.5);frame(3.04,false,false,true,-2);assert(p.drops==2,'drag unequipped')
   frame(4,true,true,false);p.ItemEquiped=other;frame(4.05,false,false,true);assert(p.drops==2)
   p.ItemEquiped=nil;frame(5,true,false,true);assert(p.drops==2,'physics-only grab or loose item consumed')
   p.ItemEquiped=gun;frame(6,true,true,false);B.ui.opened=true;frame(6.05,false,false,true);assert(p.drops==2)
   B.ui.opened=false;frame(7,true,true,false);I.reset();frame(7.05,false,false,true);assert(p.drops==2)''')

if __name__=='__main__':unittest.main(verbosity=2)
