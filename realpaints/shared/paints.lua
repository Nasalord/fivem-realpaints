-- Builds the paint list from RealPaintsData. IDs match jg-mechanic's zz-realpaints.lua exactly:
-- ids start at 1000, follow data order, and colours with an invalid hex are skipped (no id used).

local FIN = { solid = 0, metallic = 1, pearl = 2, matte = 3, satin = 4, chrome = 5 }
local FIN_NAMES = { [0] = 'solid', 'metallic', 'pearl', 'matte', 'satin', 'chrome' }

RealPaintsList = {}      -- array of entries, in id order
RealPaintsById = {}      -- [id] = entry
RealPaintsRegions = {}   -- { { region = 'German', brands = { { brand = 'BMW', colours = { entry, ... } } } } }

local function hexToRgb(hex)
  if type(hex) ~= 'string' then return nil end
  hex = (hex:gsub('^#', ''))
  if not hex:match('^%x%x%x%x%x%x$') then return nil end
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), hex:lower()
end

function RPFinishName(finish)
  return FIN_NAMES[finish] or 'metallic'
end

function RPGetPaint(id)
  if type(id) == 'number' and id >= 1000 then return RealPaintsById[id] end
  return nil
end

local regionIndex = {}
local nextId = 1000

if type(RealPaintsData) == 'table' then
  for _, brand in ipairs(RealPaintsData) do
    local region = brand.region or 'Other'
    local brandGroup = nil
    for _, c in ipairs(brand.colours or {}) do
      local r, g, b, hex = hexToRgb(c.hex)
      if r then
        local fin = FIN[c.finish]
        if fin == nil then fin = 1 end
        local id = nextId
        nextId = nextId + 1
        local entry = {
          id = id,
          brand = brand.brand,
          region = region,
          name = c.name,
          code = c.code,
          hex = hex,
          rgb = { r, g, b },
          finish = fin,
        }
        RealPaintsList[#RealPaintsList + 1] = entry
        RealPaintsById[id] = entry

        if not regionIndex[region] then
          RealPaintsRegions[#RealPaintsRegions + 1] = { region = region, brands = {} }
          regionIndex[region] = RealPaintsRegions[#RealPaintsRegions]
        end
        if not brandGroup then
          brandGroup = { brand = brand.brand, colours = {} }
          local brands = regionIndex[region].brands
          brands[#brands + 1] = brandGroup
        end
        brandGroup.colours[#brandGroup.colours + 1] = entry
      end
    end
  end
end
