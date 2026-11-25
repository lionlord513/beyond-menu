-- Guest vehicles: assemble locally, snapshot with native save code,
-- and deliver the snapshot through the game's existing server garage route.
return function(D,H,valid,log)
 local V={};local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local slots=FindObject('BlueprintGeneratedClass','CarEquipableV2_C')
 local partClass=FindObject('BlueprintGeneratedClass','CarItemEquipableActor_C')
 local function note(s)D.message=s;log('Guest vehicle: '..s)end
 local function actors(kind,world)
  local t={};for _,a in ipairs(FindAllOf(kind)or{})do if valid(a)and a:GetWorld():GetAddress()==world then t[#t+1]=a end end;return t
 end
 local function children(a)
  local out={};a:GetAttachedActors(out,true,true);local t={}
  for _,v in ipairs(out)do local x=v:get();if valid(x)then t[#t+1]=x end end
  return t
 end
 local function cleanup(j)
  local a=j and j.prototype
  if valid(a)and a:HasAuthority()then
   for _,x in ipairs(children(a))do if valid(x)and x:HasAuthority()then x:K2_DestroyActor()end end
   if valid(a)then a:K2_DestroyActor()end
  end
  if j then j.prototype=nil end
 end
 local function signature(a)
  local rows={}
  for _,v in ipairs(a:K2_GetComponentsByClass(slots))do
   local c=v:get();local x=c.AttachedCarEquipableActor
   if valid(x)then rows[#rows+1]=c:GetFName():ToString()..'='..x:GetClass():GetFName():ToString()end
  end
  local count=#rows;local attached={}
  for _,x in ipairs(children(a))do if x:IsA(partClass)then local k=x:GetClass():GetFName():ToString();attached[k]=(attached[k]or 0)+1 end end
  for k,n in pairs(attached)do rows[#rows+1]='attached:'..k..'='..n end
  table.sort(rows);return table.concat(rows,'|'),count
 end
 local function fixedOrigin(p)
  local o=game:GetWorldOriginLocation(p)
  assert(o.X==0 and o.Y==0 and o.Z==0,'Native garage delivery is unavailable in a shifted world')
  for _,a in ipairs(actors('WorldSettings',p:GetWorld():GetAddress()))do
   assert(a.bEnableWorldOriginRebasing==false,'Native garage delivery needs the standard world coordinate settings');return
  end
  error('World settings are not ready')
 end
 local function classFor(id,p)
  if not V.classes then
   local out={};StaticFindObject('/Game/BP/Helper/HelperFunction.Default__HelperFunction_C'):GetVehiclesInGame(p,out)
   V.classes={};for _,v in ipairs(out)do local c=v:get();if valid(c)then V.classes[c:GetCDO().VehicleType]=c end end
  end
  return assert(V.classes[id],'Vehicle is unavailable in this game build')
 end
 function V.start(id)
  assert(not V.job,'Wait for the current vehicle delivery')
  local p,c=H.GetPlayer(),H.GetPlayerController()
  assert(valid(p)and valid(c)and not c:HasAuthority(),'Guest connection required')
  assert(not valid(c.Vehicle),'Stand on foot with 15 metres of clear space ahead')
  assert(not game:GetGameInstance(p).IsSaving,'Wait for the save to finish');fixedOrigin(p)
  local cls=classFor(id,p);local kind=cls:GetFName():ToString();local world=p:GetWorld():GetAddress()
  local q,v=p:K2_GetActorLocation(),p:GetActorForwardVector();local seen={}
  for _,a in ipairs(actors(kind,world))do seen[a:GetAddress()]=true end
  local beaconSeen={};for _,a in ipairs(actors('BP_UFOAlienCaller_C',world))do beaconSeen[a:GetAddress()]=true end
  local j={id=id,kind=kind,world=world,pc=c,player=p,seen=seen,beaconSeen=beaconSeen,at=os.clock(),deadline=os.clock()+20,
   phase='build',position={X=q.X+v.X*1400,Y=q.Y+v.Y*1400,Z=q.Z+100},hidden={}}
  V.job=j
  local rgb=D.color or{.24,.35,.45}
  local ok,e=pcall(function()c.BP_DebugMenuComponent:SpawnCar(id,false,true,D.metallic==true,{R=rgb[1],G=rgb[2],B=rgb[3],A=1},D.toggles.tunedCars==true)end)
  if not ok then V.job=nil;error(e)end
  return 'Preparing '..D.entries['car_'..id].title..'; keep the delivery area clear'
 end
 function V.tick()
  local j=V.job;if not j then return end
  local now=os.clock();if now<(j.nextAt or 0)then return end;j.nextAt=now+.5
  local c,p=H.GetPlayerController(),H.GetPlayer()
  if not valid(c)or not valid(p)or c:HasAuthority()or c:GetAddress()~=j.pc:GetAddress()or p:GetWorld():GetAddress()~=j.world then
   cleanup(j);V.job=nil;note('Vehicle preparation stopped: session changed');return
  end
  if now>j.deadline then cleanup(j);V.job=nil;note((j.phase=='build'or j.phase=='saving')and 'Vehicle preparation timed out; no delivery sent'or 'Delivery not confirmed yet; no duplicate request sent');return end
  if j.phase=='build'then
   if not valid(j.prototype)then
    for _,a in ipairs(actors(j.kind,j.world))do if not j.seen[a:GetAddress()]and a:HasAuthority()then j.prototype=a;break end end
    if not valid(j.prototype)then return end
    j.collision=j.prototype:GetActorEnableCollision();j.simulating=j.prototype.VehicleMesh:IsSimulatingPhysics(FName('None'))
    j.prototype:SetActorEnableCollision(false);j.prototype.VehicleMesh:SetSimulatePhysics(false)
   end
   local a=j.prototype;local all=children(a);all[#all+1]=a
   for _,x in ipairs(all)do local k=x:GetAddress();if not j.hidden[k]then j.hidden[k]={actor=x,hidden=x.bHidden};x:SetActorHiddenInGame(true)end end
   local sig,count=signature(a)
   if sig~=j.signature then j.signature=sig;j.stableAt=now end
   if count==0 or now-j.at<4 or now-(j.stableAt or now)<2 then return end
   -- Save the normal presentation, never our temporary local hiding/collision.
   for _,r in pairs(j.hidden)do if valid(r.actor)then r.actor:SetActorHiddenInGame(r.hidden)end end
   a:SetActorEnableCollision(j.collision);a.VehicleMesh:SetSimulatePhysics(j.simulating)
   -- Native modular saving is asynchronous. SaveObject/ProcessSaveActorData
   -- can return an empty placeholder while TryInitSave is still assembling it.
   j.signature=sig;j.parts=count
   a.CarSaveComponent:TryInitSave()
   j.phase='saving';j.deadline=now+30
   note('Waiting for the native fitted-parts save to finish')
  elseif j.phase=='saving'then
   local a=j.prototype;assert(valid(a),'Vehicle preparation was interrupted')
   if not a.CarSaveComponent.FinishSave then return end
   -- Use the exact native modular save, held by its component. Generic
   -- SaveActors is a different snapshot and discards the fitted-parts payload.
   -- Keep this as a UScriptStruct; converting its nested arrays to Lua tables
   -- also loses data in the installed UE4SS marshaller.
   local data=a.CarSaveComponent.SAVE;assert(data:IsValid()and valid(data.Class),'Native vehicle snapshot has no class')
   assert(data.Class:GetFName():ToString()==j.kind,'Native vehicle snapshot changed class')
   -- Preserve the native snapshot's identities together with its nested parts.
   c:SpawnSavedVehicule(data,j.position,p)
   j.phase='beacon';j.deadline=now+150
   -- Keep the native snapshot owner and its source alive until the receiver
   -- confirms the complete assembly. UE4SS exposes nested arrays by reference.
   for _,r in pairs(j.hidden)do if valid(r.actor)then r.actor:SetActorHiddenInGame(true)end end
   a:SetActorEnableCollision(false);a.VehicleMesh:SetSimulatePhysics(false)
   note('Vehicle sent to native garage delivery; waiting for the host')
  elseif j.phase=='beacon'then
   local a=c.VehicleSpawnerCaller
   local function matches(a)
    if not valid(a)or a:HasAuthority()or a:GetWorld():GetAddress()~=j.world or j.beaconSeen[a:GetAddress()]then return false end
    -- The native beacon replicates VehicleClass, not its saved Vehicle/Guid.
    if not valid(a.VehicleClass)or a.VehicleClass:GetFName():ToString()~=j.kind then return false end
    local q=a:K2_GetActorLocation();local b=j.position
    return (q.X-b.X)^2+(q.Y-b.Y)^2+(q.Z-b.Z)^2<500^2
   end
   if not matches(a)then
    a=nil;for _,x in ipairs(actors('BP_UFOAlienCaller_C',j.world))do if matches(x)then assert(not a,'Ambiguous delivery beacons; activate yours manually');a=x end end
   end
   if a and valid(a.RootMeshComponent)then
    j.beacon=a;j.activateAt=now+3;j.activations=0;j.phase='arrival'
    note('Native delivery beacon received; waiting for it to finish loading')
   end
  else
   -- The beacon can replicate before its action component is ready. Its native
   -- Actived guard makes repeat activation of this same beacon idempotent.
   -- Never repeat SpawnSavedVehicule or create another beacon here.
   if valid(j.beacon)and j.activations<3 and now>=j.activateAt then
    c:ServerExecuteItemAction(true,j.beacon,true,j.beacon.RootMeshComponent,j.beacon:GetTransform())
    j.activations=j.activations+1;j.activateAt=now+5
    note('Calling native vehicle delivery; waiting for the complete car')
   end
   for _,a in ipairs(actors(j.kind,j.world))do
    if not a:HasAuthority()and not j.seen[a:GetAddress()]and a:GetDistanceTo(p)<6000 then
     local sig,count=signature(a)
     if sig==j.signature then V.lastVehicle=a;cleanup(j);V.job=nil;note(('Vehicle delivered with %d fitted parts: %s'):format(count,D.entries['car_'..j.id].title));return end
    end
   end
  end
 end
 function V.reset()cleanup(V.job);V.job=nil;V.lastVehicle=nil;V.classes=nil end
 return V
end
