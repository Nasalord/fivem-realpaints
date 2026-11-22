-- T-03-1: offline native stubs, no FiveM or MariaDB.
local root='realpaints/'
dofile(root..'shared/apply.lua')
local A=RealPaintsApply
local warnings={}
local oldPrint=print
print=function(msg) warnings[#warnings+1]=tostring(msg) end
local invalid=A.optional({gta='abc',pearl=161,status='bad'},'fixture')
assert(next(invalid)==nil and #warnings==3)
local opt=A.optional({gta='03502f',pearl=0,status='reviewed'},'good')
assert(opt.gta=='03502f' and opt.pearl==0 and opt.status=='reviewed')
assert(A.optional({gta='AABBCC'},'upper').gta=='aabbcc')
local rgb=A.colour({gta=opt.gta,hex='036358'})
assert(rgb[1]==3 and rgb[2]==80 and rgb[3]==47,'calibrated gta preferred')
local original=A.colour({hex='036358'})
assert(original[1]==3 and original[2]==99 and original[3]==88)
local calls={}
local function record(name,...)
  calls[#calls+1]={name=name,args={...}}
end
GetVehicleExtraColours=function(v) assert(v==9);return 47,121 end
SetVehicleModKit=function(...) record('kit',...) end
SetVehicleModColor_1=function(...) record('primary',...) end
SetVehicleModColor_2=function(...) record('secondary',...) end
SetVehicleCustomPrimaryColour=function(...) record('custom1',...) end
SetVehicleCustomSecondaryColour=function(...) record('custom2',...) end
SetVehicleExtraColours=function(...) record('extra',...) end
local paint={rgb=rgb,finish=2}
assert(A.applyVehicle(9,paint,'primary'))
assert(calls[2].name=='primary' and calls[2].args[4]==47)
assert(calls[#calls].name=='extra' and calls[#calls].args[2]==47 and calls[#calls].args[3]==121)
calls={}
assert(A.applyVehicle(9,paint,'secondary'))
assert(calls[2].name=='secondary' and calls[2].args[3]==0)
assert(calls[#calls].name=='extra' and calls[#calls].args[2]==47 and calls[#calls].args[3]==121)
calls={}
paint.pearl=53
assert(A.applyVehicle(9,paint,'both'))
assert(calls[2].name=='primary' and calls[2].args[4]==53)
assert(calls[4].name=='secondary' and calls[#calls].args[2]==53 and calls[#calls].args[3]==121)
calls={}
paint.pearl=0
assert(A.applyVehicle(9,paint,'primary'))
assert(calls[2].args[4]==0 and calls[#calls].args[2]==0,'explicit zero permitted')
assert(not A.applyVehicle(9,paint,'unknown'))
local mods={pearlescentColor=75,paintType2=1,color2={7,8,9}}
paint.pearl=nil
A.saveMods(mods,paint,'primary')
assert(mods.pearlescentColor==75 and mods.paintType1==2 and mods.paintType2==1)
paint.pearl=53
A.saveMods(mods,paint,'secondary')
assert(mods.pearlescentColor==53 and mods.paintType2==2 and mods.color2[2]==80)
assert(A.saveMods({}, {rgb=rgb,finish=2},'primary').pearlescentColor==nil)
-- The live server builds paint by id and persists via the shared pure helper.
local server=assert(io.open(root..'server.lua')):read('*a')
assert(server:find('RPGetPaint(req.paintId)',1,true))
assert(server:find('RealPaintsApply.saveMods(mods, paint, req.part)',1,true))
assert(server:find('pearl = paint.pearl',1,true))
local client=assert(io.open(root..'client.lua')):read('*a')
assert(client:find('RealPaintsApply.applyVehicle(veh, res, part)',1,true))
assert(not client:find('SetVehicleModColor_1(veh, res.finish, 0, 0)',1,true))
print=oldPrint
print('PASS T-03-1: optional fields, gta priority, no implicit pearl zero, primary/secondary/both, persistence')
