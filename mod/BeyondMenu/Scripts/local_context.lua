-- UEHelpers in the pinned loader can select the first remote controller.
-- Select the actual local controller, retaining the human while driving.
return function(valid)
 local H={}
 function H.GetPlayerController()
  for _,pc in ipairs(FindAllOf('PlayerControllerBase_C')or{})do
   if valid(pc)and pc:IsLocalPlayerController()then return pc end
  end
 end
 function H.GetPlayer()
  local pc=H.GetPlayerController();if not pc then return end
  if valid(pc.PlayerControlled)then return pc.PlayerControlled end
  return pc.Pawn
 end
 function H.GetWorld()
  local pc=H.GetPlayerController();return pc and pc:GetWorld()
 end
 function H.IsPauseMenu(pc)
  local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
  return not valid(pc)or game:IsGamePaused(pc)
 end
 return H
end
