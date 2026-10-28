-- zz-realpaints.loader.lua : TEMPLATE. deploy.ps1 appends this to data/realpaints-data.lua and installs the result
-- as jg-mechanic/config/zz-realpaints.lua (one file, so FiveM glob order does not matter).
-- It adds real-world paint colours to the jg-mechanic respray menu using the global RealPaintsData defined just above it.
-- Add new colours only at the END of a brand's list or as new brands at the END, so IDs of existing colours stay stable.
--
-- TabMode "region" = one tab per region (German, Italian, ...). "brand" = one tab per manufacturer.

if not (Config and Config.Mods and Config.Mods.GtaColours) then
  print("[realpaints] WARNING: Config.Mods.GtaColours not found, real paints not loaded")
  return
end

if type(RealPaintsData) ~= "table" then
  print("[realpaints] WARNING: RealPaintsData not found, real paints not loaded")
  return
end

RealPaints = { TabMode = "region", ById = {} }
RealPaints.Data = RealPaintsData

local FIN = { solid = 0, metallic = 1, pearl = 2, matte = 3, satin = 4, chrome = 5 }

local function hexToRgb(hex)
  if type(hex) ~= "string" then return nil end
  hex = (hex:gsub("^#", ""))
  if not hex:match("^%x%x%x%x%x%x$") then return nil end
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), hex:lower()
end

-- Snapshot of the stock GTA palette (taken BEFORE new tabs are added).
local palette = {}
for cat, list in pairs(Config.Mods.GtaColours) do
  if cat ~= "Chameleon" and type(list) == "table" then
    for _, e in ipairs(list) do
      if type(e) == "table" and type(e.modIndex) == "number" and e.modIndex >= 0 and e.modIndex <= 160 then
        local r, g, b = hexToRgb(e.hex)
        if r then palette[#palette + 1] = { id = e.modIndex, r = r, g = g, b = b } end
      end
    end
  end
end

local function nearestPalette(r, g, b)
  local best, bestD = 0, math.huge
  for _, p in ipairs(palette) do
    local d = (p.r - r) ^ 2 + (p.g - g) ^ 2 + (p.b - b) ^ 2
    if d < bestD or (d == bestD and p.id < best) then
      best, bestD = p.id, d
    end
  end
  return best
end

local nextId = 1000
local total, tabs, tabSeen = 0, 0, {}

for _, brand in ipairs(RealPaints.Data) do
  local tabName = brand.brand
  if RealPaints.TabMode == "region" then tabName = brand.region or "Other" end
  for _, c in ipairs(brand.colours or {}) do
    local r, g, b, hex = hexToRgb(c.hex)
    if not r then
      print(("[realpaints] WARNING: invalid hex for %s %s, skipped"):format(tostring(brand.brand), tostring(c.name)))
    else
      local fin = FIN[c.finish]
      if fin == nil then
        print(("[realpaints] WARNING: unknown finish '%s' for %s %s, using metallic"):format(tostring(c.finish), tostring(brand.brand), tostring(c.name)))
        fin = 1
      end
      if not tabSeen[tabName] then
        tabSeen[tabName] = true
        tabs = tabs + 1
        if not Config.Mods.GtaColours[tabName] then Config.Mods.GtaColours[tabName] = {} end
      end
      local id = nextId
      nextId = nextId + 1
      local entry = {
        modIndex = id,
        name = brand.brand .. " " .. c.name .. (c.code and (" (" .. c.code .. ")") or ""),
        hex = hex,
        rgb = { r, g, b },
        finish = fin,
        fallback = nearestPalette(r, g, b),
      }
      table.insert(Config.Mods.GtaColours[tabName], entry)
      RealPaints.ById[id] = entry
      total = total + 1
    end
  end
end

function RealPaints.Get(id)
  if type(id) == "number" and id >= 1000 then return RealPaints.ById[id] end
  return nil
end

print(("[realpaints] loaded %d colours in %d tabs"):format(total, tabs))
