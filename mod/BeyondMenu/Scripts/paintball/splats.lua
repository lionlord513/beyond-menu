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
  local position = B.valid(target) and mark.at or R.worldPoint(mark)
  mesh:K2_SetRelativeTransform({Translation=position, Rotation=A.identity.Rotation, Scale3D=A.identity.Scale3D}, false, {}, true)
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
   patch.runHeights={[0]=0};patch.step=mark.drip/4;patch.dripLimit=mark.drip
   for i=1,4 do
    local d=i*patch.step;local h=sample(P.add(origin,down,d))
    if not h then
     local midpoint=d-patch.step*.5
     local mid=sample(P.add(origin,down,midpoint))
     patch.dripLimit=mid and midpoint or (i-1)*patch.step
     patch.runHeights[i]=mid or patch.runHeights[i-1]
     break
    end
    patch.runHeights[i]=h
   end
  end
  return patch
 end

 local function appendVertex(geo, position, normal)
  geo.vertices[#geo.vertices+1]=position;geo.normals[#geo.normals+1]=normal
  geo.uv[#geo.uv+1]={X=.5,Y=.5}
  return #geo.vertices-1
 end
 local function triangle(geo,a,b,c)
  local t=geo.triangles;t[#t+1]=a;t[#t+1]=b;t[#t+1]=c
 end

 -- Add a low rounded meniscus over the original footprint. The irregular
 -- perimeter expands with volume while the older paint flecks remain in place.
 local function puddle(geo,mark,patch,record)
  if mark.pool<=0 then return end
  local settling=math.exp(-mark.wet/1.1)
  record.poolReach=math.max(record.poolReach or 0,mark.pool*(1-.28*settling))
  local r=P.random(mark.seed+447)
  local phi1,phi2,phi3=r()*tau,r()*tau,r()*tau
  local n=mark.normal;local u,v=patch.u,patch.v
  local depth=1+.28*settling
  local centre=appendVertex(geo,P.add(origin,n,.52*depth),n)
  local previous
  for _,ring in ipairs({{.62,.46,.015},{.91,.33,.055},{1,.10,.17}}) do
   local rim={}
   for i=1,40 do
    local a=tau*i/40;local x,y=math.cos(a),math.sin(a)
    local outline=record.poolReach*(1+.11*math.sin(3*a+phi1)+.075*math.sin(5*a+phi2)+.045*math.sin(8*a+phi3))
    local radial=P.add(P.add(origin,u,x*1.14),v,y)
    local pos=P.add(P.add(origin,radial,ring[1]*outline),n,ring[2]*depth)
    rim[i]=appendVertex(geo,pos,P.unit(P.add(n,radial,ring[3])))
   end
   for i=1,40 do
    local j=i%40+1
    if previous then triangle(geo,previous[i],rim[i],rim[j]);triangle(geo,previous[i],rim[j],previous[j])
    else triangle(geo,centre,rim[i],rim[j])end
   end
   previous=rim
  end
 end

 -- A continuous ribbon connects each hanging droplet to the deposit. Only its
 -- tip length changes between frames, keeping its path stable as it grows.
 local function trails(geo, mark, patch, down, radius, record)
  if mark.drip<=0 then return end
  local side = P.unit(P.cross(mark.normal,down))
  local random = P.random(mark.seed+537)
  -- Rewetting an existing run adds paint at once. It must not pull a stream
  -- back up the wall whenever an additional paintball resets the wet timer.
  local growth=mark.drip*(1-.48*math.exp(-mark.wet/2.4))
  record.dripReach=math.max(record.dripReach or 0,growth)
  local length=math.min(patch.dripLimit,record.dripReach)
  if length<radius*.4 then return end
  local count=math.min(4,1+math.floor(mark.volume/3))
  for line=1,count do
   local reach=length*(line==1 and 1 or .38+random()*.55)
   local width=.40+math.min(.78,mark.volume*.040)
   local lateral=(line==1 and 0 or ((line%2)*2-1)*math.floor(line/2)*.42)*radius
   local phase=random()*tau
   local left,middle,right
   local function point(distance)
    local bend=lateral+.35*math.sin(distance*.15+phase)+.18*math.sin(distance*.32+phase)
    local t=math.min(4,distance/patch.step)
    local k=math.min(3,math.floor(t));local h0=patch.runHeights[k] or 0;local h1=patch.runHeights[k+1] or h0
    local height=h0+(h1-h0)*(t-k)+.54
    return P.add(P.add(P.add(origin,down,distance),side,bend),mark.normal,height)
   end
   for step=0,8 do
    local fraction=step/8
    local at=point(reach*fraction)
    local w=width*(1-.5*fraction)
    local l=appendVertex(geo,P.add(at,side,-w),P.unit(P.add(mark.normal,side,-.22)))
    local m=appendVertex(geo,P.add(at,mark.normal,.16),mark.normal)
    local r=appendVertex(geo,P.add(at,side,w),P.unit(P.add(mark.normal,side,.22)))
    if left then
     triangle(geo,left,middle,l);triangle(geo,middle,m,l)
     triangle(geo,middle,right,m);triangle(geo,right,r,m)
    end
    left,middle,right=l,m,r
   end
   local at=point(reach);local centre=appendVertex(geo,P.add(at,mark.normal,.19),mark.normal);local rim={}
   for k=1,10 do
    local angle=tau*k/10
    local radial=P.add(P.add(origin,side,math.cos(angle)*1.45),down,math.sin(angle)*2)
    rim[k]=appendVertex(geo,P.add(at,radial,width),P.unit(P.add(mark.normal,radial,.17)))
   end
   for k=1,10 do triangle(geo,centre,rim[k],rim[k%10+1]) end
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
  local radius=mark.radius*1.25
  if not record.patch or record.volume~=mark.volume then
   record.patch=surface(mark,record,target,math.max(radius,mark.pool),down);record.volume=mark.volume
  end
  local patch=record.patch
  local geo=P.geometry({seed=mark.seed,normal=mark.normal,at=origin,radius=radius,
   stretch=mark.stretch,angle=mark.angle,imprints=mark.imprints,drip=0,pool=0},0)
  puddle(geo,mark,patch,record)
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
  -- A broad highlight keeps the pigment visible in direct desert sunlight.
  record.visual:SetMaterial(0,A.material(mark.color,mark.volume>1 and .63 or .56))
  record.triangles=#indices/3
  record.nextDraw=R.clock+.35
  record.dirty=false
 end
end
