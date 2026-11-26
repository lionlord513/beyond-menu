-- One append-only history per native world GUID. Save slots keep their own
-- inventory, but loading an older slot cannot remove paint or undo brushing.
return function(snapshot,encode,decode)
 local W={};local header='BWPAINT1\n'
 local path,rows,order,events,repair
 local function key(mark)
  if mark.paintKey then return mark.paintKey end
  local x,y,z=mark.at.X,mark.at.Y,mark.at.Z
  local parts={mark.owner or '',mark.component or '',mark.bone or '',('%u'):format(mark.seed),('%.9g,%.9g,%.9g'):format(x==0 and 0 or x,y==0 and 0 or y,z==0 and 0 or z)}
  for i,part in ipairs(parts)do parts[i]=part:gsub('%%','%%25'):gsub('|','%%7c'):gsub('[%c]',function(c)return ('%%%02x'):format(c:byte())end)end
  mark.paintKey=table.concat(parts,'|');return mark.paintKey
 end
 local function set(id,value)
  if rows[id]==nil then order[#order+1]=id end
  rows[id]=value
 end
 local function updateLine(mark)
  mark.paintedAt=mark.paintedAt or math.floor(os.time()-(mark.wet or 0))
  return 'U\t'..mark.paintedAt..'\t'..encode(mark)
 end
 local function checkpoint()
  local lines={header}
  for _,id in ipairs(order)do local mark=rows[id];lines[#lines+1]=(mark and updateLine(mark)or 'D\t'..id)..'\n'end
  snapshot.replace(path,table.concat(lines));events=#order;repair=false
 end
 function W.change(mark,removed)
  assert(path,'Paint world is not loaded');local id=key(mark)
  if removed then set(id,false)else set(id,mark)end
  if repair then checkpoint();return end
  local line=(removed and 'D\t'..id or updateLine(mark))..'\n'
  -- Close each completed stroke/impact so a normal process exit between
  -- native saves keeps the paint. A torn final record is repaired on open.
  repair=true
  local f=assert(io.open(path,'ab'));local wrote,writeErr=f:write(line);local closed,closeErr=f:close()
  assert(wrote and closed,writeErr or closeErr);events=events+1;repair=false
 end
 function W.open(filename,legacy)
  path=filename;rows={};order={};events=0;repair=false
  local bytes=snapshot.read(path)
  if bytes then
   assert(bytes:sub(1,#header)==header,'Unrecognized world paint history')
   for line in bytes:sub(#header+1):gmatch('([^\n]+)\n')do
    if line:sub(1,2)=='D\t'then set(line:sub(3),false)
    else
     local stamp,payload=line:match('^U\t(%d+)\t(P\t.+)$');local mark=decode(payload or line)
     mark.paintedAt=tonumber(stamp)or math.floor(os.time()-mark.wet)
     mark.wet=math.min(46,math.max(mark.wet,os.time()-mark.paintedAt));set(key(mark),mark)
    end
    events=events+1
   end
   local present=io.open(path,'rb');if present then present:close()end
   repair=not present or bytes:sub(-1)~='\n'
  else repair=true end
  -- Import old revision sidecars once per original impact. A deletion record
  -- prevents that impact reappearing when its older revision is opened again.
  for _,mark in ipairs(legacy)do local id=key(mark);if rows[id]==nil then set(id,mark);repair=true end end
  if repair or events>math.max(1024,#order*3)then checkpoint()end
  local live={};for _,id in ipairs(order)do if rows[id]then live[#live+1]=rows[id]end end
  return live
 end
 function W.checkpoint()
  if repair or events>math.max(1024,#order*3)then checkpoint()end
 end
 function W.close()
  W.checkpoint();path=nil;rows=nil;order=nil
 end
 return W
end
