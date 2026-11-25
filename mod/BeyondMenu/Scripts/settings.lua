return function(B)
 local S={background={.027,.036,.052},border={.28,.69,.66},button={.075,.105,.14},opacity=.91,transparent=true}
 local path=B.root..'/settings.ini'
 local f=io.open(path,'r')
 if f then for line in f:lines()do
  local k,a,b,c=line:match('^(%w+)=([%d.]+),([%d.]+),([%d.]+)$')
  if k and(S[k]and type(S[k])=='table')and tonumber(a)and tonumber(b)and tonumber(c)then S[k]={math.min(1,tonumber(a)),math.min(1,tonumber(b)),math.min(1,tonumber(c))}end
  if line=='transparent=false'then S.transparent=false end
  local o=tonumber(line:match('^opacity=([%d.]+)$'));if o then S.opacity=math.max(.25,math.min(.98,o))end
 end;f:close()end
 function S.save()
  local out=assert(io.open(path..'.tmp','w'),'Could not save settings')
  for _,k in ipairs({'background','border','button'})do out:write(k..'='..table.concat(S[k],',')..'\n')end
  out:write('transparent='..tostring(S.transparent)..'\nopacity='..S.opacity..'\n');out:close()
  local original=io.open(path,'r');if original then original:close();os.remove(path)end
  assert(os.rename(path..'.tmp',path),'Could not finish saving settings')
 end
 function S.color(k,a)local c=S[k];return{R=c[1],G=c[2],B=c[3],A=a or 1}end
 function S.hsv(h,s,v)
  local i=math.floor(h*6);local f=h*6-i;local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
  local values={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
  return values[i%6+1]
 end
 return S
end
