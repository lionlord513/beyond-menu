-- Runs inside an already-installed Apocalypse. No remote command endpoint.
return function(M,menuRoot)
 if M.beyondMenuProvider then return end;M.beyondMenuProvider=true
 local valid=function(o)return o and o:IsValid()end
 local H=dofile(M.root..'/Scripts/local_context.lua')(valid)
 local entries={};local labels={}
 local function add(id,name,fn,icon)
  entries[id]=fn;labels[#labels+1]=id..'|'..name..'|'..(icon and M.root..'/assets/shop/'..icon..'.png'or'')
 end
 for id,def in pairs(M.definitions)do local key=id
  add(key,def.Name or id,function()return M.spawn(key)end,id)
 end
 local function spawn(path,configure)
  local p=H.GetPlayer();local game=StaticFindObject('/Script/Engine.Default__GameplayStatics');local cls=LoadAsset(path);assert(valid(cls),'Item unavailable')
  local q,v=p:K2_GetActorLocation(),p:GetActorForwardVector();local tr={Translation={X=q.X+v.X*220,Y=q.Y+v.Y*220,Z=q.Z+40},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
  local a=game:BeginDeferredActorSpawnFromClass(p,cls,tr,2,nil,0);assert(valid(a),'Spawn failed')
  local ok,e=pcall(function()game:FinishSpawningActor(a,tr,0);if not M.guid(a)then a.GuidUnique=StaticFindObject('/Script/Engine.Default__KismetGuidLibrary'):NewGuid()end;if configure then configure(a)end;a:ForceNetUpdate()end)
  if not ok then if valid(a)then a:K2_DestroyActor()end;error(e)end;return a
 end
 add('ammo','Rifle ammunition',function()spawn('/Game/BP/Items/Movable/Bullets/AkBullet.AkBullet_C',function(a)a.NbBullet=30 end)end,'ammo')
 add('sight','2x sight',function()M.rail.journal.writable();spawn('/Game/BP/Items/Movable/Binocular/Binocular.Binocular_C',M.rail.optic.markItem)end,'sight')
 add('blade','Universal rotor blade',function()
  local T=M.gyrocopter.transport;T.journal.writable()
  spawn('/Game/BP/CarsV2/System/Actors/GTR/BP_GTR_Light_HL.BP_GTR_Light_HL_C',function(a)local id=assert(M.guid(a));T.journal.state.blade[id]={id,1};T.blades.skin(a,1,id)end)
 end,'blade')
 add('airframe','Hornet gyrocopter',function()return M.gyrocopter.spawn(false)end,'chassis')
 add('trailer','Landing-pad trailer',function()local _,a=M.gyrocopter.transport.spawn(true);return a end,'trailer')
 add('motorcycle','Classic motorcycle',function()return M.motorcycle.spawn(H.GetPlayer(),nil,'classic')end,'bikeframe')
 add('suzuki','Suzuki PV 50',function()return M.motorcycle.spawn(H.GetPlayer(),nil,'suzuki')end,'suzukiframe')
 table.sort(labels);ModRef:SetSharedVariable('BM_Apocalypse_Catalog',table.concat(labels,'\n'))
 if M.firing then local tick=M.firing.tick;M.firing.tick=function(a,def,now,allowed,pressed)if ModRef:GetSharedVariable('BM_UIOpen')then allowed=false;pressed=false end;return tick(a,def,now,allowed,pressed)end end
 local function guard(t,key)
  if not t or type(t[key])~='function'then return end;local fn=t[key]
  t[key]=function(...)if ModRef:GetSharedVariable('BM_UIOpen')then return end;return fn(...)end
 end
 guard(M.devmenu,'toggle');guard(M.backpack,'toggle');guard(M.utility,'open')
 local last=ModRef:GetSharedVariable('BM_Apocalypse_Request')
 LoopInGameThreadWithDelay(250,function()
  ModRef:SetSharedVariable('BM_Apocalypse_Active',M.active~=false and M.features~=false)
  local request=ModRef:GetSharedVariable('BM_Apocalypse_Request');if type(request)~='string'or request==last then return end;last=request
  local seq,id,tail=request:match('^([%d-]+)|([%w_]+)(.*)$');if not seq then return end
  local ok,e=pcall(function()
   local pc=H.GetPlayerController();local p=H.GetPlayer()
   assert(M.features~=false and not M.travelling and valid(pc)and pc:IsLocalPlayerController()and pc:HasAuthority(),'Only the local host can spawn Beyond items')
   assert(valid(p)and p.IsLoaded and not p.BP_PlayerStats.IsDead and not valid(pc.Vehicle),'Stand on foot first')
   local rgb,metallic
   if tail~=''then
    local r,g,b,m=tail:match('^|([%d.]+),([%d.]+),([%d.]+),([01])$');assert(r,'Invalid paint choice')
    rgb={tonumber(r),tonumber(g),tonumber(b)};for _,v in ipairs(rgb)do assert(v>=0 and v<=1,'Invalid paint choice')end;metallic=m=='1'
   end
   local a=assert(entries[id],'Unknown Beyond item')()
   if rgb and valid(a)then
    local paint=dofile(menuRoot..'/Scripts/vehicle_paint.lua')
    -- Optional models assemble asynchronously. Paint only this newly spawned actor.
    ExecuteWithDelay(6500,function()ExecuteInGameThread(function()if valid(a)then local ok,e=pcall(paint,a,rgb,metallic);if not ok then print('[BeyondMenu] Vehicle paint: '..tostring(e)..'\n')end end end)end)
   end
  end)
  ModRef:SetSharedVariable('BM_Apocalypse_Result',seq..'|'..(ok and'Item spawned'or tostring(e):gsub('^.-:%d+: ','')))
 end)
end
