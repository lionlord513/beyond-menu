-- The prompt and its key use the same eligibility check against the real pickup body.
return function(B,R)
 local I={};local valid=B.valid;local P=R.physics
 I.capture=dofile(B.root..'/Scripts/paintball/input_capture.lua')(B)
 local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 local function sameColor(a,b)
  for i=1,3 do if math.abs(a[i]-b[i])>1/65535 then return false end end
  return true
 end
 local function inputReady(pc)
  return valid(pc)and B.host()and not B.ui.opened and not pc.bShowMouseCursor and not B.H.IsPauseMenu(pc)and not pc.HUD.ChatUI.TypeInChat and not valid(pc.Vehicle)
 end
 function R.heldGun()
  local p=B.player();if not valid(p)then return end
  if R.isGun(p.ItemEquiped)then return p.ItemEquiped end
  if valid(p.PhysicsHandle)then
   local c=p.PhysicsHandle:GetGrabbedComponent()
   if valid(c)and R.isGun(c:GetOwner())then return c:GetOwner()end
  end
 end
 function R.targetPod()
  local pc=B.pc();local p=B.player();local gun=R.heldGun()
  if not valid(pc)or not valid(p)or not gun then return end
  local camera=pc.PlayerCameraManager;local from=camera:GetCameraLocation()
  local dir=mathlib:GetForwardVector(camera:GetCameraRotation())
  local hit=R.trace(from,P.add(from,dir,230),2,{p,gun},false)
  if hit and valid(hit.component)then
   local actor=hit.component:GetOwner();local row=R.record(actor)
   if row and row.kind=='pod'and not valid(actor:GetAttachParentActor())and not actor.isAttached then return actor end
  end
 end
 local function loadTarget()
  local pc=B.pc()
  if not inputReady(pc)or not R.journal.ready or R.journal.error then return end
  local gun=R.heldGun();if not gun then return end
  local pod=R.targetPod();local ammo=R.record(pod);if not ammo or ammo.count<1 then return end
  local hopper=R.record(gun)
  if hopper.count>=50 and sameColor(hopper.color,ammo.color)then return end
  return pod,ammo,hopper
 end
 function R.swap()
  local p=B.context(true);R.journal.writable()
  local pod,ammo,hopper=loadTarget();assert(pod,'Look at a canister with paintballs the gun can load')
  assert(not game:GetGameInstance(p).IsSaving,'Wait for the save to finish')
  local samePaint=hopper.count==0 or sameColor(hopper.color,ammo.color)
  local transfer=math.min(50-hopper.count,ammo.count)
  local newLoad=samePaint and hopper.count+transfer or ammo.count
  local remaining=samePaint and ammo.count-transfer or hopper.count
  local podColor=samePaint and ammo.color or hopper.color
  R.replaceContents(pod,remaining,podColor)
  hopper.count,hopper.color=newLoad,ammo.color
  ammo.count,ammo.color=remaining,podColor
  I.tick()
  return ('%d paintballs loaded'):format(newLoad)
 end
 function I.loadPressed()
  if B.ready()and loadTarget() then return R.swap()end
 end
 function I.firePressed()
  if not B.ready()then return end
  local pc=B.pc();if not inputReady(pc)then return end
  local gun=B.player().ItemEquiped;local row=R.record(gun)
  if row and row.kind=='gun'and row.count>0 then
   R.fire(gun,row,pc);I.updateAmmo(row)
   I.repeatGun=gun;I.repeatAt=R.clock+.16
  end
 end
 local middle={KeyName=FName('MiddleMouseButton')}
 local mouseX={KeyName=FName('MouseX')};local mouseY={KeyName=FName('MouseY')}
 function I.middleFrame(p,pc)
  if not valid(pc)then I.middle=nil;return end
  if not I.middle then
   if not pc:WasInputKeyJustPressed(middle)then return end
   local gun=p.ItemEquiped
   if not R.isGun(gun)or not inputReady(pc)then return end
   I.middle={gun=gun,started=game:GetRealTimeSeconds(p),motion=0}
  end
  local press=I.middle
  if not same(press.gun,p.ItemEquiped)or not inputReady(pc)then I.middle=nil;return end
  press.motion=press.motion+math.abs(pc:GetInputAnalogKeyState(mouseX))+math.abs(pc:GetInputAnalogKeyState(mouseY))
  local released=pc:WasInputKeyJustReleased(middle)
  if game:GetRealTimeSeconds(p)-press.started>=.24 or press.motion>=4 then
   I.middle=nil
  elseif released then
   I.middle=nil
   p:RemoveEquipedItem()
   local hand={};pc:GetItemInHand(hand)
   if same(hand.Item,press.gun)then
    pc:RemoveItemInHand()
    if valid(press.gun)then press.gun:DropItem()end
   end
  elseif not pc:IsInputKeyDown(middle)then I.middle=nil end
 end
 local function addPrompt(hud)
  local parent=hud.ActionBox:GetParent();if not valid(parent)then return end
  local prompt=StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),hud.WidgetTree)
  prompt:SetFont(hud.ArrowCompl.Font);local font=prompt.Font;font.Size=13;prompt:SetFont(font);prompt:SetColorAndOpacity(hud.ArrowCompl.ColorAndOpacity)
  prompt:SetText(FText('Load paintballs  [L]'))
  local slot=parent:AddChildToVerticalBox(prompt);slot:SetHorizontalAlignment(1);slot:SetPadding({Left=0,Top=2,Right=0,Bottom=2})
  I.prompt=prompt
 end
 local function removeAmmo()
  if valid(I.nativeAmmo)then I.nativeAmmo:SetVisibility(I.previousVisibility)end
  if valid(I.ammoLabel)then I.ammoLabel:RemoveFromParent()end
  I.nativeAmmo=nil;I.ammoLabel=nil;I.lastCount=nil
 end
 function I.updateAmmo(row)
  if not row or row.kind~='gun' then if I.ammoLabel then removeAmmo()end;return end
  local widget=B.pc().HUD.WeaponBullets;if not valid(widget)then return end
  local original=widget.BulletWeapon:GetParent()
  if not same(original,I.nativeAmmo)then
   removeAmmo();I.nativeAmmo=original;I.previousVisibility=original:GetVisibility()
   local text=StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),widget.WidgetTree)
   text:SetFont(widget.BulletWeapon.Font);text:SetColorAndOpacity(widget.BulletWeapon.ColorAndOpacity)
   local slot=original:GetParent():AddChildToHorizontalBox(text);slot:SetVerticalAlignment(2);I.ammoLabel=text
   original:SetVisibility(1)
  end
  if I.lastCount~=row.count then I.ammoLabel:SetText(FText(('%d / 50'):format(row.count)));I.lastCount=row.count end
 end
 function I.tick()
  local pc=B.pc();local hud=valid(pc)and pc.HUD;if not valid(hud)then return end
  local active=loadTarget()
  if active and not valid(I.prompt)then addPrompt(hud)end
  if valid(I.prompt)then I.prompt:SetVisibility(active and 3 or 1)end
  local equipped=B.player().ItemEquiped
  local equippedRow=R.record(equipped)
  I.capture.apply(pc,equippedRow and equippedRow.kind=='gun'and inputReady(pc))
  I.updateAmmo(equippedRow)
  if I.repeatAt then
   if not same(equipped,I.repeatGun)or not inputReady(pc)or not pc:IsInputKeyDown({KeyName=FName('LeftMouseButton')})then
    I.repeatGun=nil;I.repeatAt=nil
   elseif R.clock>=I.repeatAt then
    local row=R.record(equipped);I.repeatAt=R.clock+.13
    if row and row.count>0 then R.fire(equipped,row,pc);I.updateAmmo(row)end
   end
  end
 end
 function I.reset()
  I.middle=nil
  I.capture.release()
  if valid(I.prompt)then I.prompt:RemoveFromParent()end;I.prompt=nil;I.repeatAt=nil;I.repeatGun=nil;removeAmmo()
 end
 return I
end
