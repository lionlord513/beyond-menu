-- Native game actions adapted from the owner's personal menu.
return function(B)
 local A={};local valid=B.valid
 local function stats()local p=B.context(true);return p.BP_PlayerStats end
 local stat={{'Life','MaximumLife','AddLife'},{'Hunger','MaximumHunger','AddHunger'},{'Thirst','MaximumThirst','Add Thirst'}}
 function A.fill(which,p)
  p=p or B.player();assert(valid(p),'Player is unavailable');local s=p.BP_PlayerStats
  assert(valid(s)and not s.IsDead and not s.IsDying,'This player is not alive')
  for i,r in ipairs(stat)do if not which or i==which then s[r[3]](s,s[r[2]]-s[r[1]])end end
  p:ForceNetUpdate();return which and'Refilled'or'Health, hunger and thirst restored'
 end
 function A.refill(which)B.context(true);return A.fill(which)end
 function A.empty()local s=stats();s:AddUrine(-s.Urine);return'Bladder emptied'end
 function A.toggle(id)
  local p=B.context(id~='speed'and id~='jump');local on=not B.toggles[id]
  if id=='speed'then if on then B.remember(p,'DebugSpeedMultiplier',10)else B.restoreKey('DebugSpeedMultiplier')end
  elseif id=='jump'then if on then B.remember(p.CharacterMovement,'JumpZVelocity',1800)else B.restoreKey('JumpZVelocity')end
  elseif id=='needs'then
   if on then B.remember(p.BP_PlayerStats,'NoHunger',true);B.remember(p.BP_PlayerStats,'NoThirst',true)else B.restoreKey('NoHunger');B.restoreKey('NoThirst')end
  elseif id=='god'then if on then B.remember(p,'bCanBeDamaged',false)else B.restoreKey('bCanBeDamaged')end
  elseif not on then
   if id=='ammo'then B.restoreKey('NbBullet');B.restoreKey('NbBulletMax')elseif id=='brush'or id=='paint'then
    -- Consumables share Quantity, so restore only the affected class family.
    for key,r in pairs(B.restore)do if r.feature==id then if valid(r.o)then pcall(function()if r.o.Quantity==r.set then r.o.Quantity=r.before;r.o:OnRep_Quantity();r.o:ForceNetUpdate()end end)end;B.restore[key]=nil end end
   end
  end
  B.toggles[id]=on;A.tick();return on and'Enabled'or'Disabled'
 end
 function A.money(op,amount)
  local _,pc=B.context();local n=tonumber(amount)
  assert(n and n==n and n>=0 and n<=100000000,'Enter an amount from 0 to 100,000,000')
  local result={};pc:GetCurrentMoney(result);local before=assert(tonumber(result.NewParam),'Wallet unavailable')
  local change=op=='set'and n-before or op=='remove'and -math.min(before,n)or n
  if change>=0 then pc:AddMoney(change)else pc:RemoveMoney(-change)end
  pc:GetCurrentMoney(result);assert(math.abs(result.NewParam-before-change)<.01,'Wallet did not confirm the change')
  if valid(pc.BP_GarageComp)then pc.BP_GarageComp:SAVE()end
  return('Wallet: $%.0f'):format(result.NewParam)
 end
 function A.spawn(class,configure,distance)
  local p,pc,game=B.context();assert(not valid(pc.Vehicle),'Leave your vehicle before spawning')
  if type(class)=='string'then class=class:sub(1,1)=='/'and LoadAsset(class)or FindObject('BlueprintGeneratedClass',class)end
  assert(valid(class),'This item is unavailable in the current game')
  if not B.host()then assert(not configure,'Only the host can customize this item');p:ServerSpawnBackroomItem(class);return nil,'Spawn requested'end
  local q,v=p:K2_GetActorLocation(),p:GetActorForwardVector();distance=distance or 220
  local tr={Translation={X=q.X+v.X*distance,Y=q.Y+v.Y*distance,Z=q.Z+45},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
  local a=game:BeginDeferredActorSpawnFromClass(p,class,tr,2,nil,0);assert(valid(a),'Could not find room to spawn')
  local ok,e=pcall(function()
   if configure then configure(a)end
   game:FinishSpawningActor(a,tr,0)
   local g=a.GuidUnique;if g.A==0 and g.B==0 and g.C==0 and g.D==0 then a.GuidUnique=StaticFindObject('/Script/Engine.Default__KismetGuidLibrary'):NewGuid()end
   a:ForceNetUpdate()
  end)
  if not ok then a:K2_DestroyActor();error(e)end
  return a,'Item spawned'
 end
 function A.paint(rgb,metallic)
  B.context(true)
  A.spawn('/Game/BP/Items/Movable/Spray_Can/PaintBomb.PaintBomb_C',function(a)
   a.UseCustomColor=true;a.CustomColor={R=rgb[1],G=rgb[2],B=rgb[3],A=1};a.CustomMetallic=metallic and 1 or 0
  end)
  return metallic and'Metallic spraypaint spawned'or'Matte spraypaint spawned'
 end
 function A.time(value)
  local p,_,game=B.context(true);local sky=game:GetGameState(p).UDS;assert(valid(sky),'The sky is unavailable')
  sky['Time of Day']=value;sky['Replicated Time of Day']=value;sky['OnRep_Replicated Time of Day'](sky);sky:ForceNetUpdate();return'Time changed'
 end
 function A.weather(index)B.context(true);B.pc().BP_DebugMenuComponent:DebugWeather(index);return'Weather changed'end
 function A.tick()
  if not B.ready()or not B.host()then return end
  local world=B.player():GetWorld():GetAddress()
  local function each(kind,id,fn)
   if not B.toggles[id]then return end
   for _,a in ipairs(FindAllOf(kind)or{})do if valid(a)and a:HasAuthority()and a:GetWorld():GetAddress()==world then fn(a)end end
  end
  local function refill(a,id)
   local key=tostring(a:GetAddress())..':Quantity';B.remember(a,'Quantity',99999);B.restore[key].feature=id;a:OnRep_Quantity();a:ForceNetUpdate()
  end
  each('BrushMasterItem_C','brush',function(a)refill(a,'brush')end)
  each('PaintBombMasterItem_C','paint',function(a)refill(a,'paint')end)
  each('BulletWeaponMasterItem_C','ammo',function(a)B.remember(a,'NbBulletMax',99999);B.remember(a,'NbBullet',99999);a:ForceNetUpdate()end)
 end
 function A.reset()end
 return A
end
