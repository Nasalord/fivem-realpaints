# fivem-realpaints

Real-world car paint colours (BMW, Porsche, Ferrari, Nissan, and more) for a FiveM QBCore server.

It does two things from ONE shared colour list:

1. Adds new colour tabs (one per region: German, Italian, Japanese, American, British, Other) to the jg-mechanic respray menu.
2. Adds a standalone `realpaints` resource: a usable Vehicle Spray Can item (`paintcan`) and a `/realpaint` command for players who use vMenu. Both open a menu of the same paints.

Each swatch is a real manufacturer paint with its real name and code, applied with its GTA paint finish (solid, metallic, pearl, matte, satin or chrome).

Written for jg-mechanic v1.6.5, qb-inventory, ox_lib and oxmysql. This repo contains only our own code and colour data. It contains no JG Scripts files.

## Repo layout

    data/realpaints-data.lua              the ONLY colour list (edit this to add colours)
    jg-mechanic/config/zz-realpaints.loader.lua  loader template (never loaded directly, see below)
    realpaints/                           the standalone resource (spray can + command)
    deploy.ps1, rollback.ps1

## What the deploy changes

`deploy.ps1` changes these places on the server:

1. jg-mechanic `config\zz-realpaints.lua` (new): ONE file made by deploy from the colour list followed by the loader template. Because it is a single file, the order FiveM loads files in does not matter. If an older `zz-realpaints-data.lua` is found there it is backed up and deleted.
2. jg-mechanic `client\cl-mods.lua` (two small blocks added, each marked `-- REALPAINTS`).
3. jg-mechanic `client\cl-vehicleprops.lua` (one small block added, marked `-- REALPAINTS`).
4. A new resource folder `resources\[standalone]\realpaints\` (it starts automatically because `[standalone]` is started on boot).

Before changing anything it saves a backup to `E:\MAIN SERVER\resource-backups\realpaints-<date-time>`. If it cannot find the exact lines it expects, it stops and changes nothing.

## Deploy (first time)

Open PowerShell and run:

    New-Item -ItemType Directory -Force "E:\MAIN SERVER\deploy" | Out-Null
    git clone https://github.com/<your-github-username>/fivem-realpaints.git "E:\MAIN SERVER\deploy\fivem-realpaints"
    powershell -ExecutionPolicy Bypass -File "E:\MAIN SERVER\deploy\fivem-realpaints\deploy.ps1"

Then in the txAdmin Live Console type these, one at a time:

    refresh
    ensure realpaints
    restart jg-mechanic

The console should show `[realpaints] loaded N colours in N tabs` (jg-mechanic) and `[realpaints] N colours loaded` (the resource).

## Using it

- Spray can: give yourself one with `/giveitem <id> paintcan 1` (admin). Stand next to a car, use the item, pick region, brand and colour, then Primary / Secondary / Both. A spray animation plays, the paint is applied and the can is used up.
- Command: sit in the driver seat and type `/realpaint`. Allowed for anyone with a vMenu colour permission (see `realpaints/config.lua`).
- The colour is saved to the vehicle in the garage database, so it stays after storing and retrieving the vehicle and after a restart.

## Settings

Edit `realpaints/config.lua` in the repo (not on the server, deploy overwrites it): which item, whether the can is used up, spray time, distance, command name, which ACE permissions may use the command, whether ownership is required, whether to save to the garage.

## Update

    git -C "E:\MAIN SERVER\deploy\fivem-realpaints" pull
    powershell -ExecutionPolicy Bypass -File "E:\MAIN SERVER\deploy\fivem-realpaints\deploy.ps1"

Then `refresh`, `ensure realpaints` and `restart jg-mechanic` in the txAdmin Live Console. Running deploy again is safe: it re-copies the files, skips patches that are already in, and makes a fresh backup.

## Rollback

    powershell -ExecutionPolicy Bypass -File "E:\MAIN SERVER\deploy\fivem-realpaints\rollback.ps1"

This restores the original jg-mechanic client files from the newest backup that was taken before patching, removes the jg-mechanic config file it added (and restores an old `zz-realpaints-data.lua` if one existed), and removes the `realpaints` resource folder (or restores the old one if there was one). Then in the txAdmin Live Console: `stop realpaints`, `refresh`, `restart jg-mechanic`.

To restore from a specific backup:

    powershell -ExecutionPolicy Bypass -File "E:\MAIN SERVER\deploy\fivem-realpaints\rollback.ps1" -BackupDir "E:\MAIN SERVER\resource-backups\realpaints-20260101-120000"

## Adding colours

Edit `data/realpaints-data.lua`. Each brand looks like this:

    {
      brand = "BMW", region = "German",
      colours = {
        { code = "C4G", name = "Isle of Man Green", hex = "036358", finish = "metallic" },
      },
    },

Rules:

- `code` is optional. Leave it out if you are not sure of it.
- `hex` is 6 lowercase hex digits, no `#`.
- `finish` is one of: solid, metallic, pearl, matte, satin, chrome.
- `region` is one of: German, Italian, Japanese, American, British, Other.
- Use plain ASCII in names (no accents or fancy quotes).
- Add new colours only at the END of a brand's list, or add new brands at the END of the data, so the IDs of existing colours stay stable (saved vehicles use those IDs).

Commit, push, then update on the server (see Update above).

Set `RealPaints.TabMode = "brand"` near the top of `jg-mechanic/config/zz-realpaints.loader.lua` to get one jg-mechanic tab per manufacturer instead of one per region.

## Notes

- In jg-mechanic, pearlescent, wheel, dashboard and interior pickers only accept stock GTA palette colours, so a real paint picked there is swapped for the closest GTA colour.
- Benny's (renzu_customs) and vMenu itself are not changed.
