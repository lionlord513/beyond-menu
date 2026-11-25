return function(B)
 local C={items={},cars={},byPath={},icons={},fileIcons={},recent={},lastCarIcons={}};local valid=B.valid
 local function path(cls)return cls:GetFullName():match('^%S+ (.+)$')end
 local function title(cls)
  local name=cls:GetFName():ToString():gsub('_C$',''):gsub('^BP_',''):gsub('(%l)(%u)','%1 %2'):gsub('_',' ')
  return name
 end
 local function add(cls,name,icon,category)
  if not valid(cls)then return end;local key=path(cls);if key:find('/Debug_AK.',1,true)or key:find('/Items/Master/',1,true)then return end;local row=C.byPath[key]
  if not row then row={id=key,path=key,class=cls,name=name or title(cls),category=category or'Items'};C.items[#C.items+1]=row;C.byPath[key]=row end
  if name and name~=''then row.name=name end
  if valid(icon)then row.texture=icon;C.icons[key]=icon end
  return row
 end
 function C.ensure()
  if C.loaded then return end
  local p=B.player()or B.pc();local helper=StaticFindObject('/Game/BP/Helper/HelperFunction.Default__HelperFunction_C')
  local map={};helper:GetMapItemTexture(p,map)
  for k,v in pairs(map.ItemTexture or{})do add(k:get(),nil,v:get())end
  local ac=LoadAsset('/Game/BP/EbaySystem/AC_EbaySystem.AC_EbaySystem_C'):GetCDO()
  for _,spec in ipairs({{'PrimaryData','Structure','Car parts'},{'PrimaryData_ToolsKing','ToolsKingMap','Tools'},{'PrimaryData_Sofa','SofaStructure','Furniture'},{'PrimaryData_CK','CustomKultMap','Decorations'}})do
   local data=ac[spec[1]];if valid(data)then data[spec[2]]:ForEach(function(_,v)local d=v:get();add(d.ItemClass,d.HUDName:ToString(),d.Icon,spec[3])end)end
  end
  -- Supplement native data with paths extracted from the owner's current game.
  -- Missing classes are never presented as working entries.
  for _,r in ipairs(dofile(B.root..'/Scripts/native_paths.lua'))do
   if not C.byPath[r[2]]then local cls=LoadAsset(r[2]);if valid(cls)then add(cls,r[1])end end
  end
  local cars={};helper:GetVehiclesInGame(p,cars)
  local carNames={TrailerBase='Trailer',BarrelCar='Barrel car',HoistCar='Hoist car',KaijuG54='Kaiju G54',RotorGT7='Rotor GT7',Remorque2000='Remorque 2000'}
  for _,v in ipairs(cars)do
   local cls=v:get();if valid(cls)then local d=cls:GetCDO();local name={};helper:GetVehicleName(d.VehicleType,p,name)
    local label=name.Value and tostring(name.Value:ToString())or title(cls)
    C.cars[#C.cars+1]={id=d.VehicleType,path=path(cls),class=cls,name=carNames[label]or label,category='Cars'}
   end
  end
  local names={AkBullet_C='Rifle ammo',AkWeapon_C='AK-47',BumpGun_C='Bump gun',['3DPlasticMaster_C']='Printer filament',AlcoolMaster_C='Liquor bottle'}
  for _,row in ipairs(C.items)do row.name=names[row.class:GetFName():ToString()]or row.name end
  table.sort(C.items,function(a,b)return a.name:lower()<b.name:lower()end);table.sort(C.cars,function(a,b)return a.name:lower()<b.name:lower()end)
  C.loaded=true;B.log(('Catalog: %d items, %d cars'):format(#C.items,#C.cars))
 end
 function C.filtered(cars,query,category)
  C.ensure();query=(query or''):lower();local rows={};local list={}
  for _,r in ipairs(cars and C.cars or C.items)do list[#list+1]=r end
  for _,r in ipairs(B.optional.rows)do if (cars and r.vehicle)or(not cars and not r.vehicle)then list[#list+1]=r end end
  for _,r in ipairs(list)do if (category=='All'or not category or r.category==category)and(query==''or r.name:lower():find(query,1,true))then rows[#rows+1]=r end end
  return rows
 end
 function C.baseIcon(row,cars,tuned)
  if row.provider and not cars then return B.optional.icon(row)end
  local id=row.provider and row.item or row.id
  local file=B.root..'/assets/'..(cars and('cars/'..id..(tuned and not row.provider and'-tuned'or'-stock'))or('items/'..row.class:GetFName():ToString()))..'.png'
  if cars or not valid(row.texture)then
   local tex=C.fileIcons[file];if valid(tex)then return tex end
   local f=io.open(file,'rb');if f then f:close();tex=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(B.pc(),file);C.fileIcons[file]=tex;if valid(tex)then return tex end end
  end
  if valid(row.texture)then return row.texture end
  if row.provider then return B.optional.icon(row)end
  return C.icons[row.path]
 end
 function C.icon(row,cars,tuned)
  if cars then
   local key=tostring(row.id)..tostring(tuned);local tex=B.native.icon(row,tuned,B.ui.carPaint,B.ui.carMetallic)
   if valid(tex)then C.lastCarIcons[key]=tex;return tex end
   if valid(C.lastCarIcons[key])then return C.lastCarIcons[key]end
  end
  return C.baseIcon(row,cars,tuned)
 end
 function C.preparePaint()
  B.native.newSelection()
  if B.ui.preview then B.native.icon(B.ui.preview,B.ui.tuned,B.ui.carPaint,B.ui.carMetallic,true)end
  for _,slot in ipairs(B.ui.iconSlots or{})do B.native.icon(slot.row,B.ui.tuned,B.ui.carPaint,B.ui.carMetallic,true)end
  for _,row in ipairs(C.filtered(true,'','All'))do
   B.native.icon(row,false,B.ui.carPaint,B.ui.carMetallic,true)
   if not row.provider then B.native.icon(row,true,B.ui.carPaint,B.ui.carMetallic,true)end
  end
 end
 function C.warm()
  if not C.loaded then C.ensure();C.preparePaint()end
  if not C.warmRows then C.warmRows=C.filtered(true,'','All');C.warmAt=1 end
  for _=1,2 do
   local n=C.warmAt;local row=C.warmRows[math.floor((n-1)/2)+1];if not row then return end
   C.baseIcon(row,true,n%2==0);C.warmAt=n+1
  end
 end
 function C.preview(row,tuned)return C.icon(row,true,tuned)end
 function C.spawn(row,cars,tuned)
  if row.provider then return B.optional.spawn(row,cars and B.ui.carPaint or nil,B.ui.carMetallic)end
  if cars then
   B.context();assert(not valid(B.pc().Vehicle),'Leave your vehicle first')
   if not B.host()then
    if not C.guest then
     C.guestData={entries={},toggles={}};for _,r in ipairs(C.cars)do C.guestData.entries['car_'..r.id]={title=r.name}end
     C.guest=dofile(B.root..'/Scripts/guest_vehicle.lua')(C.guestData,B.H,valid,B.status)
    end
    C.guestData.toggles.tunedCars=tuned==true;C.guestData.color=B.ui.carPaint;C.guestData.metallic=B.ui.carMetallic;return C.guest.start(row.id)
   end
   local c=B.ui.carPaint
   B.pc().BP_DebugMenuComponent:SpawnCar(row.id,false,true,B.ui.carMetallic,{R=c[1],G=c[2],B=c[3],A=1},tuned==true)
   return row.name..' spawned'..(tuned and' with tuned parts'or'')
  end
  local _,result=B.actions.spawn(row.class);return result
 end
 function C.tick()if C.guest then C.guest.tick()end end
 function C.reset()if C.guest then C.guest.reset()end;C.items={};C.cars={};C.byPath={};C.icons={};C.fileIcons={};C.lastCarIcons={};C.loaded=false;C.warmRows=nil end
 return C
end
