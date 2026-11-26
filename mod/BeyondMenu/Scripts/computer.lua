-- The computer HUD expects an eBay terminal. It uses that actor for the
-- desktop's state, media and delivery location throughout the session.
return function(B)
 local C = {}
 local session
 local guard
 local saveHook
 local valid = B.valid
 local input = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')

 local function releaseGuard()
  if guard and valid(guard.menu) then guard.menu.CanOpenPauseMenu = guard.before end
  guard = nil
 end

 function C.close()
  local current = session
  if not current then return end
  session = nil
  local hud = current.hud
  if valid(current.service) then
   current.service.InBuyMenu = false
   current.service:OnRep_InBuyMenu()
   current.service:DestroyHUD()
  end
  if valid(hud) and hud:IsInViewport() then hud:RemoveFromParent() end
  local pc = current.controller
  if valid(pc) then
   pc:ResetIgnoreLookInput()
   pc:ResetIgnoreMoveInput()
   if valid(current.pawn) then current.pawn:EnableInput(pc) end
   pc.bShowMouseCursor = false
   -- Preserve Escape's pressed state until its native release has passed.
   input:SetInputMode_GameOnly(pc, false)
   input:SetFocusToGameViewport()
  end
  if valid(current.terminal) then current.terminal:K2_DestroyActor() end
  if guard then
   guard.releasedFrames = 0
   if valid(guard.menu) then guard.menu.CanOpenPauseMenu = false end
  end
 end

 function C.active() return session ~= nil end

 function C.tick()
  if guard and valid(guard.menu) then guard.menu.CanOpenPauseMenu = false end
  if session then
   if not valid(session.hud) or not session.hud:IsInViewport() then C.close() end
  elseif guard then
   local held = valid(guard.controller) and guard.controller:IsInputKeyDown({KeyName=FName('Escape')})
   guard.releasedFrames = held and 0 or guard.releasedFrames + 1
   if guard.releasedFrames >= 3 then releaseGuard() end
  end
 end

 function C.reset() C.close();releaseGuard() end

 function C.open()
  local pawn, controller, game = B.context()
  local service = pawn.AC_EbaySystem
  assert(valid(service), 'The computer service is still loading')
  C.reset()
  local class = LoadAsset('/Game/BP/EbaySystem/BP_eBayPC.BP_eBayPC_C')
  assert(valid(class), 'The native computer is unavailable')
  if not saveHook then
   saveHook = {RegisterHook('/Game/BP/Items/Master/ItemSavableMaster.ItemSavableMaster_C:SaveObject', function(context, output)
    if session and valid(session.terminal) and context:get():GetAddress() == session.terminal:GetAddress() then
     output:get():Empty()
    end
   end)}
  end
  local transform = pawn:GetTransform()
  local terminal = game:BeginDeferredActorSpawnFromClass(pawn, class, transform, 1, nil, 0)
  assert(valid(terminal), 'The native computer could not start')
  session = {service = service, controller = controller, pawn = pawn, terminal = terminal}
  local ok, message = pcall(function()
   terminal.FirstTimeOpen = true
   terminal.QuestGenerated = true
   terminal['Light Visibility'] = false
   terminal.MediaPlayer = StaticConstructObject(StaticFindObject('/Script/MediaAssets.MediaPlayer'), terminal)
   terminal:SetActorEnableCollision(false)
   terminal:SetActorHiddenInGame(true)
   terminal:SetReplicates(false)
   game:FinishSpawningActor(terminal, transform, 0)
   terminal:SetActorEnableCollision(false)
   terminal:SetActorHiddenInGame(true)
   terminal:SetActorTickEnabled(false)
   if valid(terminal.ItemSaver) then terminal.ItemSaver.SaveOnDistance = false end
   if valid(terminal.MediaPlayer) then terminal.MediaPlayer:Close() end
   B.ui.close()
   local menuClass = StaticFindObject('/MenuPlugin/Components/BP_MenuComponent.BP_MenuComponent_C')
   local menu = controller:GetComponentByClass(menuClass)
   if valid(menu) then
    guard = {menu=menu, before=menu.CanOpenPauseMenu, controller=controller, releasedFrames=0}
    menu.CanOpenPauseMenu = false
   end
   service['Open PC'](service, terminal)
   if guard then guard.menu.CanOpenPauseMenu = false end
   local hud = service.HUDREF
   session.hud = hud
   assert(valid(hud) and hud:IsInViewport(), 'The native computer did not open')
   controller.bShowMouseCursor = true
   input:SetInputMode_GameAndUIEx(controller, hud, 0, false, true)
  end)
  if not ok then C.close();error(message) end
  return 'Computer opened'
 end
 return C
end
