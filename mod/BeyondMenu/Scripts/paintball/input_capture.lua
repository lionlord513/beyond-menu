-- Steering the marker must not also activate a world target under the reticle.
-- A local mapping overlay preserves the native contexts and their key settings.
return function(B)
 local C={};local valid=B.valid
 local options={bIgnoreAllPressedKeysUntilRelease=true,bForceImmediately=true,bNotifyUserSettings=false}
 local function localInput(pc)
  local lib=StaticFindObject('/Script/Engine.Default__SubsystemBlueprintLibrary')
  local class=StaticFindObject('/Script/EnhancedInput.EnhancedInputLocalPlayerSubsystem')
  return lib:GetLocalPlayerSubSystemFromPlayerController(pc,class)
 end
 function C.release()
  if valid(C.subsystem)and valid(C.context)then C.subsystem:RemoveMappingContext(C.context,options)end
  C.subsystem=nil;C.context=nil
 end
 function C.apply(pc,armed)
  if not armed then if C.context then C.release()end;return end
  if valid(C.context)and valid(C.subsystem)then return end
  local sub=localInput(pc);if not valid(sub)then return end
  local context=StaticConstructObject(StaticFindObject('/Script/EnhancedInput.InputMappingContext'),sub)
  local action=StaticConstructObject(StaticFindObject('/Script/EnhancedInput.InputAction'),context)
  action.bConsumeInput=true
  context:MapKey(action,{KeyName=FName('LeftMouseButton')})
  context:MapKey(action,{KeyName=FName('RightMouseButton')})
  sub:AddMappingContext(context,10000,options)
  C.subsystem=sub;C.context=context
 end
 return C
end
