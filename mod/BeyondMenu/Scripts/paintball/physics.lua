-- Centimetres, seconds, metres/second converted at the simulation boundary.
-- Rendering and native object access live in runtime.lua; this module is testable.
local P={radius=.865,speed=8500,gravity=980,drag=.000045,step=1/240,maxAge=6}
function P.v(x,y,z)return {X=x,Y=y,Z=z}end
function P.add(a,b,s)return P.v(a.X+b.X*(s or 1),a.Y+b.Y*(s or 1),a.Z+b.Z*(s or 1))end
function P.dot(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
function P.cross(a,b)return P.v(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end
function P.unit(a)local l=math.sqrt(P.dot(a,a));return l>1e-10 and P.v(a.X/l,a.Y/l,a.Z/l)or P.v(0,0,1)end
function P.distance(a,b)local d=P.add(a,b,-1);return P.dot(d,d)end
function P.random(seed)
 return function()seed=(1664525*seed+1013904223)&0xffffffff;return seed/4294967296 end
end
-- Mix the seed before drawing shape parameters. Neighbouring shot seeds must
-- not share the same first lobe count, drop density and stretch.
local function shapeRandom(seed)
 local x=seed&0xffffffff
 x=((x~(x>>16))*0x7feb352d)&0xffffffff
 x=((x~(x>>15))*0x846ca68b)&0xffffffff
 return P.random(x~(x>>16))
end
function P.color(c)
 assert(type(c)=='table' and #c==3,'Choose an RGB color')
 local out={};for i=1,3 do local n=c[i];assert(type(n)=='number'and n==n and n>=0 and n<=1,'Invalid paint color');out[i]=n end;return out
end
function P.basis(n)
 local u=P.unit(P.cross(math.abs(n.Z)<.9 and P.v(0,0,1)or P.v(0,1,0),n));return u,P.cross(n,u)
end
function P.launch(at,direction,color,seed)
 return {at=at,velocity=P.add(P.v(0,0,0),P.unit(direction),P.speed),color=P.color(color),seed=seed,age=0}
end
function P.advance(ball,dt,trace)
 -- Sweep every substep, including the real .68-calibre radius. No tunnelling.
 dt=math.min(math.max(dt,0),.1)
 while dt>1e-8 do
  local h=math.min(dt,P.step);local v=ball.velocity;local speed=math.sqrt(P.dot(v,v))
  local decay=math.exp(-P.drag*speed*h)
  local nextv=P.v(v.X*decay,v.Y*decay,v.Z*decay-P.gravity*h)
  local nextp=P.add(ball.at,P.add(v,nextv),h*.5)
  local hit=trace and trace(ball.at,nextp,P.radius)
  if hit then ball.at=hit.at;ball.age=ball.age+h;return hit end
  ball.at=nextp;ball.velocity=nextv;ball.age=ball.age+h;dt=dt-h
 end
 if ball.age>P.maxAge then return false end
end
function P.impact(at,normal,color,seed,speed,incidence)
 local r=shapeRandom(seed);normal=P.unit(normal)
 return {at=at,normal=normal,gravity=P.v(0,0,-1),color=P.color(color),seed=seed,
  radius=2.9+r()*3.5,stretch=1+math.min(1.8,(1-math.abs(incidence or 1))*2),
  volume=1,wet=0,drip=0,pool=0,kind='splat'}
end
function P.accumulate(p,c,amount)
 amount=amount or 1;local total=p.volume+amount
 -- Mix actual pigment in linear light, retaining all previously deposited mass.
 for i=1,3 do p.color[i]=(p.color[i]*p.volume+c[i]*amount)/total end
 p.volume=total;p.wet=0
 local up=-P.dot(p.normal,p.gravity)
 local vertical=math.sqrt(math.max(0,1-up*up))
 if p.volume>=2 and vertical>.38 then p.drip=math.min(80,(p.radius+9*(p.volume-1)^.64)*vertical)end
 if up>.65 and p.volume>=2 then p.pool=math.min(65,p.radius+4.3*math.sqrt(p.volume-1))*math.sqrt(up)end
end
function P.depositOffset(old,hit,scale)
 if old.wet>=45 or P.dot(old.normal,hit.normal)<.83 then return end
 local x,y,z=hit.at.X-old.at.X,hit.at.Y-old.at.Y,hit.at.Z-old.at.Z
 if scale then x,y,z=x*scale.X,y*scale.Y,z*scale.Z end
 local reach=math.min(27,old.radius+hit.radius+3+(old.pool or 0)*.65)
 local distance=x*x+y*y+z*z
 if distance>reach*reach or math.abs(x*old.normal.X+y*old.normal.Y+z*old.normal.Z)>math.min(3,reach*.19)then return end
 return distance,P.v(x,y,z)
end
-- A burst may throw out a narrow sheet, a few heavy lobes, a crown of thin
-- fingers or a cloud of fine drops. Generate the outline and secondary drops
-- from the same jets so their placement follows the direction of the splash.
function P.geometry(p)
 local rng=shapeRandom(p.seed);local u,v=P.basis(p.normal);local tau=math.pi*2
 local vertices,triangles,normals,uv={},{},{},{}
 local function vertex(x,y,h,n,tx,ty)
  vertices[#vertices+1]=P.add(P.add(P.add(p.at,u,x),v,y),p.normal,h)
  normals[#normals+1]=n;uv[#uv+1]={X=tx,Y=ty}
 end
 local function fan(cx,cy,radius,stretch,heading,segments,outline,depth)
  local first=#vertices;local co,si=math.cos(heading),math.sin(heading)
  vertex(cx,cy,depth+.09,p.normal,.5,.5)
  for i=0,segments-1 do
   local a=i*tau/segments;local dx,dy=math.cos(a),math.sin(a)
   local r=radius*(outline and outline(a)or 1)
   local x,y=dx*stretch,dy
   local nx,ny=dx*co-dy*si,dx*si+dy*co
   vertex(cx+r*(x*co-y*si),cy+r*(x*si+y*co),depth,
    P.unit(P.add(P.add(p.normal,u,nx*.12),v,ny*.12)),.5+dx*.5,.5+dy*.5)
   triangles[#triangles+1]=first;triangles[#triangles+1]=first+1+i;triangles[#triangles+1]=first+1+(i+1)%segments
  end
 end
 local radius=p.radius;local mode=math.floor(rng()*6)
 local heading=(p.angle or rng()*tau)+(rng()-.5)*.35
 local stretch=math.min(2.9,(p.stretch or 1)*(mode==1 and 1.35+rng()*.5 or .90+rng()*.28))
 local count=({3,2,9,4,6,2})[mode+1]+math.floor(rng()*(mode==2 and 6 or 4))
 local jets={};local firstJet=rng()*tau
 for i=1,count do
  local a=(firstJet+tau*(i-1+rng()*.8)/count)%tau
  if mode==1 then a=(rng()-.5)*1.7 end
  jets[i]={a=a,width=(mode==2 and .065 or .11)+rng()*(mode==0 and .39 or .21),
   length=(mode==3 and .12 or .30)+rng()*(mode==2 and 1.15 or .85)}
 end
 local contour={};local knots=7+math.floor(rng()*5)
 for i=1,knots do contour[i]=.42+rng()*(mode==3 and .28 or .55)end
 local function outline(a)
  local index=(a%tau)*knots/tau;local i=math.floor(index)%knots;local f=index-math.floor(index);f=f*f*(3-2*f)
  local r=contour[i+1]*(1-f)+contour[(i+1)%knots+1]*f
  for _,jet in ipairs(jets)do
   local distance=math.abs((a-jet.a+math.pi)%tau-math.pi)/jet.width
   if distance<1 then r=r+jet.length*(1-distance*distance)^2 end
  end
  return r
 end
 fan(0,0,radius,stretch,heading,64,outline,.045)
 local co,si=math.cos(heading),math.sin(heading)
 -- Surface tension gathers liquid at the tips of the thicker fingers. Leave
 -- some thin jets broken between the rim and their first detached droplet.
 for _,jet in ipairs(jets)do
  if jet.width>.17 and rng()<.54 then
   local a=jet.a;local r=radius*outline(a)*(.85+rng()*.10)
   local x,y=math.cos(a)*r*stretch,math.sin(a)*r
   fan(x*co-y*si,x*si+y*co,radius*(.10+rng()*.16),1+rng()*.60,heading+a,10,nil,.055)
  end
 end
 local drops=({5,12,18,3,25,8})[mode+1]+math.floor(rng()*9)
 for i=1,drops do
  local jet=jets[1+math.floor(rng()*count)];local a=jet.a+(rng()-.5)*jet.width*2.5
  local r=radius*(outline(a)+.18+rng()^1.5*(mode==4 and 2.2 or 1.65))
  local x,y=math.cos(a)*r*stretch,math.sin(a)*r
  local size=radius*(.045+rng()^2*(mode==0 and .38 or .23))
  fan(x*co-y*si,x*si+y*co,size,1+rng()*(mode==1 and 2.9 or .95),heading+a,7,nil,.035)
 end
 for _,hit in ipairs(p.imprints or {})do
  local r=shapeRandom(hit.seed);local skew=r()*tau;local waves=3+math.floor(r()*5)
  fan(hit.x,hit.y,hit.radius*.80,1+r()*.55,skew,19,function(a)return .79+.21*math.cos(waves*a+skew)+.08*math.sin(a*11)end,.07)
 end
 return {vertices=vertices,triangles=triangles,normals=normals,uv=uv}
end
return P
