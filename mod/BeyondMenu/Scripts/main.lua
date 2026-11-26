-- BeyondMenu has its own state, input bindings and UI. No companion mod required.
local root=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/Scripts/[^/]+$')
local B={version='0.2.4',root=assert(root),queue={},toggles={},restore={},message='Ready',active=true}
function B.valid(o) return o and o:IsValid() end
function B.log(s) print('[BeyondMenu] '..tostring(s)..'\n') end
function B.status(s) B.message=tostring(s):gsub('^.-:%d+: ',''):match('[^\r\n]+'):sub(1,180);B.log(s);if B.ui then B.ui.status() end end
function B.enqueue(fn) if not B.travelling then B.queue[#B.queue+1]=fn end end
B.H=dofile(root..'/Scripts/local_context.lua')(B.valid)
function B.player() return B.H.GetPlayer() end
function B.pc() return B.H.GetPlayerController() end
function B.ready()
 local p=B.player();if not B.valid(p) then return false end
 local ok,result=pcall(function()return p.IsLoaded and p.IsInitialized and B.valid(p.BP_PlayerStats)and not p.BP_PlayerStats.IsDead end)
 return ok and result
end
function B.host() local pc=B.pc();return B.valid(pc)and pc:HasAuthority()end
function B.context(host)
 assert(B.ready(),'Join a game first');if host then assert(B.host(),'Only the host can use this')end
 return B.player(),B.pc(),StaticFindObject('/Script/Engine.Default__GameplayStatics')
end
function B.remember(o,k,v)
 local id=tostring(o:GetAddress())..':'..k
 if not B.restore[id]then B.restore[id]={o=o,k=k,before=o[k]}end
 o[k]=v;B.restore[id].set=v
end
function B.restoreKey(key)
 for id,r in pairs(B.restore)do if not key or r.k==key then
  if B.valid(r.o)then pcall(function()if r.o[r.k]==r.set then r.o[r.k]=r.before end end)end
  B.restore[id]=nil
 end end
end
function B.run(fn)
 local ok,value=xpcall(fn,debug.traceback)
 if not ok or type(value)=='string'then B.status(value)end
 return ok,value
end
B.settings=dofile(root..'/Scripts/settings.lua')(B)
B.native=dofile(root..'/Scripts/native.lua')(B)
B.actions=dofile(root..'/Scripts/actions.lua')(B)
B.catalog=dofile(root..'/Scripts/catalog.lua')(B)
B.players=dofile(root..'/Scripts/players.lua')(B)
B.optional=dofile(root..'/Scripts/optional.lua')(B)
B.flight=dofile(root..'/Scripts/flight.lua')(B)
B.paintball=dofile(root..'/Scripts/paintball/runtime.lua')(B)
B.ui=dofile(root..'/Scripts/ui.lua')(B)
function B.reset()
 B.queue={};B.ui.close();B.flight.stop();B.paintball.reset();B.restoreKey();B.toggles={};B.catalog.reset();B.players.reset();B.actions.reset();B.optional.reset()
end
RegisterKeyBind(Key.F8,function()B.enqueue(function()if B.native.mouse()then B.ui.toggle()end end)end)
function B.escape()
 if B.actions.computerSession.active() then B.actions.computerSession.close()
 elseif B.ui.opened then B.ui.back() end
end
RegisterKeyBind(Key.ESCAPE,function()
 if B.ui.opened or B.actions.computerSession.active() then
  B.enqueue(function() if B.native.mouse() then B.escape() end end)
 end
end)
RegisterKeyBind(Key.LEFT_MOUSE_BUTTON,function()if B.ui.opened then B.enqueue(B.ui.click)end end)
RegisterLoadMapPreHook(function()B.travelling=true;B.reset()end)
RegisterLoadMapPostHook(function()B.H.reset();B.queue={};B.travelling=false end)
local tick=0;local errors={};local lastTime
B.timer=LoopInGameThreadWithDelay(50,function()
 if B.travelling or not B.active then return end
 local ok,e=xpcall(function()
  local q=B.queue;B.queue={};for _,fn in ipairs(q)do B.run(fn)end
  local dt=.05;if B.ready()then local now=StaticFindObject('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(B.player());dt=lastTime and math.max(0,math.min(.1,now-lastTime))or .05;lastTime=now else lastTime=nil end
  B.native.tick();B.actions.computerSession.tick();B.ui.tick();B.flight.tick(dt);B.paintball.tick(dt);if B.ready()then B.catalog.warm()end;tick=tick+1
  if tick%10==0 and B.ready()then B.actions.tick();B.optional.tick();B.catalog.tick()end
 end,debug.traceback)
 if not ok and not errors[tostring(e)]then errors[tostring(e)]=true;B.status(e)end
end)
_G.BeyondMenu=B
B.log(B.version..' loaded. F8 opens BeyondMenu.')
return B
