-- Meshes stay centred on their own component. Far from world zero, using world
-- coordinates as float mesh vertices loses the depth offset on road surfaces.
return function(B, R)
 local P, A = R.physics, R.assets
 local mathlib = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local meshClass = StaticFindObject('/Script/ProceduralMeshComponent.ProceduralMeshComponent')
 local origin = P.v(0, 0, 0)
 local tau = math.pi * 2
 local sectors = 8

 local function create(mark, target)
  local actor = R.effectsOwner()
  local mesh = A.component(actor, meshClass)
  mesh:SetCollisionEnabled(0)
  mesh:SetGenerateOverlapEvents(false)
  mesh:SetCastShadow(false)
  if B.valid(target) then
   local bone = mark.bone ~= '' and mark.bone or 'None'
   mesh:K2_AttachToComponent(target, FName(bone), 0, 0, 0, false)
   -- Keep the attachment position in object space, but the paint diameter in
   -- centimetres even on heavily scaled walls and terrain tiles.
   mesh:SetAbsolute(false, false, true)
  end
  mesh:K2_SetRelativeTransform({Translation=mark.at, Rotation=A.identity.Rotation, Scale3D=A.identity.Scale3D}, false, {}, true)
  mesh:SetHiddenInGame(false, false)
  mesh:SetVisibility(true, false)
  return {visual=mesh, owner=actor, dirty=true}
 end

 -- Sample a small patch once. Interpolate signed height around the impact to
 -- bend wet paint across a curved panel. A missing outer sample clips that
 -- sector, but can never erase the already confirmed centre of the impact.
 local function surface(mark, record, target, radius, down)
  local normal = mark.normal
  local u, v = P.basis(normal)
  local world = record.visual:K2_GetComponentToWorld()
  local wn = mathlib:TransformDirection(world, normal)
  local ignored = {B.player()}
  local function sample(offset)
   local at = mathlib:TransformLocation(world, offset)
   local hit = R.trace(P.add(at, wn, 3), P.add(at, wn, -6), .08, ignored)
   if hit and (not B.valid(target) or (B.valid(hit.component) and hit.component:GetAddress()==target:GetAddress())) and P.dot(hit.normal,wn)>.45 then
    return P.dot(P.add(hit.at, at, -1), wn)
   end
  end
  local patch = {u=u, v=v, span=radius*1.7, heights={}, limits={}}
  for i=0,sectors-1 do
   local angle = tau*i/sectors
   local spoke = P.add(P.add(origin,u,math.cos(angle)),v,math.sin(angle))
   local h = sample(P.add(origin,spoke,patch.span))
   patch.heights[i] = h or 0
   patch.limits[i] = h and radius*3.9 or math.max(1.5,radius*.45)
  end
  if mark.drip>0 then
   patch.dripHeight = sample(P.add(origin,down,mark.drip))
   patch.dripLimit = patch.dripHeight and mark.drip or math.min(mark.drip,radius)
  end
  return patch
 end

 -- A continuous ribbon connects each hanging droplet to the deposit. Only its
 -- tip length changes between frames, keeping its path stable as it grows.
 local function trails(geo, mark, patch, down, radius, record)
  if mark.drip<=0 then return end
  local side = P.unit(P.cross(mark.normal,down))
  local random = P.random(mark.seed+537)
  -- Rewetting an existing run adds paint at once. It must not pull a stream
  -- back up the wall whenever an additional paintball resets the wet timer.
  local growth=mark.drip*(1-.65*math.exp(-mark.wet/3))
  record.dripReach=math.max(record.dripReach or 0,growth)
  local length=math.min(patch.dripLimit,record.dripReach)
  if length<radius*.4 then return end
  local function vertex(at)
   geo.vertices[#geo.vertices+1]=at
   geo.normals[#geo.normals+1]=mark.normal
   geo.uv[#geo.uv+1]={X=.5,Y=.5}
   return #geo.vertices-1
  end
  local function triangle(a,b,c)
   local t=geo.triangles;t[#t+1]=a;t[#t+1]=b;t[#t+1]=c
  end
  for line=1,3 do
   local reach=length*(line==2 and 1 or .45+random()*.42)
   local width=.24+math.min(.72,mark.volume*.025)
   local lateral=(line-2)*radius*.48
   local phase=random()*tau
   local left,right
   local function point(distance)
    local bend=lateral+.32*math.sin(distance*.18+phase)
    local height=(patch.dripHeight or 0)*(distance/mark.drip)^2+.42
    return P.add(P.add(P.add(origin,down,distance),side,bend),mark.normal,height)
   end
   for step=0,8 do
    local fraction=step/8
    local at=point(reach*fraction)
    local w=width*(1-.5*fraction)
    local l=vertex(P.add(at,side,-w));local r=vertex(P.add(at,side,w))
    if left then triangle(left,right,l);triangle(right,r,l) end
    left,right=l,r
   end
   local at=point(reach);local centre=vertex(at);local rim={}
   for k=1,10 do
    local angle=tau*k/10
    rim[k]=vertex(P.add(P.add(at,side,math.cos(angle)*width*1.5),down,math.sin(angle)*width*2))
   end
   for k=1,10 do triangle(centre,rim[k],rim[k%10+1]) end
  end
 end

 return function(mark)
  local target=R.resolve(mark)
  if mark.owner~='' and not B.valid(target) then return end
  local record=R.rendered[mark]
  if not record or not B.valid(record.visual) then
   record=create(mark,target);R.rendered[mark]=record
  end
  local down=P.unit(P.add(mark.gravity,mark.normal,-P.dot(mark.gravity,mark.normal)))
  local radius=math.max(mark.radius*1.25,mark.pool)
  if not record.patch or record.volume~=mark.volume then
   record.patch=surface(mark,record,target,radius,down);record.volume=mark.volume
  end
  local patch=record.patch
  local geo=P.geometry({seed=mark.seed,normal=mark.normal,at=origin,radius=radius,
   stretch=mark.stretch,drip=0,pool=0},0)
  local keep={}
  for i,point in ipairs(geo.vertices) do
   local x,y=P.dot(point,patch.u),P.dot(point,patch.v)
   local s=(math.atan(y,x)%tau)*sectors/tau
   local a=math.floor(s)%sectors;local b=(a+1)%sectors;local t=s-math.floor(s)
   local distance=math.sqrt(x*x+y*y)
   local h=patch.heights[a]*(1-t)+patch.heights[b]*t
   local limit=patch.limits[a]*(1-t)+patch.limits[b]*t
   -- Keep the central fan on a narrow post even when all outer probes miss.
   -- Its rim pulls back to the supported patch; satellite drops can disappear.
   if i<=65 and distance>limit then
    point=P.add(origin,point,limit/distance)
    distance=limit
   end
   keep[i-1]=distance<=limit
   geo.vertices[i]=P.add(point,mark.normal,.38+h*math.min(2,distance/patch.span)^2)
  end
  local initial=#geo.vertices
  trails(geo,mark,patch,down,radius,record)
  for i=initial,#geo.vertices-1 do keep[i]=true end
  local indices={}
  for i=1,#geo.triangles,3 do
   local a,b,c=geo.triangles[i],geo.triangles[i+1],geo.triangles[i+2]
   if keep[a] and keep[b] and keep[c] then
    indices[#indices+1]=a;indices[#indices+1]=b;indices[#indices+1]=c
    indices[#indices+1]=a;indices[#indices+1]=c;indices[#indices+1]=b
   end
  end
  record.visual:CreateMeshSection(0,geo.vertices,indices,geo.normals,geo.uv,{},{},false)
  record.visual:SetMaterial(0,A.material(mark.color,.22))
  record.triangles=#indices/3
  record.nextDraw=R.clock+.35
  record.dirty=false
 end
end
