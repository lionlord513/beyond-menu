return function(B)
 local root=B.root..'/Scripts/paintball/';local P=dofile(root..'physics.lua');local J=dofile(root..'journal.lua')(B,P);local A=dofile(root..'assets.lua')(B,P)
 local R={physics=P,journal=J,assets=A,balls={},items={},rendered={},targets={},clock=0,scanAt=0,seed=os.time()&0xffffffff}
 local valid=B.valid;local game=StaticFindObject('/Script/Engine.Default__GameplayStatics');local sys=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary');local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local transparent={R=0,G=0,B=0,A=0};local none=FName('None')
 R.view=dofile(root..'view.lua')(B,R)
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 local function guid(a)
  if not valid(a)then return end;local ok,g=pcall(function()return J.guid(a.GuidUnique)end)
  if ok and g~='00000000:00000000:00000000:00000000'then return g end
 end
 function R.record(a)local id=guid(a);return id and J.items[id],id end
 function R.isGun(a)local row=R.record(a);return row and row.kind=='gun'end
 local function contents(actor, shell, count, color)
  local parts = {}
  local function add(model, x, y, z, yaw)
   local tr = {Translation=P.v(x,y,z), Scale3D=P.v(1,1,1),
               Rotation={X=0,Y=0,Z=math.sin(yaw/2),W=math.cos(yaw/2)}}
   local part=A.visual(actor,model,shell,tr)
   parts[#parts+1]=part
   part:SetMaterial(0,A.material(color))
  end
  local ok,err=pcall(function()
   local layers=math.floor(count/7)
   for layer=0,layers-1 do add('ball-layer',0,0,1.3+layer*1.8,layer*.38) end
   for slot=0,count%7-1 do
    local angle=slot*math.pi/3+layers*.38
    add('ball',1.8*math.cos(angle),1.8*math.sin(angle),1.3+layers*1.8,0)
   end
  end)
  if not ok then
   for _,part in ipairs(parts) do part:K2_DestroyComponent(actor) end
   error(err)
  end
  return parts
 end
 local function clearContents(entry)
  for _,part in ipairs(entry.parts or {}) do
   if valid(part) then part:K2_DestroyComponent(entry.actor) end
  end
  entry.parts={}
 end
 function R.appearance(a,row)
  local id=guid(a);local old=R.items[id];if old and same(old.actor,a)and valid(old.visual)then return old end
  local c=a.StaticMesh;assert(valid(c),'Paintball item has no native mesh')
  -- Replace the actual native grab/rotation body. A separate visual on the
  -- actor root stays behind when Unreal detaches the simulating physics body.
  local visual=c;local model=row.kind=='gun'and'marker'or'canister'
  local mesh=A.mesh(model)
  if not same(visual.StaticMesh,mesh) then assert(visual:SetStaticMesh(mesh),'Paintball collision mesh failed') end
  A.skin(visual,model)
  local mass=row.kind=='gun'and(1.45+row.count*.0032)or(.08+row.count*.0032)
  a.BaseMass=mass;a.MassBase=mass;a.OvverideMass=mass;visual:SetMassOverrideInKg(none,mass,true)
  -- Keep native item collision/pickup/save, hide only the donor's geometry.
  for _,entry in ipairs(a:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.MeshComponent')))do local m=entry:get();if valid(m)and not same(m,visual)then m:SetVisibility(false,false)end end
  visual:SetHiddenInGame(false,false);visual:SetVisibility(true,false)
  if row.kind=='gun'then
   a.CanRotateRightHandItem=true;a.NbBullet=0;a.NbBulletMax=0;a.NoBulletSound=nil;a.SoundToPlay=nil;a.bCanExplode=false;a.IsAutomatic=false;a.CanBeAutomatic=false
   if valid(a.MuzzleFlash)then a.MuzzleFlash:SetVisibility(false,true);a.MuzzleFlash:Deactivate()end
   for _,kind in ipairs({'/Script/Niagara.NiagaraComponent','/Script/Engine.ParticleSystemComponent'})do
    local cls=StaticFindObject(kind);if valid(cls)then for _,value in ipairs(a:K2_GetComponentsByClass(cls))do local fx=value:get();fx:Deactivate();fx:SetAutoActivate(false);fx:SetHiddenInGame(true,false);fx:SetVisibility(false,false);fx:SetComponentTickEnabled(false)end end
   end
  end
  old={actor=a,visual=visual,row=row};R.items[id]=old
  if row.kind=='pod'then old.parts=contents(a,visual,row.count,row.color) end
  return old
 end
 function R.spawn(kind,color)
  B.context(true);J.writable();color=P.color(color)
  -- BumpGun is outside Apocalypse's rifle replacement family.
  local class=kind=='gun'and'/Game/BP/Items/Movable/Weapons/AK/BumpGun.BumpGun_C'or'/Game/BP/Items/Movable/Binocular/Binocular.Binocular_C'
  A.mesh(kind=='gun'and'marker'or'canister');A.mesh('ball')
  local a=B.actions.spawn(class,function(item)if kind=='gun'then item.NbBullet=0;item.NbBulletMax=0;item.NoBulletSound=nil;item.SoundToPlay=nil;item.bCanExplode=false end end,130)
  local id=assert(guid(a),'Paintball identity unavailable');local row={kind=kind,count=kind=='gun'and 0 or 50,color=color};J.items[id]=row
  local ok,e=pcall(R.appearance,a,row);if not ok then J.items[id]=nil;a:K2_DestroyActor();error(e)end
  return kind=='gun'and'Paintball gun spawned. Equip it, aim at a canister and press L.'or'50 paintballs spawned in a canister.'
 end
 function R.replaceContents(pod,count,color)
  local row,id=R.record(pod);local entry=R.items[id] or R.appearance(pod,row)
  local parts=contents(pod,entry.visual,count,color)
  clearContents(entry)
  entry.parts=parts
 end
 function R.trace(from,to,radius,ignored,complex)
  local hit={};if sys:SphereTraceSingle(B.player(),from,to,radius,0,complex~=false,ignored or{},0,hit,true,transparent,transparent,0)then
   local c=hit.Component;if c then local ok,v=pcall(function()return c:get()end);if ok then c=v end end
   return {at=P.v(hit.ImpactPoint.X,hit.ImpactPoint.Y,hit.ImpactPoint.Z),normal=P.v(hit.ImpactNormal.X,hit.ImpactNormal.Y,hit.ImpactNormal.Z),component=c,bone=hit.BoneName and hit.BoneName:ToString()or'None'}
  end
 end
 function R.target(c,bone)
  if not valid(c)then return '', '', nil end
  local actor=c:GetOwner();if not valid(actor)then return '', '', nil end
  local id=guid(actor)
  -- GUIDs survive item movement and native save recreation. Static level paths
  -- remain stable; procedural terrain uses world-space anchors instead.
  local key=id and('g:'..id)or('p:'..actor:GetFullName())
  if not id and (c:GetFullName():find('ProceduralMesh',1,true)or actor:GetFullName():find('Landscape',1,true))then return '', '', nil end
  local name=c:GetFName():ToString();R.targets[key..'|'..name]=c
  return key,name,c
 end
 local function transform(c,bone)
  if bone and bone~=''and bone~='None'then return c:GetSocketTransform(FName(bone),0)end
  return c:K2_GetComponentToWorld()
 end
 function R.impact(ball,hit)
  A.impactSound(hit.at,ball.seed)
  local owner,component,c=R.target(hit.component,hit.bone)
  local n=P.unit(hit.normal);local mark=P.impact(hit.at,n,ball.color,ball.seed,math.sqrt(P.dot(ball.velocity,ball.velocity)),P.dot(P.unit(ball.velocity),n))
  mark.owner=owner;mark.component=component;mark.bone=hit.bone
  if valid(c)then local tr=transform(c,mark.bone);mark.at=mathlib:InverseTransformLocation(tr,mark.at);mark.normal=P.unit(mathlib:InverseTransformDirection(tr,mark.normal));mark.gravity=P.unit(mathlib:InverseTransformDirection(tr,P.v(0,0,-1)))end
  -- Only nearby deposits on the same surface can feed a drip/pool.
  for i=#J.marks,math.max(1,#J.marks-2048),-1 do local old=J.marks[i]
   if old.owner==owner and old.component==component and old.bone==mark.bone and P.distance(old.at,mark.at)<36 and P.dot(old.normal,mark.normal)>.94 and old.wet<25 then
    P.accumulate(old,mark.color);local r=R.rendered[old];if r then r.dirty=true end;return old
   end
  end
  J.marks[#J.marks+1]=mark;return mark
 end
 function R.resolve(p)
  if p.owner==''then return nil end
  local c=R.targets[p.owner..'|'..p.component];if valid(c)then return c end
 end
 function R.worldPoint(p)local c=R.resolve(p);return valid(c)and mathlib:TransformLocation(transform(c,p.bone),p.at)or p.owner==''and p.at or nil end
 function R.draw(p)
  local target=R.resolve(p);if p.owner~=''and not valid(target)then return end
  local r=R.rendered[p]
  if not r or not valid(r.visual)then
   local actor=B.pc();local c=A.component(actor,StaticFindObject('/Script/ProceduralMeshComponent.ProceduralMeshComponent'));c:SetCollisionEnabled(0);c:SetCastShadow(false)
   if valid(target)then c:K2_AttachToComponent(target,FName(p.bone~=''and p.bone or'None'),0,0,0,false)end
   c:K2_SetRelativeTransform(A.identity,false,{},true);r={visual=c,owner=actor,dirty=true};R.rendered[p]=r
  end
  if r.dirty or(p.drip>0 and p.wet<24 and R.clock>(r.nextDraw or 0))then
   local geo=P.geometry(p,p.wet);r.nextDraw=R.clock+.25;r.dirty=false
   -- Project the mesh back to the struck surface. Drop triangles crossing an
   -- edge instead of painting floating sheets across empty space.
   local tr=valid(target)and transform(target,p.bone)or nil;local keep={}
   for i,pos in ipairs(geo.vertices)do
    local world=tr and mathlib:TransformLocation(tr,pos)or pos;local normal=tr and mathlib:TransformDirection(tr,p.normal)or p.normal
    local h=R.trace(P.add(world,normal,2),P.add(world,normal,-3),.02,{B.player()})
    if h and(not valid(target)or same(h.component,target))then
     local v=P.add(h.at,h.normal,.055);geo.vertices[i]=tr and mathlib:InverseTransformLocation(tr,v)or v;keep[i-1]=true
    end
   end
   local tris={};for i=1,#geo.triangles,3 do local a,b,c=geo.triangles[i],geo.triangles[i+1],geo.triangles[i+2];if keep[a]and keep[b]and keep[c]then tris[#tris+1]=a;tris[#tris+1]=b;tris[#tris+1]=c end end
   r.triangles=#tris/3;r.visual:CreateMeshSection(0,geo.vertices,tris,geo.normals,geo.uv,{},{},false);r.visual:SetMaterial(0,A.material(p.color))
  end
 end
 function R.fire(gun,row,pc)
  if row.count<=0 or #R.balls>=64 then return end
  local camera=pc.PlayerCameraManager
  local eye=camera:GetCameraLocation();local rotation=camera:GetCameraRotation()
  local forward=mathlib:GetForwardVector(rotation);local right=mathlib:GetRightVector(rotation)
  local muzzle=mathlib:TransformLocation(gun.StaticMesh:K2_GetComponentToWorld(),P.v(45.54,0,8.5))
  local ignored={B.player(),gun};local sightEnd=P.add(eye,forward,20000)
  local sight=R.trace(eye,sightEnd,.05,ignored)
  local aim=P.add(sight and sight.at or sightEnd,muzzle,-1)
  local direction=P.dot(aim,forward)>0 and P.unit(aim)or forward
  R.seed=(R.seed+7919)&0xffffffff;local rng=P.random(R.seed)
  direction=P.unit(P.add(P.add(direction,right,(rng()-.5)*.008),P.v(0,0,1),(rng()-.5)*.008))
  local ball=P.launch(muzzle,direction,row.color,R.seed);ball.ignored=ignored
  local obstruction=R.trace(eye,muzzle,P.radius,ignored)
  if obstruction then R.impact(ball,obstruction)
  else
   ball.visual=A.visual(pc,'ball');ball.visual:SetMaterial(0,A.material(row.color))
   ball.visual:K2_SetWorldLocation(muzzle,false,{},true);R.balls[#R.balls+1]=ball
  end
  row.count=row.count-1;A.shot(muzzle)
 end
 function R.scan()
  if not J.ready then J.load(game:GetGameInstance(B.pc()).MainSaveGame)end
  if not J.ready then return end
  if not R.frameHook then R.frameHook={RegisterHook('/Game/BP/Player/PlayerBase.PlayerBase_C:ReceiveTick',function(ctx,dt)
   if same(ctx:get(),B.player())then local ok,e=pcall(R.view.frame,dt:get());if not ok and R.viewError~=tostring(e)then R.viewError=tostring(e);B.log('Paintball view: '..tostring(e))end end
  end)}end
  for _,kind in ipairs({'BumpGun_C','Binocular_C'})do for _,a in ipairs(FindAllOf(kind)or{})do if valid(a)and same(a:GetWorld(),B.player():GetWorld())then local row=R.record(a);if row then R.appearance(a,row)end end end end
  -- Resolve persistent moving-object identities without using transient addresses.
  local wanted={};for _,p in ipairs(J.marks)do if p.owner~=''and not valid(R.resolve(p))then wanted[p.owner]=true end end
  if next(wanted)then for _,a in ipairs(FindAllOf('Actor')or{})do if valid(a)then
   local id=guid(a);local key=id and'g:'..id or'p:'..a:GetFullName()
   if wanted[key]then for _,e in ipairs(a:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.PrimitiveComponent')))do local c=e:get();R.targets[key..'|'..c:GetFName():ToString()]=c end end
  end end end
  for id,r in pairs(R.items)do if not valid(r.actor)then R.items[id]=nil end end
  if #A.voices<12 then A.audio()end
 end
 function R.tick(dt)
  if not B.ready()or not B.host()then return end
  dt=math.min(dt or .05,.1);R.clock=R.clock+dt
  if R.clock>=R.scanAt then R.scanAt=R.clock+1;R.scan()end
  if not J.ready then return end
  R.interaction.tick()
  local pc,p=B.pc(),B.player();local gun=p.ItemEquiped;local row=R.record(gun)
  if row and row.kind=='gun'then
   gun.NbBullet=0;gun.NbBulletMax=0;gun.IsAttacking=1000
  end
  for i=#R.balls,1,-1 do local b=R.balls[i];local hit=P.advance(b,dt,function(a,z,r)return R.trace(a,z,r,b.ignored)end)
   if hit~=nil then if hit then R.impact(b,hit)end;if valid(b.visual)then b.visual:K2_DestroyComponent(pc)end;table.remove(R.balls,i)
   elseif valid(b.visual)then b.visual:K2_SetWorldLocation(b.at,false,{},true)end
  end
  local pos=p:K2_GetActorLocation();local builds=0
  for index=#J.marks,1,-1 do
   local mark=J.marks[index];mark.wet=math.min(30,mark.wet+dt)
   local at=R.worldPoint(mark);local near=at and P.distance(at,pos)<8000^2
   if near then if builds<2 then local r=R.rendered[mark];if not r or r.dirty or(mark.drip>0 and mark.wet<24 and R.clock>(r.nextDraw or 0))then R.draw(mark);builds=builds+1 end end
   else local r=R.rendered[mark];if r and valid(r.visual)then r.visual:K2_DestroyComponent(r.owner)end;R.rendered[mark]=nil end
  end
 end
 function R.reset()
  R.view.reset();R.interaction.reset()
  for _,b in ipairs(R.balls)do if valid(b.visual)then b.visual:K2_DestroyComponent(B.pc())end end
  for _,r in pairs(R.rendered)do if valid(r.owner)and valid(r.visual)then r.visual:K2_DestroyComponent(r.owner)end end
  for _,r in pairs(R.items)do if valid(r.actor)then clearContents(r)end end
  A.reset();J.reset();R.balls={};R.items={};R.rendered={};R.targets={};R.clock=0;R.scanAt=0
 end
 R.interaction=dofile(root..'interaction.lua')(B,R)
 RegisterKeyBind(Key.L,function()B.enqueue(function()R.interaction.loadPressed()end)end)
 RegisterKeyBind(Key.LEFT_MOUSE_BUTTON,function()
  if not B.ui.opened then B.enqueue(function()R.interaction.firePressed()end)end
 end)
 return R
end
