-- Keep the native render components alive and update flight on the player frame.
return function(B,R)
 local Q={free={}};local P,A=R.physics,R.assets;local valid=B.valid
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local actorClass=StaticFindObject('/Script/Engine.Actor')
 function R.effectsOwner()
  if valid(Q.owner)then return Q.owner end
  local p=B.player();local spawn=mathlib:MakeTransform(p:K2_GetActorLocation(),{Pitch=0,Yaw=0,Roll=0},P.v(1,1,1))
  local owner=game:BeginDeferredActorSpawnFromClass(p,actorClass,spawn,1,nil,0)
  assert(valid(owner),'Paint presentation actor unavailable')
  owner:SetReplicates(false);owner:SetActorEnableCollision(false);owner:SetActorHiddenInGame(false)
  game:FinishSpawningActor(owner,spawn,0);Q.owner=owner
  return owner
 end
 local function acquire(color)
  local part=table.remove(Q.free)
  if not valid(part)then
   part=A.visual(R.effectsOwner(),'ball');part:SetCastShadow(false);part:SetOwnerNoSee(false)
  end
  part:SetMaterial(0,A.material(color));part:SetHiddenInGame(false,false);part:SetVisibility(true,false)
  return part
 end
 local function recycle(ball)
  if valid(ball.visual)then ball.visual:SetVisibility(false,false);Q.free[#Q.free+1]=ball.visual end
  ball.visual=nil
 end
 local function present(ball,from,to)
  local delta=P.add(to,from,-1);local distance=math.sqrt(P.dot(delta,delta))
  local direction=distance>.01 and P.unit(delta)or P.unit(ball.velocity)
  -- A short shutter streak retains the selected material without adding a light.
  local shutter=math.min(9,distance*.65)
  local at=P.add(to,direction,-shutter*.5)
  local rotation=mathlib:MakeRotFromX(direction)
  local visualScale=math.min(1.8,1+math.sqrt(P.distance(ball.origin,at))*.00012)
  local pose=mathlib:MakeTransform(at,rotation,P.v(visualScale+shutter/(2*P.radius),visualScale,visualScale))
  ball.visual:K2_SetWorldTransform(pose,false,{},true)
 end
 -- Integrate at 240 Hz in Lua. One native swept sphere per 1/30 second bounds
 -- chord error under 0.14 cm while covering the entire path between samples.
 local function advance(ball,dt)
  while dt>1e-7 do
   local step=math.min(dt,1/30);local start=ball.at
   local expired=P.advance(ball,step)
   local hit=R.trace(start,ball.at,P.radius,ball.ignored)
   if hit then ball.at=hit.at;return hit end
   if expired==false then return false end
   dt=dt-step
  end
 end
 function R.fire(gun,row,pc)
  if row.count<=0 or #R.balls>=64 then return end
  local camera=pc.PlayerCameraManager;local eye=camera:GetCameraLocation();local rotation=camera:GetCameraRotation()
  local forward=mathlib:GetForwardVector(rotation);local right=mathlib:GetRightVector(rotation)
  local muzzle=mathlib:TransformLocation(gun.StaticMesh:K2_GetComponentToWorld(),P.v(45.54,0,8.5))
  local ignored={B.player(),gun};local sightEnd=P.add(eye,forward,20000);local sight=R.trace(eye,sightEnd,.05,ignored)
  local aim=P.add(sight and sight.at or sightEnd,muzzle,-1);local direction=P.dot(aim,forward)>0 and P.unit(aim)or forward
  R.seed=(R.seed+7919)&0xffffffff;local rng=P.random(R.seed)
  direction=P.unit(P.add(P.add(direction,right,(rng()-.5)*.008),P.v(0,0,1),(rng()-.5)*.008))
  local ball=P.launch(muzzle,direction,row.color,R.seed);ball.ignored=ignored;ball.origin=muzzle
  local obstructed=R.trace(eye,muzzle,P.radius,ignored)
  if obstructed then
   R.impact(ball,obstructed)
  else
   ball.visual=acquire(row.color);R.balls[#R.balls+1]=ball
   -- Take a short sweep out of the barrel immediately. When a nearby surface
   -- is struck, the last in-flight sample survives one complete rendered frame.
   local hit=advance(ball,1/300)
   if hit then ball.pending=hit;present(ball,muzzle,P.add(muzzle,P.add(hit.at,muzzle,-1),.55))
   else present(ball,muzzle,ball.at)end
   ball.firstFrame=true
  end
  row.count=row.count-1;A.shot(muzzle)
 end
 function Q.frame(dt)
  for index=#R.balls,1,-1 do
   local ball=R.balls[index]
   if ball.firstFrame then ball.firstFrame=nil
   elseif ball.pending then
    local hit=ball.pending;table.remove(R.balls,index);recycle(ball);R.impact(ball,hit)
   else
    local from=ball.at;local hit=advance(ball,math.min(.15,math.max(0,dt)))
    if hit==false then table.remove(R.balls,index);recycle(ball)
    elseif hit then
     ball.pending=hit;present(ball,from,P.add(from,P.add(hit.at,from,-1),.82))
    else present(ball,from,ball.at)end
   end
  end
 end
 function Q.reset()
  R.balls={};Q.free={}
  if valid(Q.owner)then Q.owner:K2_DestroyActor()end;Q.owner=nil
 end
 return Q
end
