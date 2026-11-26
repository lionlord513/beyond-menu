return function(B)
 local U={opened=false,tab='Player',page=1,hits={},fields={},mode=nil,query='',category='All',tuned=false,paint={.32,.72,.66},metallic=false,carPaint={.24,.35,.45},carMetallic=false}
 local valid=B.valid;local S=B.settings;local lib,layout,slate
 local colors={text={R=.91,G=.94,B=.96,A=1},muted={R=.49,G=.57,B=.65,A=1},line={R=.14,G=.19,B=.24,A=.8},panel={R=.035,G=.047,B=.065,A=.86},white={R=1,G=1,B=1,A=1}}
 local function contrast(c)return(c[1]*.2126+c[2]*.7152+c[3]*.0722)>.38 and{R=.025,G=.035,B=.045,A=1}or{R=.94,G=.96,B=.98,A=1}end
 local function new(k)return StaticConstructObject(StaticFindObject('/Script/UMG.'..k),U.tree)end
 local function color(c)if type(c)=='table'then return c end;return colors[c]or S.color(c)end
 local function place(o,x,y,w,h)
  local slot=U.canvas:AddChildToCanvas(o);slot:SetPosition({X=U.x+x*U.scale,Y=U.y+y*U.scale});slot:SetSize({X=w*U.scale,Y=h*U.scale});o:SetVisibility(3);return o
 end
 local function brush(c,r,border,width)
  return{DrawAs=4,TintColor={SpecifiedColor=color(c),ColorUseRule=0},OutlineSettings={Color={SpecifiedColor=color(border or c),ColorUseRule=0},Width=(width or 0)*U.scale,CornerRadii={X=r*U.scale,Y=r*U.scale,Z=r*U.scale,W=r*U.scale},RoundingType=0}}
 end
 local function box(x,y,w,h,c,r,border,width)
  local o=new('Image');o:SetBrush(brush(c,r or 12,border,width));place(o,x,y,w,h);return o
 end
 local function text(t,x,y,w,h,size,c,bold,control)
  local o=new('TextBlock');o:SetText(FText(t));local f=o.Font;f.Size=math.max(9,math.floor(size*U.scale+.5));f.TypefaceFontName=FName(bold and'Bold'or'Regular');o:SetFont(f)
  local ink=color(c or'text');if c=='border'and math.abs((S.border[1]+S.border[2]+S.border[3])-(S.background[1]+S.background[2]+S.background[3]))<.55 then ink=colors.text end
  o:SetColorAndOpacity({SpecifiedColor=ink,ColorUseRule=0});o:SetClipping(1);place(o,x,y,w,h);if not control then o:SetVisibility(1)end;return o
 end
 local function image(tex,x,y,w,h)
  if not valid(tex)then return end
  local frame=new('ScaleBox');frame:SetStretch(2);local o=new('Image');o:SetBrushFromTexture(tex,true);o:SetVisibility(3);frame:AddChild(o);place(frame,x,y,w,h);return o
 end
 local function hit(x,y,w,h,fn,hover,visual)
  local h={x=x,y=y,w=w,h=h,fn=fn,onHover=hover,visual=visual};U.hits[#U.hits+1]=h;return h
 end
 local function button(label,x,y,w,h,fn,active,small)
  local bg=box(x,y,w,h,active and S.color('border',.22)or'button',h/2,active and'border'or'line',1)
  local compact=w<70;local o=text(label,x+(compact and 0 or 18),y+(h-(small and 18 or 22))/2-2,w-(compact and 0 or 36),28,small and 12 or 15,active and'border'or contrast(S.button),active,true)
  if compact then o:SetJustification(1)end
  return hit(x,y,w,h,fn,nil,{bg=bg,active=active,r=h/2})
 end
 local function field(key,value,x,y,w,h)
  box(x,y,w,h,'panel',12,'line',1)
  local o=new('EditableTextBox');o:SetText(FText(value or''));o:SetForegroundColor(colors.text)
  local style=o.WidgetStyle;local transparent={DrawAs=0};style.BackgroundImageNormal=transparent;style.BackgroundImageHovered=transparent;style.BackgroundImageFocused=transparent;style.BackgroundImageReadOnly=transparent
  style.ForegroundColor={SpecifiedColor=colors.text,ColorUseRule=0}
  local f=style.TextStyle.Font;f.Size=math.max(11,math.floor(15*U.scale));style.TextStyle.Font=f;o.WidgetStyle=style
  place(o,x+10,y+4,w-20,h-8);o:SetVisibility(0);U.fields[key]=o;return o
 end
 local function value(k,fallback)local o=U.fields[k];return valid(o)and o:GetText():ToString()or fallback end
 local function check(label,on,x,y,w,fn)
  box(x,y,22,22,on and'border'or'button',7,on and'border'or'line',1)
  if on then text('✓',x+4,y-2,20,24,16,contrast(S.border),true,true)end
  text(label,x+34,y-1,w-34,26,14,nil,nil,true);hit(x,y,w,28,fn)
 end
 local function section(title,x,y,sub)
  text(title,x,y,720,34,26,'text',true);if sub then text(sub,x,y+41,760,26,13,'muted')end
 end
 function U.status()if valid(U.statusText)then U.statusText:SetText(FText(B.message))end end
 local function execute(fn,redraw)
  B.run(fn);if U.opened and not U.child and redraw~=false then U.render()end
 end
 function U.navigate(mode)
  U.mode=mode;U.page=1;U.query='';U.category='All';U.selected=nil;U.hover=nil
  if mode=='paint'or mode=='color'or mode=='carcolor'then local c=mode=='paint'and U.paint or U.colorDraft;U.brightness=math.max(c[1],c[2],c[3])end
  if mode=='items'or mode=='cars'then B.catalog.ensure();B.optional.refresh()end
  U.render()
 end
 local function toggle(label,id,x,y,w)
  button(label,x,y,w,48,function()execute(function()return B.actions.toggle(id)end)end,B.toggles[id]);text(B.toggles[id]and'On'or'Off',x+w-54,y+16,40,22,11,B.toggles[id]and'border'or'muted')
 end
 local function player()
  section('Player',218,104,'Health, abilities and money.')
  button('Scoreboard',874,108,166,38,function()U.navigate('scoreboard')end,false,true)
  text('HEALTH & NEEDS',218,197,500,22,11,'muted',true)
  local rows={{'Full heal',function()return B.actions.refill()end},{'Refill health',function()return B.actions.refill(1)end},{'Refill hunger',function()return B.actions.refill(2)end},{'Refill thirst',function()return B.actions.refill(3)end},{'Empty bladder',B.actions.empty}}
  for i,r in ipairs(rows)do button(r[1],218+((i-1)%3)*279,234+math.floor((i-1)/3)*60,261,48,function()execute(r[2])end)end
  text('ABILITIES',218,371,500,22,11,'muted',true)
  toggle('Super speed','speed',218,408,261);toggle('Super jump','jump',497,408,261);toggle('No hunger or thirst','needs',776,408,261)
  button(B.toggles.flight and'Flight / noclip: On'or'Flight / noclip: Off',218,472,261,46,function()execute(B.flight.toggle)end,B.toggles.flight)
  button('Open Computer',497,472,261,46,function()execute(B.actions.computer,false)end)
  text('Hold Shift to fly faster',776,488,261,24,12,'muted')
  text('MONEY',218,540,500,22,11,'muted',true)
  field('money',U.money or'5000',218,574,240,46)
  for i,r in ipairs({{'Add','add'},{'Remove','remove'},{'Set balance','set'}})do button(r[1],480+(i-1)*188,574,172,46,function()U.money=value('money','5000');execute(function()return B.actions.money(r[2],U.money)end)end)end
  if not B.host()then text('Player stats and world changes are controlled by the host.',218,637,800,24,12,'muted')end
 end
 local function items()
  section('Items',218,104,'Spawn items and refill supplies.')
  box(218,198,820,134,'panel',22,'line',1)
  text('Native item catalog',244,220,650,32,22,'text',true);text('Every available item, with search and native icons.',244,263,610,25,13,'muted')
  button('Open catalog',820,242,190,48,function()U.navigate('items')end,true)
  text('UNLIMITED SUPPLIES',218,370,550,22,11,'muted',true)
  toggle('Brush & sponge','brush',218,407,261);toggle('Spraypaint','paint',497,407,261);toggle('Ammo','ammo',776,407,261)
  text('CUSTOM PAINT',218,506,550,22,11,'muted',true)
  button('Spraypaint maker',218,544,290,50,function()U.navigate('paint')end)
  text('Pick a color. Choose metallic or matte.',533,559,500,26,13,'muted')
 end
 local function fun()
  U.paintballColor=U.paintballColor or{1,.12,.025}
  button('Spawn paintball gun',218,112,190,36,function()execute(function()return B.paintball.spawn('gun',U.paintballColor)end)end,false,true)
  button('Spawn 50 paintballs',462,112,190,36,function()execute(function()return B.paintball.spawn('pod',U.paintballColor)end)end,false,true)
  if not valid(U.wheel)then U.wheel=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(U.pc,B.root..'/assets/color-wheel.png')end
  local icon=image(U.wheel,419,117,26,26);if valid(icon)then icon:SetToolTipText(FText('Choose paintball color'))end
  hit(413,112,38,36,function()U.colorDraft={table.unpack(U.paintballColor)};U.brightness=math.max(table.unpack(U.colorDraft));U.mode='paintballcolor';U.render()end)
  local c=U.paintballColor;box(423,149,18,3,{R=c[1],G=c[2],B=c[3],A=1},2)
 end
 local function world()
  section('World',218,104,'Set the time and weather for this session.')
  text('TIME OF DAY',218,199,550,22,11,'muted',true)
  for i,r in ipairs({{'Dawn',600},{'Noon',1200},{'Dusk',1800},{'Midnight',0}})do button(r[1],218+(i-1)*210,236,192,48,function()execute(function()return B.actions.time(r[2])end)end)end
  text('WEATHER',218,336,550,22,11,'muted',true)
  local weather={{'Clear',0},{'Cloudy',1},{'Fog',2},{'Overcast',3},{'Partly cloudy',4},{'Dust',5},{'Rain',6},{'Light rain',7},{'Storm',8},{'Calm dust',9},{'Sandstorm',10},{'Snow',11},{'Blizzard',12},{'Light snow',13}}
  for i,r in ipairs(weather)do button(r[1],218+((i-1)%4)*210,374+math.floor((i-1)/4)*58,192,46,function()execute(function()return B.actions.weather(r[2])end)end,false,true)end
 end
 local function settings()
  section('Settings',218,104,'Menu colors and transparency.')
  text('BACKGROUND',218,201,500,22,11,'muted',true)
  button('Transparent',218,238,220,48,function()S.transparent=true;S.save();U.render()end,S.transparent)
  button('Solid color',454,238,220,48,function()S.transparent=false;S.save();U.render()end,not S.transparent)
  text('Opacity',218,319,160,25,14,'muted');text(math.floor(S.opacity*100)..'%',846,319,85,25,14)
  button('−',938,307,46,42,function()S.opacity=math.max(.25,S.opacity-.05);S.save();U.render()end)
  button('+',994,307,46,42,function()S.opacity=math.min(.98,S.opacity+.05);S.save();U.render()end)
  for i,r in ipairs({{'Border color','border'},{'Background color','background'},{'Button color','button'}})do
   local y=387+(i-1)*64;box(218,y,38,38,S.color(r[2]),13,'line',1);button(r[1],276,y-4,310,46,function()U.colorTarget=r[2];U.colorDraft={table.unpack(S[r[2]])};U.navigate('color')end)
  end
  text('BeyondMenu '..B.version..'  ·  Open with F8',218,618,620,26,12,'muted')
  -- Small toolbox icon. The tooltip supplies its accessible description.
  local x,y=988,602;local b=box(x,y,50,44,'button',14,'line',1);b:SetToolTipText(FText('Open native debug menu'))
  box(x+15,y+10,20,8,'muted',3);box(x+10,y+17,30,19,'text',4);box(x+10,y+23,30,2,'background',1);box(x+23,y+21,5,8,'background',1)
  hit(x,y,50,44,function()execute(U.debug,false)end)
 end
 local function rosterKey(rows)local t={tostring(B.host())};for _,r in ipairs(rows)do t[#t+1]=r.key..r.name..r.ping end;return table.concat(t,'|')end
 local function scoreboard()
  section('Scoreboard',218,104,'Players connected to this session.')
  local rows=B.players.list();U.scoreRows=rows;U.roster=rosterKey(rows)
  text('PLAYER',240,198,600,22,11,'muted',true);text('PING',867,198,100,22,11,'muted',true)
  local per=6;U.pages=math.max(1,math.ceil(#rows/per));U.page=math.min(U.page,U.pages)
  for i=(U.page-1)*per+1,math.min(U.page*per,#rows)do local row=rows[i];local y=236+(i-(U.page-1)*per-1)*59
   box(218,y,820,49,'panel',15,'line',1);text(('%02d'):format(i),236,y+14,38,23,12,'muted');text(row.name..(row.self and'  (you)'or''),287,y+11,540,30,15)
   local ping=row.ping;local c=ping<90 and{R=.35,G=.75,B=.55,A=1}or ping<180 and{R=.95,G=.67,B=.28,A=1}or{R=.91,G=.37,B=.35,A=1}
   for n=1,3 do box(849+n*7,y+30-n*5,4,n*5,c,2)end;text(tostring(ping)..' ms',884,y+15,92,24,12,'muted')
   if B.host()then button('•••',980,y+7,46,34,function()U.selected=U.selected==row.key and nil or row.key;U.render()end,U.selected==row.key,true)end
  end
  if U.selected and B.host()then
   box(635,294,388,208,'background',20,'border',1)
   local row;for _,r in ipairs(rows)do if r.key==U.selected then row=r end end
   if row then text(row.name,657,312,340,28,15,'text',true)
    for i,r in ipairs({{'Teleport to player',function()return B.players.teleport(row.key,false)end},{'Bring player to me',function()return B.players.teleport(row.key,true)end},{'Full heal',function()return B.players.heal(row.key)end}})do button(r[1],655,350+(i-1)*45,346,36,function()U.selected=nil;execute(r[2])end,false,true)end
   else U.selected=nil end
  end
 end
 local function colorWheel()
  local paint=U.mode=='paint';local car=U.mode=='carcolor';local paintball=U.mode=='paintballcolor';local rgb=paint and U.paint or U.colorDraft
  box(186,80,875,570,{R=0,G=0,B=0,A=.38},20);hit(186,80,875,570,function()end)
  box(266,142,730,456,'background',24,'border',1.2)
  text(paint and'Spraypaint maker'or car and'Car color'or paintball and'Paintball color'or'Choose a color',292,164,610,34,23,'text',true)
  button('×',928,158,44,38,U.back,false,true)
  text(paint and'Choose a color and finish.'or'Press Apply to save this color.',292,208,660,24,12,'muted')
  if not valid(U.wheel)then U.wheel=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(U.pc,B.root..'/assets/color-wheel.png')end
  image(U.wheel,295,264,250,250)
  hit(295,264,250,250,function(x,y)
   local dx,dy=(x-420)/125,(y-389)/125;local radius=math.sqrt(dx*dx+dy*dy)
   if radius>1 then return end
   local h=(math.atan(dy,dx)/(2*math.pi)+1)%1;local c=S.hsv(h,radius,U.brightness or 1)
   if paint then U.paint=c else U.colorDraft=c end;U.render()
  end)
  box(590,260,376,96,{R=rgb[1],G=rgb[2],B=rgb[3],A=1},18,'line',1)
  text(('RGB  %d · %d · %d'):format(math.floor(rgb[1]*255+.5),math.floor(rgb[2]*255+.5),math.floor(rgb[3]*255+.5)),590,374,376,28,13,'muted')
  text('Brightness',590,425,240,25,14);button('−',846,410,52,42,function()
   local mx=math.max(rgb[1],rgb[2],rgb[3],.001);local n=math.max(.05,mx-.1);for i=1,3 do rgb[i]=rgb[i]/mx*n end;U.brightness=n;U.render()
  end);button('+',914,410,52,42,function()
   local mx=math.max(rgb[1],rgb[2],rgb[3],.001);local n=math.min(1,mx+.1);for i=1,3 do rgb[i]=rgb[i]/mx*n end;U.brightness=n;U.render()
  end)
  if paintball then
   text('Used for newly spawned paintball canisters.',590,476,376,28,12,'muted')
   button('Apply',590,530,376,44,function()U.paintballColor={table.unpack(U.colorDraft)};U.mode=nil;U.render()end,true)
  elseif car then
   check('Metallic',U.carMetalDraft,590,476,158,function()U.carMetalDraft=true;U.render()end);check('Matte',not U.carMetalDraft,788,476,158,function()U.carMetalDraft=false;U.render()end)
   button('Apply',590,530,376,44,function()U.carPaint={table.unpack(U.colorDraft)};U.carMetallic=U.carMetalDraft;B.catalog.preparePaint();U.mode='cars';U.render()end,true)
  elseif paint then
   check('Metallic',U.metallic,590,476,158,function()U.metallic=true;U.render()end);check('Matte',not U.metallic,788,476,158,function()U.metallic=false;U.render()end)
   button('Spawn spraypaint',590,530,376,44,function()execute(function()return B.actions.paint(U.paint,U.metallic)end)end,true)
  else button('Apply',590,530,376,44,function()S[U.colorTarget]={table.unpack(U.colorDraft)};S.save();U.mode=nil;U.tab='Settings';U.render()end,true)end
 end
 local function catalog()
  local cars=U.mode=='cars'or U.mode=='carcolor';section(cars and'Car spawner'or'Native item catalog',218,104,cars and'Choose a vehicle. Leave clear space nearby.'or'Spawn an item with one click.')
  field('search',U.query,218,187,cars and 515 or 640,43);button('Search',cars and 750 or 875,187,cars and 108 or 162,43,function()U.query=value('search','');U.page=1;U.render()end,false,true)
  local list=B.catalog.filtered(cars,U.query,U.category);local cols=cars and 3 or 5;local per=cols*3;U.pages=math.max(1,math.ceil(#list/per));U.page=math.min(U.page,U.pages)
  text(#list..(cars and' vehicles'or' items'),218,244,230,23,11,'muted');U.catalogHover=text('',440,244,597,23,12,'muted')
  for i=(U.page-1)*per+1,math.min(U.page*per,#list)do
   local row=list[i];local n=i-(U.page-1)*per-1;local w=cars and 172 or 151;local x=218+(n%cols)*(w+16);local y=278+math.floor(n/cols)*108
   local bg=box(x,y,w,94,'button',16,'line',1)
   local tex=B.catalog.icon(row,cars,U.tuned);local picture=image(tex,x+16,y+5,w-32,56)
   if cars then U.iconSlots[#U.iconSlots+1]={row=row,widget=picture,texture=tex}end
   local label=text(row.name,x+10,y+65,w-20,24,11,contrast(S.button),true,true)
   hit(x,y,w,94,function()execute(function()return B.catalog.spawn(row,cars,U.tuned)end,false)end,function()
    if valid(U.catalogHover)then U.catalogHover:SetText(FText(row.name))end
    if cars then U.pendingPreview=row;U.previewAt=os.clock()+1 end
   end,{bg=bg,r=16})
  end
  if cars then
   B.native.prioritize(U.iconSlots,U.tuned)
   box(804,278,233,310,'panel',20,'line',1)
   text('PREVIEW',824,298,195,22,10,'muted',true)
   U.previewImage=new('Image');place(U.previewImage,817,337,207,138);U.previewImage:SetVisibility(1)
   U.previewName=text('Hover over a car',824,491,193,52,15,'muted',true)
   U.previewNote=text(U.tuned and'Tuned parts'or'Standard parts',824,554,195,23,11,'muted')
   check('Tuned parts',U.tuned,218,619,250,function()U.tuned=not U.tuned;U.previewShown=false;U.render()end)
   button('Car color',463,611,176,38,function()U.colorDraft={table.unpack(U.carPaint)};U.carMetalDraft=U.carMetallic;U.mode='carcolor';U.brightness=math.max(table.unpack(U.colorDraft));U.render()end,false,true)
   box(652,619,22,22,{R=U.carPaint[1],G=U.carPaint[2],B=U.carPaint[3],A=1},8,'line',1)
  end
 end
 function U.render()
  if not valid(U.canvas)then return end
  U.canvas:ClearChildren();U.hits={};U.fields={};U.iconSlots={};U.previewImage=nil;U.previewName=nil;U.hover=nil;U.pendingPreview=nil;U.previewShown=false
  local vp=layout:GetViewportSize(U.pc);local dpi=layout:GetViewportScale(U.pc)
  U.scale=math.max(.2,math.min(vp.X/1160,vp.Y/760))/dpi;U.x=(vp.X/dpi-1080*U.scale)/2;U.y=(vp.Y/dpi-690*U.scale)/2
  colors.text=contrast(S.background);local light=S.background[1]*.2126+S.background[2]*.7152+S.background[3]*.0722>.38
  colors.muted=light and{R=.18,G=.23,B=.29,A=1}or{R=.49,G=.57,B=.65,A=1}
  colors.panel=light and{R=.80,G=.84,B=.87,A=.86}or{R=.035,G=.047,B=.065,A=.86}
  colors.line=light and{R=.45,G=.52,B=.58,A=.8}or{R=.14,G=.19,B=.24,A=.8}
  box(-5,-3,1090,700,{R=0,G=0,B=0,A=.24},30)
  box(0,0,1080,690,S.color('background',S.transparent and S.opacity or 1),28,'border',1.5)
  box(12,12,174,666,{R=.018,G=.026,B=.039,A=.62},21)
  text('Beyond',30,32,140,37,27,'white',true);text('MENU',33,76,140,24,11,S.color('border'),true)
  local tabs={'Player','Items','Car spawner','Fun','World','Settings'}
  for i,t in ipairs(tabs)do button(t,26,146+(i-1)*58,145,45,function()U.tab=t;U.mode=t=='Car spawner'and'cars'or nil;U.page=1;U.query='';if U.mode then B.catalog.ensure();B.optional.refresh()end;U.render()end,U.tab==t,true)end
  text('F8',35,610,60,27,14,'white',true);text('open / close',35,636,130,22,11,{R=.6,G=.67,B=.72,A=1})
  text(B.host()and'HOST SESSION'or'GUEST SESSION',218,36,550,24,10,'border',true)
  if U.mode and U.tab~='Car spawner'then button('Back',858,25,106,40,U.back,false,true)end
  button('×',989,23,48,42,U.close,false,false)
  if U.mode=='scoreboard'then scoreboard()elseif U.mode=='paint'or U.mode=='color'or U.mode=='carcolor'or U.mode=='paintballcolor'then if U.mode=='paint'then items()elseif U.mode=='carcolor'then catalog()elseif U.mode=='paintballcolor'then fun()else settings()end;colorWheel()elseif U.mode=='items'or U.mode=='cars'then catalog()
  elseif U.tab=='Player'then player()elseif U.tab=='Items'then items()elseif U.tab=='Fun'then fun()elseif U.tab=='World'then world()elseif U.tab=='Settings'then settings()end
  if U.pages and(U.mode=='items'or U.mode=='cars'or U.mode=='scoreboard')then
   button('‹',882,611,44,34,function()U.page=math.max(1,U.page-1);U.render()end,false,true)
   text(U.page..' / '..U.pages,935,620,62,22,11,'muted');button('›',997,611,40,34,function()U.page=math.min(U.pages,U.page+1);U.render()end,false,true)
  end
  U.statusText=text(B.message,218,662,818,20,10,'muted')
 end
 function U.open()
  B.context();U.pc=B.pc();U.pawn=B.player();U.world=U.pc:GetWorld():GetAddress()
  if U.pc.bShowMouseCursor then return'Close the other menu first'end
  lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary');layout=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary');slate=StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary')
  U.widget=lib:Create(U.pc,StaticFindObject('/Script/UMG.UserWidget'),U.pc)
  U.tree=U.widget.WidgetTree;if not valid(U.tree)then U.tree=StaticConstructObject(StaticFindObject('/Script/UMG.WidgetTree'),U.widget);U.widget.WidgetTree=U.tree end
  U.canvas=new('CanvasPanel');U.tree.RootWidget=U.canvas;U.widget:AddToViewport(10120);U.widget:SetClipping(1)
  U.cursorBefore=U.pc.bShowMouseCursor;U.pc:SetIgnoreLookInput(true);U.pc:SetIgnoreMoveInput(true);U.blocked=true
  U.pc.bShowMouseCursor=true;lib:SetInputMode_UIOnlyEx(U.pc,U.widget,0,true);U.opened=true;ModRef:SetSharedVariable('BM_UIOpen',true);U.render();return'BeyondMenu opened'
 end
 function U.close()
  U.opened=false;ModRef:SetSharedVariable('BM_UIOpen',false)
  if valid(U.child)then U.child:RemoveFromParent()end;U.child=nil
  if valid(U.widget)then U.widget:RemoveFromParent()end
  if U.blocked and valid(U.pc)then U.pc:SetIgnoreLookInput(false);U.pc:SetIgnoreMoveInput(false);U.pc.bShowMouseCursor=U.cursorBefore or false;lib:SetInputMode_GameOnly(U.pc,true)end
  U.blocked=false;U.widget=nil;U.canvas=nil;U.tree=nil;U.hits={};U.fields={};U.preview=nil;U.wheel=nil;U.statusText=nil;U.hover=nil
 end
 function U.back()if U.child then U.close()elseif U.mode=='carcolor'then U.mode='cars';U.render()elseif U.mode and U.tab~='Car spawner'then U.mode=nil;U.selected=nil;U.render()else U.close()end end
 function U.toggle()if U.opened then U.close()else local ok,e=pcall(U.open);if not ok then U.close();error(e)end end end
 function U.mouse()
  local focus,x,y=B.native.mouse();if not focus then return -10000,-10000 end
  local vp=layout:GetViewportSize(U.pc);local dpi=layout:GetViewportScale(U.pc)
  return(x*vp.X/dpi-U.x)/U.scale,(y*vp.Y/dpi-U.y)/U.scale
 end
 function U.click()
  if not U.opened or U.child then return end
  local x,y=U.mouse()
  for i=#U.hits,1,-1 do local h=U.hits[i];if x>=h.x and x<=h.x+h.w and y>=h.y and y<=h.y+h.h then h.fn(x,y);return end end
 end
 function U.debug()
  B.context(true);local cls=LoadAsset('/Game/UI/WBP_Debug.WBP_Debug_C');assert(valid(cls),'Native debug menu unavailable')
  U.child=lib:Create(U.pc,cls,U.pc);U.widget:SetVisibility(1);U.child:AddToViewport(10121);lib:SetInputMode_UIOnlyEx(U.pc,U.child,0,true)
  return'Native debug menu opened. F8 closes it.'
 end
 function U.refreshIcons()
  if not U.opened or(U.mode~='cars'and U.mode~='carcolor')then return end
  for _,slot in ipairs(U.iconSlots or{})do local tex=B.catalog.icon(slot.row,true,U.tuned);if valid(tex)and valid(slot.widget)and tex~=slot.texture then slot.widget:SetBrushFromTexture(tex,true);slot.texture=tex end end
  if U.preview and U.previewShown and valid(U.previewImage)then local tex=B.catalog.preview(U.preview,U.tuned);if valid(tex)then U.previewImage:SetBrushFromTexture(tex,false)end end
 end
 function U.tick()
  if not U.opened then return end
  if not B.ready()or not valid(U.pc)or U.pc:GetWorld():GetAddress()~=U.world then U.close();return end
  if U.child then if not valid(U.child)or not U.child:IsInViewport()then U.close()end;return end
  if U.mode=='scoreboard'and os.clock()>=(U.rosterAt or 0)then U.rosterAt=os.clock()+1;if rosterKey(B.players.list())~=U.roster then U.render()end end
  local x,y=U.mouse();local target
  for i=#U.hits,1,-1 do local h=U.hits[i];if x>=h.x and x<=h.x+h.w and y>=h.y and y<=h.y+h.h then target=h;break end end
  if target~=U.hover then
   U.pendingPreview=nil
   if U.hover and U.hover.visual then local v=U.hover.visual;v.bg:SetBrush(brush(v.active and S.color('border',.22)or'button',v.r,v.active and'border'or'line',1))end
   U.hover=target
   if target then if target.visual then local v=target.visual;v.bg:SetBrush(brush(S.color('border',.16),v.r,'border',1.2))end;if target.onHover then target.onHover()end end
  end
  if U.pendingPreview and os.clock()>=(U.previewAt or 0)then U.preview=U.pendingPreview;U.pendingPreview=nil;U.previewShown=false end
  if U.mode=='cars'and U.preview and not U.previewShown then
   U.previewShown=true;local tex=B.catalog.preview(U.preview,U.tuned)
   if valid(tex)and valid(U.previewImage)then U.previewImage:SetBrushFromTexture(tex,false);U.previewImage:SetVisibility(3)end
   if valid(U.previewName)then U.previewName:SetText(FText(U.preview.name))end
   if valid(U.previewNote)then U.previewNote:SetText(FText(U.preview.provider and'No tuned parts available'or U.tuned and'Tuned parts'or'Standard parts'))end
  end
 end
 return U
end
