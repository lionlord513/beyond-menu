return function(B)
 local P={};local valid=B.valid
 function P.list()
  local p,_,game=B.context();local world=p:GetWorld():GetAddress();local state=game:GetGameState(p);local rows={}
  if not valid(state)then return rows end
  state.PlayerArray:ForEach(function(_,v)
   local s=v:get();if not valid(s)or s.bIsInactive then return end
   local pawn=s:GetPawn();local name=s:GetPlayerName():ToString()
   rows[#rows+1]={key=tostring(s:GetAddress()),state=s,pawn=pawn,name=name~=''and name or'Player',ping=math.max(0,math.floor(s:GetPingInMilliseconds()+.5)),self=valid(pawn)and pawn:GetAddress()==p:GetAddress(),world=world}
  end)
  table.sort(rows,function(a,b)if a.self~=b.self then return a.self end;return a.name:lower()<b.name:lower()end)
  return rows
 end
 function P.target(key)
  B.context(true)
  for _,row in ipairs(P.list())do if row.key==key then
   local p=row.pawn;assert(valid(p)and p:GetWorld():GetAddress()==row.world and p.IsLoaded,'Player is still loading')
   assert(valid(p.BP_PlayerStats)and not p.BP_PlayerStats.IsDead and not p.BP_PlayerStats.IsDying,'Player is not alive')
   return p,row
  end end
  error('This player has left the game')
 end
 function P.teleport(key,bring)
  local other=P.target(key);local own=B.player();local moved,dest=bring and other or own,bring and own or other
  assert(moved:GetAddress()~=dest:GetAddress(),'Choose another player')
  local mc,dc=moved:GetController(),dest:GetController()
  assert(valid(mc)and valid(dc)and not valid(mc.Vehicle)and not valid(dc.Vehicle),'Both players must be on foot')
  local q,v=dest:K2_GetActorLocation(),dest:GetActorRightVector()
  local point={X=q.X+v.X*180,Y=q.Y+v.Y*180,Z=q.Z+30}
  moved.CharacterMovement:StopMovementImmediately()
  assert(moved:K2_TeleportTo(point,moved:K2_GetActorRotation()),'No clear space beside the player')
  -- Match the authoritative position on the owning client to avoid correction.
  moved:ClientForceTeleport(moved:K2_GetActorLocation());moved:ForceNetUpdate()
  return bring and'Player brought to you'or'Teleported to player'
 end
 function P.heal(key)return B.actions.fill(nil,P.target(key))end
 function P.reset()end
 return P
end
