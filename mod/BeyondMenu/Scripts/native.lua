return function(B)
 local N={queue={},requested={},textures={},revision=3};local dll=B.root..'/assets/native/BeyondMenuImaging.dll'
 N.render=assert(package.loadlib(dll,'bm_render'));N.pointer=assert(package.loadlib(dll,'bm_pointer'))
 local done=B.root..'/state/paint-done.txt'
 function N.mouse()
  N.pointer();local f=io.open(B.root..'/state/pointer.txt','r');if not f then return false,0,0 end
  local s=f:read('*a');f:close();local focus,x,y=s:match('^(%d) ([%d.e+-]+) ([%d.e+-]+)');return focus=='1',tonumber(x)or 0,tonumber(y)or 0
 end
 function N.newSelection()
  for _,q in ipairs(N.queue)do N.requested[q.key]=nil end;N.queue={}
 end
 function N.prioritize(slots,tuned)
  local wanted={}
  for _,s in ipairs(slots or{})do local r=s.row;wanted[(r.provider and r.item or tostring(r.id))..(tuned and not r.provider and'-tuned'or'-stock')..(B.ui.carMetallic and'-metal'or'-matte')]=true end
  local first,last={},{};for _,q in ipairs(N.queue)do local list=wanted[q.base]and first or last;list[#list+1]=q end
  for _,q in ipairs(last)do first[#first+1]=q end;N.queue=first
 end
 function N.icon(row,tuned,rgb,metallic,prepareOnly)
  local id=row.provider and row.item or tostring(row.id)
  local base=id..(tuned and not row.provider and'-tuned'or'-stock')..(metallic and'-metal'or'-matte')
  local r,g,b=math.floor(rgb[1]*255+.5),math.floor(rgb[2]*255+.5),math.floor(rgb[3]*255+.5)
  local key=base..('-v%d-%02x%02x%02x'):format(N.revision,r,g,b);local file=B.root..'/state/paint/'..key..'.png'
  local tex=N.textures[key];if B.valid(tex)then return tex end
  local f=io.open(file,'rb');if f then f:close();if prepareOnly then return end;tex=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(B.pc(),file);N.textures[key]=tex;return tex end
  if not N.requested[key]then N.requested[key]=true;N.queue[#N.queue+1]={base=base,r=r,g=g,b=b,key=key,revision=N.revision}end
 end
 function N.tick()
  if N.busy then
   if B.ui.opened and os.clock()>=(N.refreshAt or 0)then N.refreshAt=os.clock()+.1;B.ui.refreshIcons()end
   local f=io.open(done,'r');if not f then return end;local result=f:read('*a');f:close();os.remove(done);N.busy=false
   local _,failed=result:match('^(%d+) (%d+)');if tonumber(failed or 0)>0 then B.log('Some vehicle thumbnails could not be rendered')end
   if B.ui.opened then B.ui.refreshIcons()end
  end
  if #N.queue==0 then return end
  local first=table.remove(N.queue,1);local batch={first};local keep={}
  for _,q in ipairs(N.queue)do if #batch<9 and q.r==first.r and q.g==first.g and q.b==first.b and q.revision==first.revision then batch[#batch+1]=q else keep[#keep+1]=q end end;N.queue=keep
  local f=assert(io.open(B.root..'/state/paint-request.txt','w'));f:write(('%d %d %d %d\n'):format(first.r,first.g,first.b,first.revision));for _,q in ipairs(batch)do f:write(q.base,'\n')end;f:close()
  os.remove(done);N.busy=true;N.render()
 end
 return N
end
