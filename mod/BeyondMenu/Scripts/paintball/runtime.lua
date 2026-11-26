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
  local hit={};if sys:SphereTraceSingle(R.pawn or B.player(),from,to,radius,0,complex~=false,ignored or{},0,hit,true,transparent,transparent,0)then
   local c=hit.Component;if c then local ok,v=pcall(function()return c:get()end);if ok then c=v end end
   return {at=P.v(hit.ImpactPoint.X,hit.ImpactPoint.Y,hit.ImpactPoint.Z),normal=P.v(hit.ImpactNormal.X,hit.ImpactNormal.Y,hit.ImpactNormal.Z),component=c,bone=hit.BoneName and hit.BoneName:ToString()or'None'}
  end
 end
 function R.target(c,bone)
  if not valid(c)then return '', 'WorldOrigin', nil end
  local actor=c:GetOwner();if not valid(actor)then return '', 'WorldOrigin', nil end
  local id=guid(actor)
  -- GUIDs survive item movement and native save recreation. Static level paths
  -- remain stable; procedural terrain uses world-space anchors instead.
  local key=id and('g:'..id)or('p:'..actor:GetFullName())
  if not id then
   local kind=actor:GetClass():GetFName():ToString()
   if kind:find('Landscape',1,true)or kind:find('PRRoad',1,true)or c:GetClass():GetFName():ToString()=='ProceduralMeshComponent' then
    return '', 'WorldOrigin', nil
   end
  end
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
  local incoming=P.unit(ball.velocity);local scale
  if owner=='' and component=='WorldOrigin'then
   local origin=game:GetWorldOriginLocation(R.pawn or B.player());R.origin=P.v(origin.X,origin.Y,origin.Z)
   mark.at=P.add(mark.at,R.origin)
  elseif valid(c)then
   local tr=transform(c,mark.bone);scale=tr.Scale3D
   if owner:sub(1,2)=='p:'then
    local o=game:GetWorldOriginLocation(R.pawn or B.player())
    mark.anchor={at=P.add(mark.at,o),normal=n,class=c:GetOwner():GetClass():GetFName():ToString()}
   end
   mark.at=mathlib:InverseTransformLocation(tr,mark.at);mark.normal=P.unit(mathlib:InverseTransformDirection(tr,mark.normal))
   mark.gravity=P.unit(mathlib:InverseTransformDirection(tr,P.v(0,0,-1)));incoming=mathlib:InverseTransformDirection(tr,incoming)
  end
  if math.abs(P.dot(mark.normal,incoming))<.86 then
   local u,v=P.basis(mark.normal);mark.angle=math.atan(P.dot(incoming,v),P.dot(incoming,u))
  end
  -- Use physical centimetres even on scaled surfaces, and choose the closest
  -- wet deposit. Slight shot spread can feed a shared pool or vertical run.
  local closest,offset,best
  for i=#J.marks,math.max(1,#J.marks-2048),-1 do
   local old=J.marks[i]
   if old.owner==owner and old.component==component and old.bone==mark.bone then
    local distance,d=P.depositOffset(old,mark,scale)
    if distance and (not best or distance<best)then closest,offset,best=old,d,distance end
   end
  end
  if closest then
   local u,v=P.basis(closest.normal);local hits=closest.imprints or {};closest.imprints=hits
   if #hits==4 then table.remove(hits,1)end
   hits[#hits+1]={x=P.dot(offset,u),y=P.dot(offset,v),radius=mark.radius,seed=mark.seed}
   if closest.remaining then closest.remaining=(closest.remaining*closest.volume+1)/(closest.volume+1)end
   P.accumulate(closest,mark.color);closest.paintedAt=os.time();closest.seenAt=R.clock;R.fresh=closest
   local r=R.rendered[closest];if r then r.dirty=true end;J.persist(closest);return closest
  end
  mark.seenAt=R.clock;J.marks[#J.marks+1]=mark;R.fresh=mark;J.persist(mark);return mark
 end
 function R.resolve(p)
  if p.owner==''then return nil end
  local c=R.targets[p.owner..'|'..p.component];if valid(c)then return c end
 end
 function R.worldPoint(p)
  if p.owner=='' then
   if p.component=='WorldOrigin' and R.origin then return P.add(p.at,R.origin,-1)end
   return p.at
  end
  local c=R.resolve(p);if valid(c)then return mathlib:TransformLocation(transform(c,p.bone),p.at)end
 end
 function R.scrub(hit,strength)
  if not J.ready or not B.host() or not hit or not valid(hit.component) or not(strength and strength>0 and strength<math.huge)then return 0 end
  local owner,component=R.target(hit.component,hit.bone);local address=hit.component:GetAddress();local count=0
  -- Only rendered paint within arm's reach can be touched. Distance culling
  -- never modifies the ledger or the remaining amount of any mark.
  for mark,r in pairs(R.rendered)do
   local matches=(mark.owner==owner and (owner=='' or mark.component==component))or r.surfaceAddress==address
   if matches then
    local surface=R.resolve(mark)
    local centre=R.worldPoint(mark);local n,g=mark.normal,mark.gravity
    if valid(surface)then local tr=transform(surface,mark.bone);n=mathlib:TransformDirection(tr,n);g=mathlib:TransformDirection(tr,g)end
    local wear=centre and P.brushWear(mark,P.add(hit.at,centre,-1),n,g,hit.normal,strength)
    if wear then
     count=count+1;local remaining=(mark.remaining or 1)-wear
     if remaining<=.001 then
      if valid(r.visual)and valid(r.owner)then r.visual:K2_DestroyComponent(r.owner)end
      R.rendered[mark]=nil;if R.fresh==mark then R.fresh=nil end
      for i=#J.marks,1,-1 do if J.marks[i]==mark then table.remove(J.marks,i);break end end
      J.persist(mark,true)
     else mark.remaining=remaining;r.dirty=true;R.fresh=mark;J.persist(mark)end
    end
   end
  end
  return count
 end
 R.draw=dofile(root..'splats.lua')(B,R)
 R.projectiles=dofile(root..'projectile.lua')(B,R)
 function R.scan()
  if not J.ready then J.load(game:GetGameInstance(B.pc()).MainSaveGame)end
  if not J.ready then return end
  local o=game:GetWorldOriginLocation(B.player());local previous=R.lastScanOrigin;R.origin=P.v(o.X,o.Y,o.Z);R.lastScanOrigin=R.origin
  if previous and P.distance(previous,R.origin)>0 then
   for mark,r in pairs(R.rendered)do
    if mark.owner=='' and mark.component=='WorldOrigin' and valid(r.visual)then r.visual:K2_SetWorldLocation(R.worldPoint(mark),false,{},true)end
   end
  end
  if not R.frameHook then R.frameHook={RegisterHook('/Game/BP/Player/PlayerBase.PlayerBase_C:ReceiveTick',function(ctx,dt)
   local p=ctx:get();if not same(p,B.player())then return end
   R.interaction.middleFrame(p,B.pc())
   local frameDt=dt:get();if #R.balls>0 then R.projectiles.frame(frameDt)end
   local ok,e=pcall(R.view.frame,frameDt);if not ok and R.viewError~=tostring(e)then R.viewError=tostring(e);B.log('Paintball view: '..tostring(e))end
  end)}end
  for id,entry in pairs(R.items)do if not valid(entry.actor)then R.items[id]=nil end end
  if R.clock >= (R.nextItemLookup or 0) then
   local missing={}
   for id,row in pairs(J.items)do if not R.items[id]then missing[row.kind]=true end end
   local world=B.player():GetWorld()
   for kind in pairs(missing)do
    for _,a in ipairs(FindAllOf(kind=='gun'and'BumpGun_C'or'Binocular_C')or{})do
     if valid(a)and same(a:GetWorld(),world)then
      local row,id=R.record(a);if row and not R.items[id]then R.appearance(a,row)end
     end
    end
   end
   R.nextItemLookup=R.clock+3
  end
  -- Resolve persistent moving-object identities without using transient addresses.
  -- Resolve unloaded targets in batches. Never enumerate the world's actors
  -- every second just because one painted object is beyond streaming range.
  if R.clock >= (R.resolveAt or 0) and #J.marks>0 then
   R.resolveAt=R.clock+3
   local wanted={};local probes=0
   for i=1,math.min(128,#J.marks) do
    if probes>=4 then break end
    R.resolveIndex=((R.resolveIndex or 0)%#J.marks)+1
    local mark=J.marks[R.resolveIndex]
    if mark.owner~='' and not valid(R.resolve(mark)) then
     if mark.anchor then
      -- Procedurally recreated scenery can acquire a different object name.
      -- Reattach only to the same class and physical surface at the saved point.
      if probes<4 then
       local anchor=mark.anchor;local at=P.add(anchor.at,R.origin,-1)
       local h=R.trace(P.add(at,anchor.normal,6),P.add(at,anchor.normal,-6),.15,{B.player()});probes=probes+1
       if h and valid(h.component)and P.dot(h.normal,anchor.normal)>.85 and h.component:GetOwner():GetClass():GetFName():ToString()==anchor.class then
        local restored=mathlib:TransformLocation(transform(h.component,mark.bone),mark.at)
        if P.distance(restored,h.at)<36 then R.targets[mark.owner..'|'..mark.component]=h.component end
       end
      end
     else wanted[mark.owner]=true end
    end
   end
   local function remember(key,actor)
    if not valid(actor)then return end
    for _,entry in ipairs(actor:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.PrimitiveComponent')))do
     local component=entry:get()
     R.targets[key..'|'..component:GetFName():ToString()]=component
    end
   end
   local needsGuid=false
   for key in pairs(wanted)do
    if key:sub(1,2)=='p:' then
     local path=key:match('^p:%S+ (.+)$')
     if path then remember(key,StaticFindObject(path))end
    else needsGuid=true end
   end
   if needsGuid then
    for _,cls in ipairs({'ItemBaseMaster_C','Pawn'})do
     for _,actor in ipairs(FindAllOf(cls)or{})do
      local id=guid(actor);if id and wanted['g:'..id]then remember('g:'..id,actor)end
     end
    end
   end
  end
  if #A.voices<12 then A.audio()end
 end
 function R.tick(dt)
  if not B.ready()or not B.host()then return end
  R.pawn=B.player()
  dt=math.min(dt or .05,.1);R.clock=R.clock+dt
  if R.clock>=R.scanAt then R.scanAt=R.clock+1;R.scan()end
  if not J.ready then return end
  R.interaction.tick()
  R.brush.tick(dt)
  local pc,p=B.pc(),B.player();local gun=p.ItemEquiped;local row=R.record(gun)
  if row and row.kind=='gun'then
   gun.NbBullet=0;gun.NbBulletMax=0;gun.IsAttacking=1000
  end
  local pos=p:K2_GetActorLocation()
  local builds=0
  local function visit(mark)
   mark.wet=math.min(46,mark.wet+math.max(0,R.clock-(mark.seenAt or (R.clock-dt))))
   mark.seenAt=R.clock
   local at=R.worldPoint(mark)
   local r=R.rendered[mark]
   if at and P.distance(at,pos)<8000^2 then
    local flowing=(mark.drip>0 and mark.wet<18)or(mark.pool>0 and mark.wet<5)
    if builds<2 and (not r or r.dirty or (flowing and R.clock>(r.nextDraw or 0))) then
     R.draw(mark);builds=builds+1
    end
   elseif r then
    if valid(r.visual)then r.visual:K2_DestroyComponent(r.owner)end
    R.rendered[mark]=nil
   end
  end
  if R.fresh then visit(R.fresh);R.fresh=nil end
  for i=1,math.min(#J.marks,24)do
   R.paintIndex=((R.paintIndex or 0)%#J.marks)+1;visit(J.marks[R.paintIndex])
  end
 end
 function R.reset()
  R.view.reset();R.interaction.reset();R.brush.reset()
  R.fresh=nil;R.pawn=nil;R.origin=nil;R.lastScanOrigin=nil;R.resolveAt=nil;R.resolveIndex=nil;R.paintIndex=nil;R.nextItemLookup=nil

  for _,r in pairs(R.rendered)do if valid(r.owner)and valid(r.visual)then r.visual:K2_DestroyComponent(r.owner)end end
  for _,r in pairs(R.items)do if valid(r.actor)then clearContents(r)end end
  R.projectiles.reset();A.reset();J.reset();R.balls={};R.items={};R.rendered={};R.targets={};R.clock=0;R.scanAt=0
 end
 R.interaction=dofile(root..'interaction.lua')(B,R)
 R.brush=dofile(root..'brush.lua')(B,R)
 RegisterKeyBind(Key.L,function()B.enqueue(function()R.interaction.loadPressed()end)end)
 RegisterKeyBind(Key.LEFT_MOUSE_BUTTON,function()
  if not B.ui.opened then B.enqueue(function()R.interaction.firePressed()end)end
 end)
 return R
end
