RPConfig = {
  -- Inventory item that opens the paint menu when used (item must already exist in qb-core shared items).
  Item = 'paintcan',
  -- true = one spray can is removed from the inventory each time a paint is applied with it.
  ConsumeItem = true,
  -- Milliseconds the spray animation / progress circle lasts (can mode only).
  SprayTime = 8000,
  -- How close (metres) the player must be to the vehicle when using the can.
  MaxDistance = 3.0,
  -- Chat command name (without the slash) for vMenu-style instant respray from the driver seat.
  Command = 'realpaint',
  -- Players may use the command if they have one of these ACE permissions,
  -- or one of the QBCore permissions listed below. Other players remain restricted.
  -- Grant only this feature permanently via server.cfg:
  -- add_ace identifier.license:YOUR_LICENSE realpaints.command allow
  CommandAces = { 'realpaints.command', 'vMenu.VehicleOptions.Colors', 'vMenu.VehicleOptions.All', 'vMenu.Everything' },
  -- QBCore administrators retain command access across restarts if their admin
  -- permissions are configured persistently in the server's QBCore/ACE setup.
  CommandQBPermissions = { 'god', 'admin' },
  -- true = the command only works from the driver seat of a vehicle.
  CommandRequiresDriver = true,
  -- true = after spraying, write the new colour into player_vehicles.mods so it survives garage store/retrieve and restarts.
  SaveToGarage = true,
  -- true = the spray can only works on vehicles owned by the player (player_vehicles.citizenid).
  CanRequiresOwnership = false,
  -- true = the command only works on vehicles owned by the player.
  CommandRequiresOwnership = false,
}
