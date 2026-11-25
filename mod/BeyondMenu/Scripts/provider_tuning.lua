return function(T,menuRoot)
 if T.beyondMenuProvider then return end;T.beyondMenuProvider=true
 local rows={'laptop|Tuner Laptop|'..T.root..'/assets/laptop/icon.png'}
 local catalog=dofile(T.root..'/Scripts/nitrous/catalog.lua')
 for _,r in ipairs(catalog)do rows[#rows+1]='nitrous_'..r.id..'|'..r.name..'|'..menuRoot..'/assets/optional/nitrous-'..r.id..'.png'end
 ModRef:SetSharedVariable('BM_Tuning_Catalog',table.concat(rows,'\n'))
 for _,t in ipairs({T.ui,T.laptop})do if t and type(t.open)=='function'then local fn=t.open;t.open=function(...)if ModRef:GetSharedVariable('BM_UIOpen')then return end;return fn(...)end end end
 local last=ModRef:GetSharedVariable('BM_Tuning_Request')
 LoopInGameThreadWithDelay(250,function()
  ModRef:SetSharedVariable('BM_Tuning_Active',T.active~=false)
  local request=ModRef:GetSharedVariable('BM_Tuning_Request');if type(request)~='string'or request==last then return end;last=request
  local seq,id=request:match('^([%d-]+)|([%w_]+)$');if not seq then return end
  local ok,e=pcall(function()
   local pc=T.vehicle.pc();assert(T.valid(pc)and pc:IsLocalPlayerController()and pc:HasAuthority(),'Only the local host can spawn Beyond items')
   if id=='laptop'then
    local token=math.random(1,2147483646);ModRef:SetSharedVariable('BT_LocalLaptopGrant',token);pc:ServerExecRPC(('BT1 {"op":"localLaptopGrant","token":%d}'):format(token))
   else
    local n=tonumber(id:match('^nitrous_(%d+)$'));assert(n and catalog[n],'Unknown bottle')
    local game=StaticFindObject('/Script/Engine.Default__GameplayStatics');local p=pc.PlayerControlled;local q,v=p:K2_GetActorLocation(),p:GetActorForwardVector()
    local tr={Translation={X=q.X+v.X*220,Y=q.Y+v.Y*220,Z=q.Z+40},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
    local a=game:BeginDeferredActorSpawnFromClass(p,LoadAsset('/Game/BP/Items/Movable/TankContainer/GasBarrelGaz_2.GasBarrelGaz_2_C'),tr,2,nil,0);assert(T.valid(a),'Spawn failed')
    game:FinishSpawningActor(a,tr,0);ModRef:SetSharedVariable('BT_NewBottle_'..a:GetFullName(),n)
   end
  end)
  ModRef:SetSharedVariable('BM_Tuning_Result',seq..'|'..(ok and'Item spawned'or tostring(e):gsub('^.-:%d+: ','')))
 end)
end
