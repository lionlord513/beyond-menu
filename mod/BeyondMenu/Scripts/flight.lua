return function(B)
 local F={};local valid=B.valid;local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 function F.stop()
  local r=F.state;F.state=nil;B.toggles.flight=false
  if r and valid(r.pawn)then
   local p=r.pawn;local m=p.CharacterMovement;m:StopMovementImmediately();p:SetActorEnableCollision(r.collision);m:SetMovementMode(r.mode,r.custom)
  end
 end
 function F.toggle()
  if F.state then F.stop();return'Flight disabled'end
  local p,pc=B.context(true);assert(not valid(pc.Vehicle),'Leave your vehicle before flying')
  local m=p.CharacterMovement
  F.state={pawn=p,pc=pc,collision=p:GetActorEnableCollision(),mode=m.MovementMode,custom=m.CustomMovementMode}
  m:StopMovementImmediately();m:DisableMovement();p:SetActorEnableCollision(false);B.toggles.flight=true
  return'Flight enabled: WASD, Space up, Ctrl down, hold Shift to boost'
 end
 function F.tick(dt)
  local r=F.state;if not r then return end
  if not B.ready()or not valid(r.pawn)or not valid(r.pc)or B.player():GetAddress()~=r.pawn:GetAddress()or valid(r.pc.Vehicle)then F.stop();return end
  local pc,p=r.pc,r.pawn;p:SetActorEnableCollision(false);p.CharacterMovement:StopMovementImmediately()
  if B.ui.opened or pc.bShowMouseCursor or B.H.IsPauseMenu(pc)or pc.HUD.ChatUI.TypeInChat then return end
  local function down(k)return pc:IsInputKeyDown({KeyName=FName(k)})end
  local rot=pc.PlayerCameraManager:GetCameraRotation();local forward=mathlib:GetForwardVector(rot);local right=mathlib:GetRightVector(rot)
  local a=(down('W')and 1 or 0)-(down('S')and 1 or 0);local b=(down('D')and 1 or 0)-(down('A')and 1 or 0);local z=(down('SpaceBar')and 1 or 0)-(down('LeftControl')and 1 or 0)
  local x,y=forward.X*a+right.X*b,forward.Y*a+right.Y*b;z=z+forward.Z*a+right.Z*b;local length=math.sqrt(x*x+y*y+z*z)
  if length<.001 then return end
  local step=(down('LeftShift')or down('RightShift'))and 7200 or 1800;step=step*math.min(dt or .05,.1)/math.max(1,length)
  local q=p:K2_GetActorLocation();p:K2_SetActorLocation({X=q.X+x*step,Y=q.Y+y*step,Z=q.Z+z*step},false,{},true);p:ForceNetUpdate()
 end
 return F
end
