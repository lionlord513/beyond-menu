-- Use the replicated native material parameters, including attached body panels.
return function(actor,rgb,metallic)
 local valid=function(o)return o and o:IsValid()end
 local all={actor};local children={};actor:GetAttachedActors(children,true,true)
 for _,v in ipairs(children)do all[#all+1]=v:get()end
 local kind=StaticFindObject('/Game/BP/Components/MaterialDynComponent.MaterialDynComponent_C')
 for _,a in ipairs(all)do if valid(a)then
  local c=a:GetComponentByClass(kind)
  if valid(c)then
   for name,value in pairs({Color={R=rgb[1],G=rgb[2],B=rgb[3],A=1},Metallic=metallic and 1 or 0,Polish=1,['Rust and wear']=0})do
    c:UpdateDynParam({Key_2_9A8C438B4224A6B1657E3997CF43EB5B=FName(name),VectorParameter_12_33A11DA14457E338EF9919B9B47CA282=type(value)=='table'and value or{R=0,G=0,B=0,A=1},ScalarParameter_8_52C9880A475C4002B11BC8A2E153EE81=type(value)=='number'and value or 0,IsScalarParameter_11_EA81612E4CFE7ABB1E2351A611997EA1=type(value)=='number'},false)
   end
   c:ProcessDynParam();a:ForceNetUpdate()
  end
 end end
end
