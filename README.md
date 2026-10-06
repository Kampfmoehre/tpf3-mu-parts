# Buyable Multiple Unit Parts (Transport Fever 3)

A small script mod for Transport Fever 3 that offers the **parts of
multiple-unit sets as single vehicles** in the depot: power cars and the
special coaches that are normally only available inside the complete set,
for example the Inter-City 125 power car and its buffet coach, or the
Re 450 locomotive and its driving trailer.

- The complete sets stay available.
- When loading a game you choose **per set** whether its parts are unlocked.
  Default: Inter-City 125, Re 450 DPZ, RABe 502 Twindexx and ES1 Lastochka.
  A last switch covers sets from other mods.
- Unlocked parts get their role from the file name appended to the name so
  they can be told apart, e.g. "Inter-City 125 (front)" or
  "Britischer Mark 3 Passagierwagen (middle2)".
- Nothing new is added to the game, existing vehicles are only offered
  differently, so the mod is marked cosmetic and achievements stay enabled.
- English and German; set names come from the game's own translations.

Available on mod.io: <https://mod.io/g/transportfever3/m/buyable-multiple-unit-parts>

## Notes

- Parts of electric multiple units often carry motors in the middle cars
  (Shinkansen, ES1, Twindexx), so a single middle car runs on its own. The
  game only checks for an engine, not for a driver's cab. Build sensible
  consists yourself.
- Prices of the parts are computed by the game from power and capacity, as
  for every base-game vehicle.
- Removing the mod from a savegame leaves already bought part vehicles in
  place, but they can no longer be bought (`severityRemove: Warning`).

## Installation

Subscribe on mod.io or in the in-game Mod-Hub, enable the mod when loading
or creating a game and pick the sets in the mod settings.

Manual installation: copy the folder `kampfmoehre_mu_parts_1` into the
game's local mod directory, on Linux
`~/.local/share/Steam/userdata/<steam-id>/3493540/local/mods/`.

## How it works

The depot's vehicle list drops every vehicle whose
`transportVehicle.filterTags` is empty (base
`vehicle_store_util.depotMatchesVehicleFilterTags`). Set-only parts ship with
empty filter tags, ordinary coaches with `{ "default" }`. The `multipleUnitOnly`
field found in the model files is not known to the engine and has no effect.

`content/mod.script.lua` runs as the mod's `postRunFn` after all resources
are loaded. For every enabled set it reads the multiple-unit definition
(`api.res.multipleUnitRep`), resolves its part models and, for parts without
filter tags, writes the set's tags into the model metadata via
`api.res.modelRep.getAsTable` / `setAsTable`, the same way the official
campaign mods adjust vehicle data. The mod parameters are declared in
`mod.json`; their names reuse the game's `VEHICLE_MULTIPLEUNIT_*_NAME`
translation keys. Parameter values arrive 1-based in `allModParams`.

## Development

```
kampfmoehre_mu_parts_1/            the mod (this is what gets published)
  mod.json                         mod id, one Off/On parameter per set
  strings.json                     translations (en, de)
  _metadata/modinfo.json           name, summary, description (+ de)
  _metadata/0.png, 1.png           title and gallery image, 1920x1080
  content/mod.script.lua           the actual code (postRunFn)
sync.sh                            copies the mod into the game's staging area
```

Workflow: edit, `./sync.sh`, reload the savegame (the parameters are read on
load). The script prints `[mu_parts]` lines to
`.../3493540/local/crash_dump/stdout.txt`. Before uploading a new version
through the in-game Mod-Hub, increase `revision` in `mod.json`.

## License

MIT, see `LICENSE`.
