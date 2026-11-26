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
 local function encodeMark(p)
   local fields={'P',esc(p.owner or''),esc(p.component or''),esc(p.bone or''),p.seed,p.radius,p.stretch,p.volume,p.wet,p.drip,p.pool}
   for _,v in ipairs({p.at,p.normal,p.gravity})do for _,k in ipairs({'X','Y','Z'})do fields[#fields+1]=('%.9g'):format(v[k])end end
   for i=1,3 do fields[#fields+1]=('%.9g'):format(p.color[i])end
   if p.angle or p.imprints or p.remaining or p.anchor then
    fields[#fields+1]=p.angle and ('%.8g'):format(p.angle)or''
    local hits={};for _,h in ipairs(p.imprints or {})do
     hits[#hits+1]=('%.6g,%.6g,%.6g,%d'):format(h.x,h.y,h.radius,h.seed)
    end
    fields[#fields+1]=table.concat(hits,'|')
   end
   if p.remaining or p.anchor then fields[#fields+1]=p.remaining and ('%.9g'):format(p.remaining)or''end
   if p.anchor then
    fields[#fields+1]=esc(p.anchor.class)
    for _,v in ipairs({p.anchor.at,p.anchor.normal})do for _,k in ipairs({'X','Y','Z'})do fields[#fields+1]=('%.12g'):format(v[k])end end
   end
   return table.concat(fields,'\t')
 end
 function J.encode()
  local lines={'BPAINT1'};local keys={};for id in pairs(J.items)do keys[#keys+1]=id end;table.sort(keys)
  for _,id in ipairs(keys)do local r=J.items[id];lines[#lines+1]=table.concat({'I',id,r.kind,r.count,r.color[1],r.color[2],r.color[3]},'\t')end
  for _,p in ipairs(J.marks)do lines[#lines+1]=encodeMark(p)end
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
    assert(w[1]=='P'and (#w==23 or #w==25 or #w==26 or #w==33),'Invalid paint mark')
    local p={owner=unesc(w[2]),component=unesc(w[3]),bone=unesc(w[4]),seed=num(w[5]),radius=num(w[6]),stretch=num(w[7]),volume=num(w[8]),wet=num(w[9]),drip=num(w[10]),pool=num(w[11])}
    p.at=P.v(num(w[12]),num(w[13]),num(w[14]));p.normal=P.v(num(w[15]),num(w[16]),num(w[17]));p.gravity=P.v(num(w[18]),num(w[19]),num(w[20]));p.color=P.color({num(w[21]),num(w[22]),num(w[23])})
    if w[24] and w[24]~=''then p.angle=num(w[24]);assert(math.abs(p.angle)<=math.pi+.00001,'Invalid impact angle')end
    if w[25] and w[25]~=''then
     p.imprints={}
     for value in w[25]:gmatch('[^|]+')do
      local x,y,r,s=value:match('^([^,]+),([^,]+),([^,]+),([^,]+)$');x,y,r,s=num(x),num(y),num(r),num(s)
      assert(#p.imprints<4 and math.abs(x)<=28 and math.abs(y)<=28 and r>0 and r<1000 and s%1==0 and s>=0 and s<=4294967295,'Invalid paint imprint')
      p.imprints[#p.imprints+1]={x=x,y=y,radius=r,seed=s}
     end
    end
    if w[26] and w[26]~=''then p.remaining=num(w[26]);assert(p.remaining>0 and p.remaining<=1,'Invalid remaining paint')end
    if w[27]then p.anchor={class=unesc(w[27]),at=P.v(num(w[28]),num(w[29]),num(w[30])),normal=P.v(num(w[31]),num(w[32]),num(w[33]))}end
    assert(p.seed%1==0 and p.seed>=0 and p.seed<=4294967295 and p.radius>0 and p.radius<1000 and p.stretch>=1 and p.stretch<=3 and p.volume>=1 and p.drip>=0 and p.drip<=80 and p.pool>=0 and p.pool<1e6,'Invalid paint geometry')
    assert(math.abs(P.dot(p.normal,p.normal)-1)<.01,'Invalid paint normal');marks[#marks+1]=p
   end
  end
  return items,marks
 end
 local worldPaint=dofile(B.root..'/Scripts/paintball/world_paint.lua')(snapshot,encodeMark,function(line)
  local _,marks=J.decode('BPAINT1\n'..line..'\n');assert(#marks==1,'Invalid world paint record');return marks[1]
 end)
 function J.persist(mark,removed)
  local ok,e=pcall(worldPaint.change,mark,removed)
  if ok then J.paintError=nil;return end
  -- The ledger retains the pending change in memory for its next checkpoint.
  -- A failed disk write must not interrupt the projectile or inventory action.
  local message=tostring(e)
  if J.paintError~=message then B.status('Paint write failed: '..message)end;J.paintError=message
 end
 function J.load(save)
  if J.ready or not B.valid(save)then return end
  local key,world=J.key(save);if not key then return end
  local bytes=snapshot.read(path(key));local items,marks={},{}
  if bytes then items,marks=J.decode(bytes)end
  J.marks=worldPaint.open(B.root..'/state/paint-world-'..world:gsub(':','')..'.log',marks)
  J.items=items;J.world=world;J.ready=true
 end
 function J.writable()assert(J.ready,'Waiting for the world save');assert(not J.error,J.error)end
 function J.capture(save)
  if not J.ready or not B.valid(save)or not save:IsA(StaticFindObject('/Script/DriveBeyondHorizons.DBHSaveGame'))then return end
  local key,world=J.key(save);if not key or world~=J.world then return end
  worldPaint.checkpoint();snapshot.commit(path(key),key,J.encode());J.paintError=nil;J.error=nil
 end
 J.hook={RegisterHook('/Script/DriveBeyondHorizons.DBHHelper:SaveGameToSlotAsyncReal',function(_,save)
  local ok,e=pcall(J.capture,save:get());if not ok then J.error=tostring(e);B.status('Paint save failed: '..J.error)end
 end)}
 function J.reset()if J.ready then worldPaint.close()end;J.items={};J.marks={};J.world=nil;J.ready=false;J.error=nil;J.paintError=nil end
 return J
end
