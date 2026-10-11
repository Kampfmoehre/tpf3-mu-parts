# Buyable Multiple Unit Parts (Transport Fever 3)

A small script mod for Transport Fever 3 that offers the **parts of
multiple-unit sets as single vehicles** in the depot: power cars and the
special coaches that are normally only available inside the complete set,
for example the Inter-City 125 power car and its buffet coach, or the
Re 450 locomotive and its driving trailer.

- The complete sets stay available.
- When loading a game you choose **per set** whether its parts are unlocked.
  Default: Inter-City 125, Re 450 DPZ and RABe 502 Twindexx.
  A last switch covers sets from other mods.
- The parts are listed as variants of their set in the "Multiple Unit" tab:
  expanding the set shows the complete set first, then its parts in set
  order. Parts get their role appended to the name so they can be told apart,
  e.g. "ICE 1 (power car)", "ICE 1 (middle car 2)" or
  "Britischer Mark 3 Passagierwagen (middle car)". With the switch
  "Show parts as variants of their set" off, the parts appear between the
  other locomotives and wagons instead (without role names).
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
- The Deluxe Upgrade Pack's TEE VT 11.5 ships a large store image only for
  its end car; its middle cars show the game's placeholder texture in the
  preview. The base-game sets have images for all parts.
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

### Parts as variants of their set

The vehicle store groups vehicles by `transportVehicle.groupFileName`
(`vehicle_store_window.tl`, `variantGroup2muAndVariants`): a vehicle whose
group names another store entry is hidden from the flat list and shown under
that entry, which gets an expand arrow. The engine only accepts a *model*
path there (a `.mu` path is dropped with "referenced model not found"), and a
model-headed group sorts badly (power cars without capacity always come
first) and shows the head's name and image.

So the work is split:

- `mod.script.lua` marks every unlocked part of a set with
  `groupFileName` = the first unlocked part of that set. That is only a
  marker.
- `content/gui/kampfmoehre_mu_parts/mu_parts.script.lua`, loaded as a
  `::ModEntryPointExtension` react plugin, wraps functions of the shared
  `vehicle_store_util` module table:
  - `makeVehicleData`: a marked part's `variantGroup` becomes the set's
    `.mu` path, so the set heads the group.
  - `vehicleFilter`: in the "Multiple Unit" tab (`withEngine` and
    `withCapacity` both true) parts are checked without the engine/capacity
    conditions, so unpowered coaches appear under their set.
  - `getPrimaryBucket`: the store sorts by this bucket (no capacity <
    passengers < passengers+cargo < cargo) before the chosen sort key, also
    inside a group. Parts get a bucket after all others, ordered by their
    position in the set, so the set comes first and ties (same year, same
    name) do not shuffle the parts.
  - `getVehicleNameAndIcons`: appends the role. "power car" = engine without
    capacity, "end car" = first or last in the set, otherwise "middle car";
    numbered when a set has several parts with the same role. Changing
    `description.name` in the `postRunFn` has no effect on the store, it shows
    the translated name key of the model.

## Development

```
kampfmoehre_mu_parts_1/            the mod (this is what gets published)
  mod.json                         mod id, one Off/On parameter per set
  strings.json                     translations (en, de)
  _metadata/modinfo.json           name, summary, description (+ de)
  _metadata/0.png … 5.png          title and gallery images, 1920x1080
                                   (0-2 grouped, 3-5 with the switch off)
  content/mod.script.lua           postRunFn: unlock and mark the parts
  content/gui/kampfmoehre_mu_parts/
    entry.res.lua                  registers the react plugin
    mu_parts.script.lua            vehicle store hooks (grouping, names, order)
sync.sh                            copies the mod into the game's staging area
```

Workflow: edit, `./sync.sh`, reload the savegame (the parameters are read on
load). Both scripts print `[mu_parts]` lines to
`.../3493540/local/crash_dump/stdout.txt`. Before uploading a new version
through the in-game Mod-Hub, increase `revision` in `mod.json`.

## License

MIT, see `LICENSE`.
