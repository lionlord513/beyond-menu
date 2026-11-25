-- Optional providers are read only until the local host requests a catalog item.
return function(B)
 local O={rows={},icons={},sequence=0};local valid=B.valid
 function O.refresh()
  O.rows={}
  for _,provider in ipairs({'Apocalypse','Tuning'})do
   local data=ModRef:GetSharedVariable('BM_'..provider..'_Catalog')
   if type(data)=='string'and ModRef:GetSharedVariable('BM_'..provider..'_Active')~=false then for line in data:gmatch('[^\n]+')do
    local id,name,icon=line:match('^([%w_]+)|([^|]+)|([^|]*)$')
    if id then
     local vehicle=provider=='Apocalypse'and(id=='airframe'or id=='motorcycle'or id=='suzuki'or id=='trailer')
     O.rows[#O.rows+1]={id='mod:'..provider..':'..id,provider=provider,item=id,name=id=='airframe'and'Hornet gyrocopter'or name,iconPath=icon,vehicle=vehicle,category=vehicle and'Cars'or'Beyond mods'}
    end
   end end
  end
 end
 function O.spawn(row,rgb,metallic)
  B.context(true);assert(not O.pending,'Wait for the previous item')
  assert(type(ModRef:GetSharedVariable('BM_'..row.provider..'_Catalog'))=='string','This mod is no longer active')
  O.sequence=O.sequence+1;local seq=tostring(os.time())..'-'..O.sequence
  local paint=rgb and('|%.6f,%.6f,%.6f,%d'):format(rgb[1],rgb[2],rgb[3],metallic and 1 or 0)or''
  ModRef:SetSharedVariable('BM_'..row.provider..'_Request',seq..'|'..row.item..paint)
  O.pending={provider=row.provider,seq=seq,untilTime=os.clock()+15}
  return'Spawning '..row.name
 end
 function O.icon(row)
  if row.iconPath==''then return end
  local tex=O.icons[row.iconPath];if not valid(tex)then
   local f=io.open(row.iconPath,'rb');if not f then return end;f:close()
   tex=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(B.pc(),row.iconPath);O.icons[row.iconPath]=tex
  end
  return tex
 end
 function O.tick()
  local p=O.pending;if not p then return end
  local reply=ModRef:GetSharedVariable('BM_'..p.provider..'_Result')
  if type(reply)=='string'and reply:sub(1,#p.seq+1)==p.seq..'|'then B.status(reply:sub(#p.seq+2));O.pending=nil
  elseif os.clock()>p.untilTime then O.pending=nil;B.status('Spawn was not confirmed; no duplicate request sent')end
 end
 function O.reset()O.pending=nil;O.rows={};O.icons={}end
 return O
end
