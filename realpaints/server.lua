local QBCore = exports['qb-core']:GetCoreObject()

print(('[realpaints] %d colours loaded'):format(#RealPaintsList))

local lastUse = {}

local function allowed(src)
  for _, ace in ipairs(RPConfig.CommandAces or {}) do
    if IsPlayerAceAllowed(tostring(src), ace) then return true end
  end
  return false
end

local function trim(s)
  s = tostring(s or '')
  s = s:gsub('^%s+', '')
  s = s:gsub('%s+$', '')
  return s
end

local function fail(reason)
  return { ok = false, reason = reason }
end

QBCore.Functions.CreateUseableItem(RPConfig.Item, function(source, item)
  TriggerClientEvent('realpaints:client:openCan', source, item and item.slot or nil)
end)

RegisterCommand(RPConfig.Command, function(src)
  if src == 0 then return end
  if allowed(src) then
    TriggerClientEvent('realpaints:client:openCommand', src)
  else
    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You are not allowed to use this command.' })
  end
end, false)

local VALID_PART = { primary = true, secondary = true, both = true }
local VALID_MODE = { can = true, command = true }

lib.callback.register('realpaints:server:apply', function(src, req)
  if type(req) ~= 'table' then return fail('Bad request.') end

  local now = GetGameTimer()
  if lastUse[src] and now - lastUse[src] < 2000 then return fail('Slow down.') end
  lastUse[src] = now

  -- Never trust client colours: only the paint id is used, the colour comes from the server-side list.
  local paint = RPGetPaint(req.paintId)
  if not paint then return fail('Unknown paint.') end
  if type(req.part) ~= 'string' or not VALID_PART[req.part] then return fail('Bad paint part.') end
  if type(req.mode) ~= 'string' or not VALID_MODE[req.mode] then return fail('Bad mode.') end
  if type(req.netId) ~= 'number' then return fail('Bad vehicle.') end

  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return fail('Player not found.') end

  local veh = NetworkGetEntityFromNetworkId(req.netId)
  if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
    return fail('Vehicle not found.')
  end

  local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
  if dist > (RPConfig.MaxDistance + 2.0) then return fail('You are too far from the vehicle.') end

  local needOwnership
  if req.mode == 'command' then
    if not allowed(src) then return fail('You are not allowed to do that.') end
    if GetVehiclePedIsIn(ped, false) ~= veh then return fail('You must be in the vehicle.') end
    if RPConfig.CommandRequiresDriver and GetPedInVehicleSeat(veh, -1) ~= ped then
      return fail('You must be the driver.')
    end
    needOwnership = RPConfig.CommandRequiresOwnership
  else
    if not exports['qb-inventory']:HasItem(src, RPConfig.Item, 1) then return fail('You do not have a spray can.') end
    needOwnership = RPConfig.CanRequiresOwnership
  end

  local plate = trim(GetVehicleNumberPlateText(veh))

  if needOwnership then
    local player = QBCore.Functions.GetPlayer(src)
    local cid = player and player.PlayerData and player.PlayerData.citizenid
    local row = cid and MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', { plate })
    if not row or row.citizenid ~= cid then return fail('This is not your vehicle.') end
  end

  if req.mode == 'can' and RPConfig.ConsumeItem then
    local removed = exports['qb-inventory']:RemoveItem(src, RPConfig.Item, 1, req.slot, 'realpaints')
    if not removed then removed = exports['qb-inventory']:RemoveItem(src, RPConfig.Item, 1, nil, 'realpaints') end
    if not removed then return fail('Could not use the spray can.') end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[RPConfig.Item], 'remove')
  end

  local saved = false
  if RPConfig.SaveToGarage and plate ~= '' then
    local row = MySQL.single.await('SELECT mods FROM player_vehicles WHERE plate = ?', { plate })
    if row then
      local mods = {}
      if type(row.mods) == 'string' and row.mods ~= '' then
        local ok, decoded = pcall(json.decode, row.mods)
        if ok and type(decoded) == 'table' then mods = decoded end
      end
      if req.part == 'primary' or req.part == 'both' then
        mods.color1 = { paint.rgb[1], paint.rgb[2], paint.rgb[3] }
        mods.paintType1 = paint.finish
      end
      if req.part == 'secondary' or req.part == 'both' then
        mods.color2 = { paint.rgb[1], paint.rgb[2], paint.rgb[3] }
        mods.paintType2 = paint.finish
      end
      MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', { json.encode(mods), plate })
      saved = true
    end
  end

  return { ok = true, rgb = paint.rgb, finish = paint.finish, saved = saved }
end)

AddEventHandler('playerDropped', function()
  lastUse[source] = nil
end)
