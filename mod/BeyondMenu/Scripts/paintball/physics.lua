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
 local r=P.random(seed);normal=P.unit(normal)
 return {at=at,normal=normal,gravity=P.v(0,0,-1),color=P.color(color),seed=seed,
  radius=3.1+r()*2.3,stretch=1+math.min(1.8,(1-math.abs(incidence or 1))*2),
  volume=1,wet=0,drip=0,pool=0,kind='splat'}
end
function P.accumulate(p,c,amount)
 amount=amount or 1;local total=p.volume+amount
 -- Mix actual pigment in linear light, retaining all previously deposited mass.
 for i=1,3 do p.color[i]=(p.color[i]*p.volume+c[i]*amount)/total end
 p.volume=total;p.wet=0
 local up=-P.dot(p.normal,p.gravity)
 local vertical=math.sqrt(math.max(0,1-up*up))
 if p.volume>=3 and vertical>.3 then p.drip=math.min(80,(p.volume-2)^.7*5*vertical)end
 if up>.65 and p.volume>=3 then p.pool=math.sqrt(p.volume-2)*2.8 end
end
function P.geometry(p,age)
 local rng=P.random(p.seed);local u,v=P.basis(p.normal)
 local vertices,triangles,normals,uv={},{},{},{}
 local function point(x,y,z)
  return P.add(P.add(P.add(p.at,u,x),v,y),p.normal,z or .035)
 end
 local function fan(cx,cy,radius,stretch,phase,segments,lumpy)
  local first=#vertices;vertices[#vertices+1]=point(cx,cy,.06);normals[#normals+1]=p.normal;uv[#uv+1]={X=.5,Y=.5}
  local lobes={};for i=1,8 do lobes[i]=rng()*math.pi*2 end
  for i=0,segments-1 do
   local a=i/segments*math.pi*2;local shape=1
   if lumpy then shape=1+.19*math.sin(a*3+lobes[1])+.12*math.sin(a*7+lobes[2])+.08*math.sin(a*13+lobes[3])+.05*math.sin(a*23+lobes[4])end
   local x,y=math.cos(a)*radius*shape,math.sin(a)*radius*shape*stretch
   vertices[#vertices+1]=point(cx+x*math.cos(phase)-y*math.sin(phase),cy+x*math.sin(phase)+y*math.cos(phase))
   normals[#normals+1]=p.normal;uv[#uv+1]={X=.5+math.cos(a)*.5,Y=.5+math.sin(a)*.5}
  end
  for i=0,segments-1 do triangles[#triangles+1]=first;triangles[#triangles+1]=first+1+i;triangles[#triangles+1]=first+1+(i+1)%segments end
 end
 local radius=math.max(p.radius,p.pool or 0);local phase=rng()*math.pi*2
 fan(0,0,radius,p.stretch,phase,64,true)
 -- Each impact has its own lobes, filaments, satellite drops and rotation.
 for i=1,12+math.floor(rng()*14)do
  local angle=rng()*math.pi*2;local dist=radius*(.85+rng()*1.5)
  fan(math.cos(angle)*dist,math.sin(angle)*dist,(.07+rng()*.17)*radius,1+rng()*1.6,angle,9,false)
 end
 if(p.drip or 0)>0 then
  local g=P.unit(P.add(p.gravity,p.normal,-P.dot(p.gravity,p.normal)))
  local gx,gy=P.dot(g,u),P.dot(g,v);local length=p.drip*(1-math.exp(-math.max(0,age or p.wet or 0)/4))
  for j=1,3 do
   local shift=(j-2)*radius*.42;local len=length*(.55+rng()*.45)
   local width=.12+math.min(.5,p.volume*.018);local count=math.max(2,math.ceil(len/1.2))
   for k=1,count do local d=len*k/count;fan(-gy*shift+gx*d,gx*shift+gy*d,width,1.5,math.atan(gy,gx),8,false)end
   fan(-gy*shift+gx*len,gx*shift+gy*len,width*1.8,1.25,0,12,false)
  end
 end
 return {vertices=vertices,triangles=triangles,normals=normals,uv=uv}
end
return P
