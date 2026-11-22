-- T-03-1: identical source in realpaints and jg-mechanic's merged config.
-- No natives are called until applyVehicle is invoked on a client.
RealPaintsApply = RealPaintsApply or {}
local A = RealPaintsApply

local function rgb(hex)
  if type(hex) ~= 'string' or not hex:match('^%x%x%x%x%x%x$') then return nil end
  return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

-- Optional metadata is never allowed to invalidate or renumber the paint itself.
function A.optional(entry, label)
  local result = {}
  if entry.gta ~= nil then
    if rgb(entry.gta) then result.gta = entry.gta:lower()
    else print(('[realpaints] invalid gta for %s; ignored'):format(tostring(label))) end
  end
  if entry.pearl ~= nil then
    if type(entry.pearl) == 'number' and entry.pearl == math.floor(entry.pearl)
        and entry.pearl >= 0 and entry.pearl <= 160 then
      result.pearl = entry.pearl
    else print(('[realpaints] invalid pearl for %s; ignored'):format(tostring(label))) end
  end
  if entry.status ~= nil then
    if entry.status == 'unset' or entry.status == 'measured' or entry.status == 'reviewed' then
      result.status = entry.status
    else print(('[realpaints] invalid status for %s; ignored'):format(tostring(label))) end
  end
  return result
end

function A.colour(entry)
  return rgb(entry.gta) or rgb(entry.hex)
end

-- Pure bookkeeping also used by the server, with no client-supplied values.
function A.saveMods(mods, paint, part)
  if part == 'primary' or part == 'both' then
    mods.color1 = { paint.rgb[1], paint.rgb[2], paint.rgb[3] }
    mods.paintType1 = paint.finish
  end
  if part == 'secondary' or part == 'both' then
    mods.color2 = { paint.rgb[1], paint.rgb[2], paint.rgb[3] }
    mods.paintType2 = paint.finish
  end
  if paint.pearl ~= nil then mods.pearlescentColor = paint.pearl end
  return mods
end

function A.applyVehicle(vehicle, paint, part)
  if part ~= 'primary' and part ~= 'secondary' and part ~= 'both' then return false end
  local pearl, wheel = GetVehicleExtraColours(vehicle)
  local keep = paint.pearl ~= nil and paint.pearl or pearl
  SetVehicleModKit(vehicle, 0)
  local r, g, b = paint.rgb[1], paint.rgb[2], paint.rgb[3]
  if part == 'primary' or part == 'both' then
    SetVehicleModColor_1(vehicle, paint.finish, 0, keep)
    SetVehicleCustomPrimaryColour(vehicle, r, g, b)
  end
  if part == 'secondary' or part == 'both' then
    SetVehicleModColor_2(vehicle, paint.finish, 0)
    SetVehicleCustomSecondaryColour(vehicle, r, g, b)
  end
  SetVehicleExtraColours(vehicle, keep, wheel)
  return true
end
return A
