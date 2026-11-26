-- Native save revision sidecars. Never execute data as Lua or mix two worlds.
return function(B,P)
 local J={items={},marks={},ready=false};local snapshot=dofile(B.root..'/Scripts/paintball/save_snapshot.lua')
 local function guid(g)return('%08x:%08x:%08x:%08x'):format(g.A&0xffffffff,g.B&0xffffffff,g.C&0xffffffff,g.D&0xffffffff)end
 J.guid=guid
 function J.key(save)
  local s=save.SaveGameMetadata.SaveName;local world=guid(s.Guid)
  if world=='00000000:00000000:00000000:00000000'then return end
  return world:gsub(':','')..'-'..guid(s.GuidUnique):gsub(':','')..'-'..tostring(s.Iterator),world
 end
 local function esc(s)return tostring(s):gsub('%%','%%25'):gsub('\t','%%09'):gsub('\n','%%0A'):gsub('\r','%%0D')end
 local function unesc(s)return s:gsub('%%(%x%x)',function(h)return string.char(tonumber(h,16))end)end
 local function num(v)local n=tonumber(v);assert(n and n==n and math.abs(n)<1e15,'Invalid paint snapshot number');return n end
 local function path(key)return B.root..'/state/paintball-'..key..'.txt'end
 function J.encode()
  local lines={'BPAINT1'};local keys={};for id in pairs(J.items)do keys[#keys+1]=id end;table.sort(keys)
  for _,id in ipairs(keys)do local r=J.items[id];lines[#lines+1]=table.concat({'I',id,r.kind,r.count,r.color[1],r.color[2],r.color[3]},'\t')end
  for _,p in ipairs(J.marks)do
   local fields={'P',esc(p.owner or''),esc(p.component or''),esc(p.bone or''),p.seed,p.radius,p.stretch,p.volume,p.wet,p.drip,p.pool}
   for _,v in ipairs({p.at,p.normal,p.gravity})do for _,k in ipairs({'X','Y','Z'})do fields[#fields+1]=('%.9g'):format(v[k])end end
   for i=1,3 do fields[#fields+1]=('%.9g'):format(p.color[i])end
   lines[#lines+1]=table.concat(fields,'\t')
  end
  return table.concat(lines,'\n')..'\n'
 end
 function J.decode(bytes)
  assert(bytes:sub(1,8)=='BPAINT1\n','Unknown paint snapshot');local items,marks={},{}
  for line in bytes:sub(9):gmatch('[^\n]+')do
   local w={};for s in(line..'\t'):gmatch('(.-)\t')do w[#w+1]=s end
   if w[1]=='I'then
    assert(#w==7 and w[2]:match('^%x+:%x+:%x+:%x+$')and(w[3]=='gun'or w[3]=='pod'),'Invalid paint item')
    local count=num(w[4]);assert(count%1==0 and count>=0 and count<=50 and not items[w[2]],'Invalid paintball count')
    items[w[2]]={kind=w[3],count=count,color=P.color({num(w[5]),num(w[6]),num(w[7])})}
   else
    assert(w[1]=='P'and #w==23,'Invalid paint mark')
    local p={owner=unesc(w[2]),component=unesc(w[3]),bone=unesc(w[4]),seed=num(w[5]),radius=num(w[6]),stretch=num(w[7]),volume=num(w[8]),wet=num(w[9]),drip=num(w[10]),pool=num(w[11])}
    p.at=P.v(num(w[12]),num(w[13]),num(w[14]));p.normal=P.v(num(w[15]),num(w[16]),num(w[17]));p.gravity=P.v(num(w[18]),num(w[19]),num(w[20]));p.color=P.color({num(w[21]),num(w[22]),num(w[23])})
    assert(p.seed%1==0 and p.seed>=0 and p.seed<=4294967295 and p.radius>0 and p.radius<1000 and p.stretch>=1 and p.stretch<=3 and p.volume>=1 and p.drip>=0 and p.drip<=80 and p.pool>=0 and p.pool<1e6,'Invalid paint geometry')
    assert(math.abs(P.dot(p.normal,p.normal)-1)<.01,'Invalid paint normal');marks[#marks+1]=p
   end
  end
  return items,marks
 end
 function J.load(save)
  if J.ready or not B.valid(save)then return end
  local key,world=J.key(save);if not key then return end
  local bytes=snapshot.read(path(key));local items,marks={},{}
  if bytes then items,marks=J.decode(bytes)end
  J.items=items;J.marks=marks;J.world=world;J.ready=true
 end
 function J.writable()assert(J.ready,'Waiting for the world save');assert(not J.error,J.error)end
 function J.capture(save)
  if not J.ready or not B.valid(save)or not save:IsA(StaticFindObject('/Script/DriveBeyondHorizons.DBHSaveGame'))then return end
  local key,world=J.key(save);if not key or world~=J.world then return end
  snapshot.commit(path(key),key,J.encode())
 end
 J.hook={RegisterHook('/Script/DriveBeyondHorizons.DBHHelper:SaveGameToSlotAsyncReal',function(_,save)
  local ok,e=pcall(J.capture,save:get());if not ok then J.error=tostring(e);B.status('Paint save failed: '..J.error)end
 end)}
 function J.reset()J.items={};J.marks={};J.world=nil;J.ready=false;J.error=nil end
 return J
end
