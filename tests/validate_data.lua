-- T-03-1: catalogue fields, native loader parity and stable file-order IDs.
dofile('data/realpaints-data.lua')
dofile('realpaints/shared/apply.lua')
assert(type(RealPaintsData)=='table')
local total=0
for _,brand in ipairs(RealPaintsData) do
  for _,colour in ipairs(brand.colours or {}) do
    total=total+1
    assert(type(colour.hex)=='string' and colour.hex:match('^%x%x%x%x%x%x$'))
    assert(RealPaintsApply.colour(colour)~=nil)
    if colour.gta~=nil then
      assert(type(colour.gta)=='string' and colour.gta:match('^%x%x%x%x%x%x$'))
    end
    if colour.pearl~=nil then
      assert(type(colour.pearl)=='number' and colour.pearl%1==0
        and colour.pearl>=0 and colour.pearl<=160)
    end
    if colour.source~=nil then
      assert(type(colour.source)=='string' and #colour.source<=120)
    end
    if colour.status~=nil then
      assert(colour.status=='unset' or colour.status=='measured' or colour.status=='reviewed')
    end
  end
end
assert(total==782,'do not insert, remove or reorder existing colours in T-03-1')
assert(RealPaintsData[1].colours[1].name=='Isle of Man Green')
dofile('realpaints/shared/paints.lua')
assert(#RealPaintsList==782 and #RealPaintsById==0) -- ById is keyed from 1000, not an array
for i,paint in ipairs(RealPaintsList) do
  assert(paint.id==999+i and RealPaintsById[paint.id]==paint)
end
assert(RealPaintsById[1000].name=='Isle of Man Green')
assert(RealPaintsById[1781].name=='Purple Haze')
assert(RealPaintsById[1782]==nil)
local resource=RealPaintsList
-- Exercise the same catalogue construction in the JG loader, with stub GTA palette.
Config={Mods={GtaColours={Metallic={{modIndex=1,hex='ffffff'}}}}}
dofile('jg-mechanic/config/zz-realpaints.loader.lua')
for _,p in ipairs(resource) do
  local jg=assert(RealPaints.Get(p.id),'missing jg paint '..p.id)
  assert(jg.finish==p.finish and jg.hex==p.hex and jg.rgb[1]==p.rgb[1])
  assert(jg.pearl==p.pearl and jg.gta==p.gta and jg.status==p.status)
end
-- Fixture must exercise both loaders, not just the shared colour helper.
RealPaintsData = {
  { brand='Fixture', region='Other', colours={
    { name='Calibrated Pearl', hex='036358', gta='03502f',
      pearl=53, status='measured', finish='pearl' }
  }}
}
dofile('realpaints/shared/paints.lua')
local standalone=assert(RPGetPaint(1000))
assert(standalone.hex=='036358' and standalone.gta=='03502f')
assert(standalone.rgb[1]==3 and standalone.rgb[2]==80 and standalone.rgb[3]==47,
  'standalone RGB must use gta rather than reference hex')
assert(standalone.pearl==53 and standalone.status=='measured')
Config={Mods={GtaColours={Metallic={{modIndex=1,hex='ffffff'}}}}}
dofile('jg-mechanic/config/zz-realpaints.loader.lua')
local jg=assert(RealPaints.Get(1000))
assert(jg.hex==standalone.hex and jg.gta==standalone.gta)
assert(jg.rgb[1]==3 and jg.rgb[2]==80 and jg.rgb[3]==47,
  'JG RGB must use gta rather than reference hex')
assert(jg.pearl==53 and jg.status=='measured')
print('PASS T-03-1: 782 stable catalogue IDs and matching standalone/JG data')
