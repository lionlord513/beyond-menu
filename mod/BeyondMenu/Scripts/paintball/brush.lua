-- Sample the game's polish brush at the surface touched by its scrubbing stroke.
return function(B,R)
 local C={};local valid=B.valid;local P=R.physics
 local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local classPath='/Game/BP/Items/Movable/Tools/PolishBrush.PolishBrush_C'
 local primary={KeyName=FName('LeftMouseButton')}
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 function C.reset()
  C.actor=nil;C.component=nil;C.localPoint=nil;C.native=nil
 end
 local function activeBrush(pc)
  if B.ui.opened or pc.bShowMouseCursor or B.H.IsPauseMenu(pc)or pc.HUD.ChatUI.TypeInChat or valid(pc.Vehicle)then return end
  local item={};pc:GetItemInHand(item);local brush=item.Item
  if not valid(brush)then return end
  if not valid(C.class)then C.class=StaticFindObject(classPath)end
  if not valid(C.class)or not brush:IsA(C.class)or brush.Quantity<=0 then return end
  local controlled=brush.IsActive and brush.IsControlled and same(brush.ControlledBy,pc)
  if controlled or pc:IsInputKeyDown(primary)then return brush,controlled end
 end
 local function contact(brush,pc,native)
  local ignored={B.player(),brush}
  if native then
   local h=brush.CurrentHit
   if h.bBlockingHit then
    local base=h.ImpactPoint;local n=h.ImpactNormal
    local offset=P.add(brush.TargetLocation,base,-1)
    -- The game holds the brush mesh above the surface and slides it across
    -- the initial hit. Trace through its bristles to obtain the touched face.
    local tip=P.add(P.add(base,offset),n,-P.dot(offset,n))
    local hit=R.trace(P.add(tip,n,5),P.add(tip,n,-8),.35,ignored)
    if hit and valid(hit.component)then return hit end
   end
  end
  -- Walls and terrain have no native polish scalar. Use the same brush
  -- gesture and a short surface trace when the stock tool has no target.
  if not pc:IsInputKeyDown(primary)then return end
  local cam=pc.PlayerCameraManager;local eye=cam:GetCameraLocation()
  return R.trace(eye,P.add(eye,mathlib:GetForwardVector(cam:GetCameraRotation()),185),.35,ignored)
 end
 function C.tick(dt)
  if #R.journal.marks==0 then C.reset();return end
  local pc=B.pc();local brush,native=activeBrush(pc)
  if not brush then C.reset();return end
  local h=contact(brush,pc,native)
  if not h or not valid(h.component)then C.reset();return end
  local tr=h.component:K2_GetComponentToWorld()
  local previous=same(C.actor,brush)and same(C.component,h.component)and C.native==native and C.localPoint
  C.actor=brush;C.component=h.component;C.native=native
  C.localPoint=mathlib:InverseTransformLocation(tr,h.at)
  if not previous then return end
  local delta=P.add(h.at,mathlib:TransformLocation(tr,previous),-1)
  local tangent=P.add(delta,h.normal,-P.dot(delta,h.normal))
  local cm=math.sqrt(P.dot(tangent,tangent))
  if cm<.12 or cm>34 then return end
  if native and brush.CurrentXY.X^2+brush.CurrentXY.Y^2<.04 then return end
  R.scrub(h,math.min(math.max(0,dt)*1.1,cm/18))
 end
 return C
end
