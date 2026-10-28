local currentMode = nil
local currentSlot = nil
local built = false

local FINISH_LABEL = { [0] = 'Solid', 'Metallic', 'Pearl', 'Matte', 'Satin', 'Chrome' }

local function notify(kind, text)
  lib.notify({ type = kind, description = text })
end

-- Find the vehicle this action applies to, or nil (and a notification).
local function getTargetVehicle()
  if currentMode == 'can' then
    if cache.vehicle then
      notify('error', 'Get out of the vehicle to use the spray can.')
      return nil
    end
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), RPConfig.MaxDistance, false)
    if not veh or veh == 0 then
      notify('error', 'No vehicle nearby.')
      return nil
    end
    return veh
  end

  local veh = GetVehiclePedIsIn(cache.ped, false)
  if not veh or veh == 0 then
    notify('error', 'You must be in a vehicle.')
    return nil
  end
  if RPConfig.CommandRequiresDriver and GetPedInVehicleSeat(veh, -1) ~= cache.ped then
    notify('error', 'You must be the driver.')
    return nil
  end
  return veh
end

local function takeControl(veh)
  local tries = 0
  while not NetworkHasControlOfEntity(veh) and tries < 20 do
    NetworkRequestControlOfEntity(veh)
    Wait(100)
    tries = tries + 1
  end
end

local function applyPaint(paint, part)
  local veh = getTargetVehicle()
  if not veh then return end

  if currentMode == 'can' then
    local done = lib.progressCircle({
      duration = RPConfig.SprayTime,
      label = 'Spraying...',
      useWhileDead = false,
      canCancel = true,
      disable = { move = true, car = true, combat = true },
      anim = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 49 },
      prop = {
        model = 'ng_proc_spraycan01a',
        bone = 57005,
        pos = vec3(0.072, 0.041, -0.06),
        rot = vec3(33.0, 38.0, 0.0),
      },
    })
    if not done then
      notify('error', 'Cancelled.')
      return
    end
    veh = getTargetVehicle()
    if not veh then return end
  end

  local res = lib.callback.await('realpaints:server:apply', false, {
    netId = NetworkGetNetworkIdFromEntity(veh),
    paintId = paint.id,
    part = part,
    mode = currentMode,
    slot = currentSlot,
  })

  if not res or not res.ok then
    notify('error', (res and res.reason) or 'Could not apply paint.')
    return
  end

  takeControl(veh)
  SetVehicleModKit(veh, 0)
  local r, g, b = res.rgb[1], res.rgb[2], res.rgb[3]
  if part == 'primary' or part == 'both' then
    SetVehicleModColor_1(veh, res.finish, 0, 0)
    SetVehicleCustomPrimaryColour(veh, r, g, b)
  end
  if part == 'secondary' or part == 'both' then
    SetVehicleModColor_2(veh, res.finish, 0)
    SetVehicleCustomSecondaryColour(veh, r, g, b)
  end

  local text = ('Applied %s %s.'):format(paint.brand, paint.name)
  if res.saved then text = text .. ' Saved to garage.' end
  notify('success', text)
end

local function showPartMenu(paint, backId)
  lib.registerContext({
    id = 'realpaints_part',
    title = ('%s %s'):format(paint.brand, paint.name),
    menu = backId,
    options = {
      { title = 'Primary', icon = 'fill-drip', iconColor = '#' .. paint.hex, onSelect = function() applyPaint(paint, 'primary') end },
      { title = 'Secondary', icon = 'fill', iconColor = '#' .. paint.hex, onSelect = function() applyPaint(paint, 'secondary') end },
      { title = 'Both', icon = 'palette', iconColor = '#' .. paint.hex, onSelect = function() applyPaint(paint, 'both') end },
    },
  })
  lib.showContext('realpaints_part')
end

local function buildMenus()
  if built then return end
  built = true

  local rootOptions = {}
  for ri, region in ipairs(RealPaintsRegions) do
    local regionId = 'realpaints_region_' .. ri
    local regionOptions = {}

    for bi, brand in ipairs(region.brands) do
      local brandId = ('realpaints_brand_%d_%d'):format(ri, bi)
      local colourOptions = {}
      for _, paint in ipairs(brand.colours) do
        local desc = FINISH_LABEL[paint.finish] or 'Metallic'
        if paint.code then desc = paint.code .. ' - ' .. desc end
        colourOptions[#colourOptions + 1] = {
          title = paint.name,
          description = desc,
          icon = 'circle',
          iconColor = '#' .. paint.hex,
          onSelect = function() showPartMenu(paint, brandId) end,
        }
      end
      lib.registerContext({ id = brandId, title = brand.brand, menu = regionId, options = colourOptions })
      regionOptions[#regionOptions + 1] = {
        title = brand.brand,
        description = ('%d colours'):format(#brand.colours),
        icon = 'fill-drip',
        menu = brandId,
        arrow = true,
      }
    end

    lib.registerContext({ id = regionId, title = region.region, menu = 'realpaints_root', options = regionOptions })
    rootOptions[#rootOptions + 1] = { title = region.region, icon = 'globe', menu = regionId, arrow = true }
  end

  lib.registerContext({ id = 'realpaints_root', title = 'Real Paints', options = rootOptions })
end

local function openMenu(mode, slot)
  currentMode = mode
  currentSlot = slot
  if #RealPaintsList == 0 then
    notify('error', 'No paints available.')
    return
  end
  if not getTargetVehicle() then return end
  buildMenus()
  lib.showContext('realpaints_root')
end

RegisterNetEvent('realpaints:client:openCan', function(slot)
  openMenu('can', slot)
end)

RegisterNetEvent('realpaints:client:openCommand', function()
  openMenu('command', nil)
end)

-- Register the command locally so chat and F8 both open it on this client.
-- The server still decides whether the player may use the command.
RegisterCommand(RPConfig.Command, function()
  print(('[realpaints] /%s invoked on client'):format(RPConfig.Command))

  local ok, permitted = pcall(function()
    return lib.callback.await('realpaints:server:canUseCommand', false)
  end)
  if not ok then
    print(('[realpaints] permission check failed: %s'):format(tostring(permitted)))
    notify('error', 'RealPaints permission check failed. See F8 console.')
    return
  end
  if not permitted then
    notify('error', 'You are not allowed to use this command.')
    return
  end

  openMenu('command', nil)
end, false)

print(('[realpaints] client ready; command /%s registered'):format(RPConfig.Command))

CreateThread(function()
  Wait(1000)
  TriggerEvent('chat:addSuggestion', '/' .. RPConfig.Command, 'Apply a real-world factory paint')
end)
