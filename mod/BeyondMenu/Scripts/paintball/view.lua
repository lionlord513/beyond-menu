-- Both hands come from the same native first-person animation. The marker is
-- already attached to Hand_RSocket by the game's equip action.
return function(B, R)
 local V = {}
 local valid = B.valid
 local mathlib = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local identity = {X=1,Y=1,Z=1}
 local function copy(tr)
  local t,q,s = tr.Translation,tr.Rotation,tr.Scale3D
  return {Translation={X=t.X,Y=t.Y,Z=t.Z},Rotation={X=q.X,Y=q.Y,Z=q.Z,W=q.W},Scale3D={X=s.X,Y=s.Y,Z=s.Z}}
 end
 local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
 local function unchanged(a,b)
  if not b then return false end
  for name,part in pairs(b) do
   for k,v in pairs(part) do if math.abs(a[name][k]-v)>.001 then return false end end
  end
  return true
 end
 function V.reset()
  local arm=V.arm
  if valid(arm)then
   if unchanged(arm:GetRelativeTransform(),V.applied) then arm:K2_SetRelativeTransform(V.original,false,{},true) end
   if arm:GetAnimationMode()==1 and same(arm:GetAnimInstance(),V.instance) then
    if V.mode==1 and valid(V.previousClip) then arm:PlayAnimation(V.previousClip,true)
    else arm:SetAnimationMode(V.mode) end
   end
  end
  if valid(V.gun) and valid(V.mesh) and V.meshOriginal and same(V.mesh.AttachParent,V.gun.RootComponent) and not V.mesh:IsSimulatingPhysics(FName('None')) then
   V.mesh:K2_SetRelativeTransform(V.meshOriginal,false,{},true)
  end
  V.mesh=nil
  for _,component in ipairs(V.body or {}) do if valid(component)then component:SetOwnerNoSee(false)end end
  V.arm=nil;V.gun=nil;V.applied=nil;V.body=nil;V.instance=nil;V.previousClip=nil;V.aim=nil
 end
 local function equip(p,gun)
  V.reset()
  V.arm=p.FpsArm;V.gun=gun;V.original=copy(V.arm:GetRelativeTransform());V.mode=V.arm:GetAnimationMode();V.previousClip=V.mode==1 and V.arm.AnimationData.AnimToPlay or nil
  V.mesh=gun.StaticMesh;V.meshOriginal=copy(V.mesh:GetRelativeTransform())
  V.body={}
  for _,v in ipairs(p:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.SkeletalMeshComponent')))do
   local c=v:get()
   if valid(c)and not same(c,V.arm)and c:IsVisible()and not c.bOwnerNoSee and c:GetFName():ToString()~='Legs'then
    c:SetOwnerNoSee(true);V.body[#V.body+1]=c
   end
  end
 end
 function V.frame(dt)
  local p,pc=B.player(),B.pc();local gun=valid(p)and p.ItemEquiped
  if not valid(pc)or not pc.IsInFPS or not R.isGun(gun)or not same(gun.RootComponent.AttachParent,p.FpsArm)then
   if V.arm then V.reset()end
   return
  end
  if not same(gun,V.gun)then equip(p,gun)end
  local aim=not pc.bShowMouseCursor and pc:IsInputKeyDown({KeyName=FName('RightMouseButton')})
  if aim~=V.aim then
   local name=aim and 'ANIM_MP7A1-ADSIdle' or 'ANIM_MP7A1-Idle'
   local sequence=LoadAsset('/MasterCharacter/Animations/Arms/'..name..'.'..name)
   if valid(sequence)then V.arm:PlayAnimation(sequence,true);V.instance=V.arm:GetAnimInstance() end
   V.aim=aim
  end
  if pc:IsInputKeyDown({KeyName=FName('MiddleMouseButton')}) then return end
  local cam=pc.PlayerCameraManager
  local camera=mathlib:MakeTransform(cam:GetCameraLocation(),cam:GetCameraRotation(),identity)
  local arm=V.arm
  local P=R.physics
  local function bone(name) return arm:GetSocketLocation(FName(name)) end
  -- Resolve the grip from the animated palms. Aligning the arm rig to the
  -- imported mesh's axes used to turn the right elbow across the camera.
  local function center(a,b)
   return P.add(a,P.add(b,a,-1),.5)
  end
  local right=center(bone('middle_02_r'),bone('thumb_03_r'))
  local left=center(bone('ring_01_l'),bone('thumb_03_l'))
  local forward=P.unit(P.add(left,right,-1))
  local shoulderLine=P.unit(P.add(bone('upperarm_r'),bone('upperarm_l'),-1))
  local grip=mathlib:MakeTransform(right,mathlib:MakeRotFromXY(forward,shoulderLine),identity)
  local localGrip=mathlib:MakeRelativeTransform(grip,arm:K2_GetComponentToWorld())
  local pose=mathlib:MakeTransform(aim and {X=30,Y=0,Z=-12}or{X=28,Y=13,Z=-18},{Pitch=0,Yaw=0,Roll=0},identity)
  local desired=mathlib:ComposeTransforms(pose,camera)
  local armWorld=mathlib:ComposeTransforms(mathlib:InvertTransform(localGrip),desired)
  arm:K2_SetWorldTransform(armWorld,false,{},true)
  if same(V.mesh.AttachParent,gun.RootComponent)then
   -- These are the measured coordinates of the pistol grip and foregrip
   -- on the supplied model. The grip line sits below the receiver.
   local modelOffset=mathlib:MakeTransform({X=3.1,Y=0,Z=1.8},{Pitch=0,Yaw=0,Roll=0},identity)
   V.mesh:K2_SetWorldTransform(mathlib:ComposeTransforms(modelOffset,desired),false,{},true)
  end
  V.applied=copy(V.arm:GetRelativeTransform())
 end
 return V
end
