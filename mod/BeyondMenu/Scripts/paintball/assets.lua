return function(B,P)
 local A={cache={},materials={},voices={}};local valid=B.valid
 local identity={Translation=P.v(0,0,0),Rotation={X=0,Y=0,Z=0,W=1},Scale3D=P.v(1,1,1)};A.identity=identity
 local meshClass=StaticFindObject('/Script/Engine.StaticMeshComponent')
 local function offset(o,name)local n;o:ForEachProperty(function(p)if p:GetFName():ToString()==name then n=p:GetOffset_Internal()end end);assert(n,'Model loader field missing: '..name);return n end
 function A.component(owner,kind)
  local c=owner:AddComponentByClass(kind or meshClass,true,identity,false);assert(valid(c),'Paintball component creation failed')
  c:SetComponentTickEnabled(false);c:SetIsReplicated(false)
  if kind==nil or kind==meshClass then c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false)end
  return c
 end
 function A.mesh(name)
  local old=A.cache[name];if old and valid(old.holder)and valid(old.mesh)then return old.mesh end
  local dll=B.root..'/assets/native/BeyondPaintballMesh.dll'
  local load=assert(package.loadlib(dll,'ba_load_asset'));local build=assert(package.loadlib(dll,'ba_load_chassis'))
  local lib=StaticFindObject('/Script/glTFRuntime.Default__glTFRuntimeFunctionLibrary')
  local fn=StaticFindObject('/Script/glTFRuntime.glTFRuntimeFunctionLibrary:glTFLoadAssetFromFilename');local cfg=StaticFindObject('/Script/glTFRuntime.glTFRuntimeConfig')
  assert(valid(lib)and valid(fn),'This game build has no runtime model loader')
  local addr,why=load(lib:GetAddress(),fn:GetAddress(),offset(fn,'LoaderConfig'),offset(fn,'ReturnValue'),B.root..'/assets/paintball/'..name..'.glb',offset(cfg,'SceneScale'),offset(cfg,'TransformBaseType'))
  local asset;for _,a in ipairs(FindAllOf('glTFRuntimeAsset')or{})do if a:GetAddress()==addr then asset=a;break end end
  assert(valid(asset),'Paintball model import failed: '..tostring(why or name))
  local owner=B.pc();local holder=A.component(owner);holder:SetVisibility(false,false);holder:SetCastShadow(false)
  local mesh
  if name=='marker' then
   -- The importer constructs each Chaos shape from plain FBox bounds while
   -- building the mesh. Keep its outer on the cache holder for the world.
   local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
   local class=StaticFindObject('/Script/glTFRuntime.glTFRuntimeAssetActor')
   local loader=game:BeginDeferredActorSpawnFromClass(owner,class,identity,1,nil,0)
   assert(valid(loader),'Marker import actor creation failed')
   local ok,result=pcall(function()
    local boxes={}
    for _,b in ipairs(dofile(B.root..'/Scripts/paintball/collision_boxes.lua')) do
     boxes[#boxes+1]={Min=P.v(b[1],b[2],b[3]),Max=P.v(b[4],b[5],b[6]),IsValid=1}
    end
    loader.Asset=asset;loader:SetActorHiddenInGame(true);loader:SetActorEnableCollision(false)
    local config=loader.StaticMeshConfig
    config.Outer=holder;config.BoxCollisions=boxes;config.bBuildSimpleCollision=false
    config.bBuildComplexCollision=true;config.bAllowCPUAccess=true;config.MaterialsConfig.bSkipLoad=true
    game:FinishSpawningActor(loader,identity,0)
    local component=loader:GetComponentByClass(meshClass)
    assert(valid(component)and valid(component.StaticMesh),'Marker model did not load')
    local result=component.StaticMesh
    assert(result.BodySetup.AggGeom.BoxElems:GetArrayNum()==#boxes,'Marker compound collision did not load')
    assert(holder:SetStaticMesh(result),'Marker cache assignment failed')
    return result
   end)
   loader:K2_DestroyActor()
   if not ok then holder:K2_DestroyComponent(owner);error(result)end
   mesh=result
  else
   fn=StaticFindObject('/Script/glTFRuntime.glTFRuntimeAsset:LoadStaticMesh');cfg=StaticFindObject('/Script/glTFRuntime.glTFRuntimeStaticMeshConfig')
   addr=build(asset:GetAddress(),fn:GetAddress(),offset(fn,'StaticMeshConfig'),offset(fn,'ReturnValue'),offset(cfg,'bBuildSimpleCollision'),offset(cfg,'bBuildComplexCollision'))
   for _,m in ipairs(FindAllOf('StaticMesh')or{})do if m:GetAddress()==addr then mesh=m;break end end
   assert(valid(mesh),'Paintball model build failed: '..name)
   assert(holder:SetStaticMesh(mesh),'Mesh assignment failed')
  end
  A.cache[name]={mesh=mesh,holder=holder,owner=owner};return mesh
 end
 function A.texture(name)
  A.textures=A.textures or{};if valid(A.textures[name])then return A.textures[name]end
  local t=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(B.pc(),B.root..'/assets/paintball/'..name..'.png');assert(valid(t),'Paint texture missing: '..name);A.textures[name]=t;return t
 end
 function A.pbr(diffuse,roughness,metal)
  local parent=LoadAsset('/MasterWeapon/Materials/Weapons/MAT_ArK47.MAT_ArK47')
  local m=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(B.pc(),parent,FName('BeyondPaintballPBR'),0)
  m:SetTextureParameterValue(FName('Diffuse'),diffuse);m:SetTextureParameterValue(FName('NormalMap'),A.texture('normal'));m:SetTextureParameterValue(FName('AOMap'),A.texture('white'))
  m:SetTextureParameterValue(FName('RoughnessMap'),type(roughness)=='string'and A.texture(roughness)or A.texture('white'))
  m:SetTextureParameterValue(FName('MetalMap'),type(metal)=='string'and A.texture(metal)or A.texture('black'))
  m:SetScalarParameterValue(FName('DiffuseBrightness'),1);m:SetScalarParameterValue(FName('AODarkness'),1);m:SetScalarParameterValue(FName('RoughnessBrightness'),type(roughness)=='number'and roughness or 1)
  return m
 end
 function A.material(color,roughness)
  local key=('%02x%02x%02x'):format(math.floor(color[1]^.4545*255+.5),math.floor(color[2]^.4545*255+.5),math.floor(color[3]^.4545*255+.5))..'-'..tostring(roughness or .16);local old=A.materials[key];if valid(old)then return old end
  local file=B.root..'/state/paint-color-'..key..'.bmp';local f=assert(io.open(file,'wb'))
  local pixel=string.char(math.floor(color[3]^.4545*255+.5),math.floor(color[2]^.4545*255+.5),math.floor(color[1]^.4545*255+.5),0)
  f:write('BM'..string.pack('<I4I2I2I4I4i4i4I2I2I4I4i4i4I4I4',58,0,0,54,40,1,1,1,24,0,4,2835,2835,0,0)..pixel);f:close()
  local diffuse=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(B.pc(),file);assert(valid(diffuse),'Paint color texture failed')
  local m=A.pbr(diffuse,roughness or .16,0)
  A.materials[key]=m;return m
 end
 function A.skin(c,name)
  if name=='marker'then
   A.markerMaterial=valid(A.markerMaterial)and A.markerMaterial or A.pbr(A.texture('marker-albedo'),'marker-roughness','marker-metallic')
   c:SetMaterial(0,A.markerMaterial);c:SetMaterial(1,A.material({.0305,.0305,.0305},.28));c:SetMaterial(2,A.material({.1336,.1179,.1218},.24));c:SetMaterial(3,A.material({.3093,.3093,.3093},.22))
  elseif name=='canister'then
   if not valid(A.glass)then A.glass=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(B.pc(),LoadAsset('/Game/Environments/Materials/Master/MI_GarageGlass.MI_GarageGlass'),FName('PaintballPodShell'),0);A.glass:SetScalarParameterValue(FName('Opacity'),.3);A.glass:SetScalarParameterValue(FName('Roughness'),.13);A.glass:SetScalarParameterValue(FName('IOR'),1.1)end
   c:SetMaterial(0,A.glass);c:SetMaterial(1,A.material({.008,.008,.01},.55))
  end
 end
 function A.visual(owner,name,parent,tr)
  local c=A.component(owner);assert(c:SetStaticMesh(A.mesh(name)),'Paintball visual failed')
  if valid(parent)then c:K2_AttachToComponent(parent,FName('BM_Paintball_'..name),0,0,0,false)end
  c:K2_SetRelativeTransform(tr or identity,false,{},true);A.skin(c,name);return c
 end
 -- Decode once per independent voice so close shots and impacts can overlap.
 local function bytes(name)
  A.encoded=A.encoded or {}
  if not A.encoded[name] then
   local file=assert(io.open(B.root..'/assets/paintball/'..name,'rb'))
   local data=file:read('*a');file:close()
   local buffer={}
   for i=1,#data do buffer[i]=data:byte(i) end
   A.encoded[name]=buffer
  end
  return A.encoded[name]
 end
 function A.audio()
  local index=#A.voices
  if index>=12 then return end
  local impact=index%2==1
  local group=impact and ('impact'..math.floor(index/2)%3) or 'shot'
  local w=StaticFindObject('/Script/RuntimeAudioImporter.Default__StreamingSoundWave'):CreateStreamingSoundWave()
  local holder=A.component(B.pc(),StaticFindObject('/Script/Engine.AudioComponent'))
  holder:SetAutoActivate(false);holder:SetSound(w)
  local original=LoadAsset('/Game/Sound/Player/Combat/Ak47/Ak_Shot.Ak_Shot')
  w.SoundClassObject=original.SoundClassObject;w.AttenuationSettings=original.AttenuationSettings
  w:SetStopSoundOnPlaybackFinish(true);w:SetLooping(false);w:SetVolume(impact and .55 or .9)
  w:AppendAudioDataFromEncoded(bytes(group..'.mp3'),0)
  A.voices[#A.voices+1]={wave=w,holder=holder,owner=B.pc(),group=group}
 end
 local function play(group,at)
  local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
  for _,v in ipairs(A.voices) do
   if v.group==group and valid(v.wave) and v.wave:GetDurationConst()>0 and not v.wave:IsPlaying(B.pc()) then
    v.wave:RewindPlaybackTime(0)
    game:PlaySoundAtLocation(B.pc(),v.wave,at,{Pitch=0,Yaw=0,Roll=0},1,.97+math.random()*.06,0,nil,nil,nil,nil)
    return
   end
  end
 end
 function A.shot(at)play('shot',at)end
 function A.impactSound(at,seed)play('impact'..(seed%3),at)end
 function A.reset()
  for _,r in pairs(A.cache)do if valid(r.owner)and valid(r.holder)then r.holder:K2_DestroyComponent(r.owner)end end
  for _,r in ipairs(A.voices)do if valid(r.owner)and valid(r.holder)then r.holder:K2_DestroyComponent(r.owner)end end
  A.cache={};A.materials={};A.voices={};A.textures={};A.markerMaterial=nil;A.glass=nil
 end
 return A
end
