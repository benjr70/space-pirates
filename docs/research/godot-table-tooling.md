# Godot table tooling for `WeaponProfile`: the facts

Research for the "master sheet" decision: ways to see and edit one custom
Resource type across many instances as a single table in Godot 4, and to have
changes show up in a running game. This note lays out facts and trade-offs. It
does not pick an option.

Researched 2026-11-22. Nothing here was run in Godot; every claim marked
**Verified** was read in the linked source, and every claim marked
**Inferred** is a conclusion drawn from those sources that nobody has tested
in this project.

## The project as it stands

- Engine: Godot 4.7 (`config/features=PackedStringArray("4.7", "Forward Plus")`
  in `project.godot`). Latest upstream release at time of writing is
  4.7.2-stable, 2026-08-18
  ([releases](https://github.com/godotengine/godot/releases)).
- `scripts/weapon_profile.gd` exports 34 fields: 24 `float`, 2 `int`
  (`magazine_size`, `damage`), 1 `bool` (`semi_auto`), 2
  `Vector3` (`pose_hip`, `pose_low`), 4 `StringName` (`fire_clip`,
  `model_fire_clip`, `model_reload_clip`, `model_rack_clip`) and 1
  `PackedScene` (`model`).
- Two instances today: `resources/weapons/carbine.tres` and `sidearm.tres`.
  Each is a text `.tres` with one `name = value` line per property, the scene
  as `ExtResource("2")`, vectors as `Vector3(0.13, -0.19, -0.4)` and names as
  `&"fire"`.
- No table addon is installed (`addons/` holds only an art pack).

Godot has no built-in table view of Resources. The proposal to add a
spreadsheet resource has been open since 2019
([godot-proposals #13](https://github.com/godotengine/godot-proposals/issues/13)).

## (a) Editor addons that show Resources as a table

### Edit Resources as Table (don-tnowe)

Repo: <https://github.com/don-tnowe/godot-resources-as-sheets-plugin>.
Asset library: <https://godotengine.org/asset-library/asset/1479>.

**Verified**

- What it is: "adds a tab for viewing and editing folders of Resources as
  data tables, one Resource per row"
  ([README](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/blob/master/README.md)).
  It works on the existing `.tres` files in place; no data migration.
- Maturity: MIT, about 1,030 stars, 30 open issues and PRs, not archived, no
  GitHub releases or tags. `plugin.cfg` on master says version 2.7; the asset
  library entry is titled "Edit Resources as Table 2", version string 2.17.4.
- Maintenance: last push to master 2026-10-31, with several community PRs
  merged that day.
- Godot 4.7: PR
  [#129 "fix: plugin main screen for Godot 4.7"](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/pull/129)
  says the addon was broken on 4.7 and was merged 2026-10-31. The asset
  library entry is pinned to commit `3363e0d` from 2026-01-27, and master is
  16 commits ahead of it. So the asset-library build predates the 4.7 fix;
  the fix is only on master. The PR text gives Godot 4.2 as the minimum
  working version after the change; the asset library lists 4.0.
- README features: keyboard editing of text, numbers, colors and booleans;
  multi-cell select in one column, then type into all or edit all in the
  Inspector; multiply or add across selected numbers; sort by column; filter
  rows by a GDScript expression or by class; hide columns; undo and redo.
- Layout is one weapon per row, one property per column. The addon has
  frozen columns and column hiding; column reordering is an open request
  ([#114](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/114)).
  No transposed view (weapons as columns) is mentioned in the README.
- Field types, from the cell editor source
  ([`typed_cells/`](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/tree/master/addons/resources_spreadsheet_view/typed_cells)):
  - `float` and `int`: a number cell, typed directly. `from_text` returns
    `text.to_float()`; `edit_tres.gd` casts back to `int` when the previous
    value was an `int`.
  - `bool`: a checkbox cell; toggled by selecting and pressing a key, click
    to toggle is an open request
    ([#43](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/43)).
  - `StringName`: handled by the string cell; `edit_tres.gd` writes
    `StringName(value)` when the previous value was a `StringName`. An
    earlier bug saved `StringName` as `String` and `int` as `float`, which
    "create[d] unnecessary git changes"; closed 2025-05-06
    ([#95](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/95)).
  - `Vector3`: there is no Vector cell editor. The list of editors is enum
    array, dict, array, color, bool, enum, resource, number, string. A
    `Vector3` falls through to the base `cell_editor.gd`, which shows
    `str(value)` and edits text through `var_to_str` and `str_to_var`.
  - `PackedScene`: the resource cell (`can_edit_value` is `type ==
    TYPE_OBJECT`) shows a preview and label and is not text-editable
    (`is_text()` returns false). Changing it goes through the Inspector. A
    request for a dedicated PackedScene control was closed as not planned
    ([#118](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/118)).
- Saving: `edit_tres.gd` `save_entries` is a no-op with the comment
  "Resources are saved with Ctrl+S". Edits change the loaded Resource in
  memory and reach disk on the editor's normal save.
- Git: the files on disk stay the same per-weapon `.tres`, so a balance
  change is a one-line diff in that weapon's file. The addon also writes a
  `saved_state.json` (recent paths, column visibility) that flips values
  between `0` and `0.0` and makes git noise; open
  ([#120](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/120)).
- It can also open a table over sub-resources held inside one Resource: a
  path of the form `folder::property` makes rows from the Resources or
  arrays found in that property (`edit_tres.gd`, `import_from_path` and
  `_append_soloed_property`). This is relevant to option (c).
- It has CSV import, export and "edit directly" modes. See (b).

**Inferred**

- Editing a `Vector3` cell as text means typing the full literal, for example
  `Vector3(0.16, -0.18, -0.3)`, because that is the `var_to_str` form
  ([`variant_parser.cpp` L2055](https://github.com/godotengine/godot/blob/4.7-stable/core/variant/variant_parser.cpp#L2055)).
  Not tested.
- Table edits will probably not reach a running game through the editor's
  live sync. See (d).

### Godot Resource Manager (IMP1)

Repo: <https://github.com/IMP1/godot-resource-manager>.

**Verified** (README and repo metadata)

- "A Godot 4.x Plugin for easier editing of custom resources by displaying
  them all in more of a 'spreadsheet' format." Lists every instance of a
  chosen `class_name` type, found by scanning project folders.
- Its README type list marks `bool`, `int`, `float`, `String`, `Vector3`,
  `StringName`, `Color` and `Resource` as directly editable in the view.
  `PROPERTY_HINT_RANGE` is unchecked.
- Maturity: 2 stars, one release (v0.1.0, 2025-12-10; README says v0.2.0),
  last push 2025-12-21, no open issues. README links Godot 4.4 docs. No
  statement about 4.7. Not found in the asset library search.

### Resource Databases (DarthPapalo)

Repo: <https://github.com/DarthPapalo/ResourceDatabases>.

**Verified** (README and repo metadata): 123 stars, latest release
1.4.0-stable on 2026-05-09. The README describes a "database editor" that
groups resources into collections and categories and loads them at runtime by
UID or path. It describes organising and looking up resources; it does not
describe a grid of property columns. Whether it shows properties side by
side was not established.

### Pandora (bitbrain)

Repo: <https://github.com/bitbrain/pandora>.

**Verified**: about 1,135 stars, last push 2026-08-20, latest release
v1.0-alpha10 on 2026-07-27. The README carries the banner "THIS ADDON IS
STILL IN ALPHA AND NOT PRODUCTION-READY YET". It is not a view over existing
Resources: data lives in its own `data.pandora` file as entities and
categories with inherited properties, read at runtime through a `Pandora`
singleton. Documented property types include bool, integer, float, string,
color, vector2, vector3, resource and reference
([docs](https://github.com/bitbrain/pandora/tree/godot-4.x/docs/concepts/properties)).
Adopting it would replace `WeaponProfile` as the data model rather than
table it.

### Others found, lower maturity

**Verified** from repo metadata only:

- [Ward727a/godot_datatable_plugin](https://github.com/Ward727a/godot_datatable_plugin):
  Unreal-style datatables in its own storage. Archived; README says "Project
  in stand-by" since 2024-10-01.
- [meishijie JSON Table Editor](https://github.com/meishijie/JSON-Editor-Plugin-for-Godot-4.x)
  (asset 3631): edits JSON files as tables. 29 stars, last push 2025-07-01.
- [WitchHat07/ResPort](https://github.com/WitchHat07/ResPort): CSV import
  and export of Resource data. 2 stars, last push 2026-02-03, no README at
  the repo root.

## (b) CSV or JSON as the source of truth

### What the engine gives you

**Verified**

- CSV reading and writing: `FileAccess.get_csv_line` returns a
  `PackedStringArray` per line with standard quoting; `store_csv_line` is the
  inverse
  ([FileAccess](https://docs.godotengine.org/en/4.7/classes/class_fileaccess.html)).
  Every cell is a string; there is no schema or type column in the engine.
- A `.csv` in the project is claimed by the translation importer: the
  `ResourceImporterCSVTranslation` importer is the engine's recogniser for
  the `csv` extension
  ([source](https://github.com/godotengine/godot/blob/4.7-stable/editor/import/resource_importer_csv_translation.cpp#L46),
  [class docs](https://docs.godotengine.org/en/4.7/classes/class_resourceimportercsvtranslation.html)).
  The Import dock can change a file to "Keep File (exported as is)" or "Skip
  File (not exported)"
  ([import process](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html)).
- Exported builds: non-resource files such as `.txt`, `.json` and `.csv` are
  only included if added to the export filters
  ([exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)).
- JSON: `JSON.parse` yields Dictionaries, Arrays, Strings, numbers and
  booleans. Numbers are parsed with `String.to_float`
  ([JSON](https://docs.godotengine.org/en/4.7/classes/class_json.html)), so
  `magazine_size` and `damage` arrive as floats and need a cast.
- Typed values in text:
  - `var_to_str` and `str_to_var` round-trip Variants in the same notation
    `.tres` files use: `Vector3(x, y, z)`, `&"name"` for `StringName`, and
    `Resource("res://path")` (or a `uid://`) for a Resource with a path
    ([@GlobalScope](https://docs.godotengine.org/en/4.7/classes/class_@globalscope.html#class-globalscope-method-var-to-str),
    [`variant_parser.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/core/variant/variant_parser.cpp#L2005)).
  - `JSON.from_native` and `JSON.to_native` encode engine types into
    JSON-compliant values. In the source, a `StringName` becomes the string
    `"sn:name"`, a `String` becomes `"s:text"`, and a `Vector3` becomes a
    dictionary with `"type"` and `"args": [x, y, z]`. Objects are skipped
    unless `full_objects` / `allow_objects` is true
    ([`json.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/core/io/json.cpp#L650)).
- An `EditorImportPlugin` can turn a source file into a saved Resource at
  import time
  ([import plugins](https://docs.godotengine.org/en/4.7/tutorials/plugins/editor/import_plugins.html)).

**Inferred**

- A hand-written loader has to map each column to a `WeaponProfile` property
  and convert by type. The 24 floats, 2 ints and 1 bool are trivial. Each
  `Vector3` is either three columns or one cell holding a literal.
  `StringName` is a plain string cell cast on load. `PackedScene` is a path
  cell passed to `load()`; renaming or moving the scene in the editor will
  not update a path stored in a CSV, whereas the `.tres` `ext_resource` line
  is rewritten by the editor. Not tested.
- `preload` and typed `@export var profile: WeaponProfile` references keep
  working only if the CSV is converted into Resources (import plugin or a
  generate step). A CSV read at runtime with `FileAccess` produces
  `WeaponProfile` objects in memory that have no `resource_path`.
- Doc comments on the script (the `##` lines that explain each field) show
  as tooltips in the Inspector but do not travel into a CSV or JSON file.

### CSV addons

**Verified**

- [timothyqiu/godot-csv-data-importer](https://github.com/timothyqiu/godot-csv-data-importer)
  (asset 1793): 129 stars, last push 2026-06-22; asset library entry v2.0
  dated 2023-04-05, listed for Godot 4.0. Imports CSV or TSV "as a custom
  `Resource` object" whose `records` is an array of string arrays or, with
  Headers on, Dictionaries. Options detect numbers and booleans. Nothing in
  the README covers Vector3, StringName or resource references, and it does
  not produce instances of your own Resource class.
- [citizenll/godot-csv-typed-importer](https://github.com/citizenll/godot-csv-typed-importer)
  (asset 1846): 15 stars, last push 2024-03-02. A type row in the CSV with
  four types: `int`, `float`, `str`, `json`.
- Edit Resources as Table, CSV modes
  ([`spreadsheet_import.gd`](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/blob/master/addons/resources_spreadsheet_view/import_export/spreadsheet_import.gd)):
  column types are bool, int, float, string, color, object, enum and
  collection. Any property type not in its map (which includes `Vector3` and
  `StringName`) is treated as a string column. An object column is written as
  `resource_path` and read back with `load(path)`. Import creates or updates
  one `.tres` per row. The "CSV Import bug tracker" issue is open with
  unresolved items, including "On reimport, values not in the CSV get set to
  an empty" and "Importer reads datatypes from settings file, but names are
  read from the imported table"
  ([#80](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/80)).
  Using an already-written class as the import target is an open request
  ([#72](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/issues/72)).

**Inferred**: because that addon maps `Vector3` to a string column, a CSV
round trip of `pose_hip` and `pose_low` through it is likely to set a string
on a `Vector3` property. Not tested.

### Git

**Inferred** (from the file formats, not from a trial)

- CSV with one weapon per row: a single stat change rewrites one line that
  holds all 34 values, so a line diff shows which weapon changed but not
  which stat without a word-level diff. Two branches that tune different
  stats of the same weapon conflict on that line.
- CSV transposed (one stat per row, one weapon per column) gives the
  side-by-side reading the owner asked for, and a change touches one stat's
  line, but adding a weapon touches every line.
- JSON with one key per line diffs one line per stat, like `.tres`.
- Spreadsheet programs may re-quote cells or change number formatting on
  save, which adds diff noise. No source checked.

## (c) One Resource holding an array of sub-resources

**Verified**

- GDScript can export typed arrays of Resources, for example
  `@export var scenes: Array[PackedScene]`
  ([exports](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html)).
  An `Array[WeaponProfile]` on a holder Resource uses the same mechanism.
- Resources saved inside another file are written as `[sub_resource type=...
  id="..."]` sections ahead of the main `[resource]` section; resources in
  other files are `[ext_resource ...]` lines
  ([TSCN format](https://docs.godotengine.org/en/4.7/engine_details/file_formats/tscn.html)).
  So the array can hold either embedded profiles (all weapons in one file)
  or references to the existing per-weapon `.tres` files.
- The Inspector edits a sub-resource by clicking it to expand its properties
  ([Inspector dock](https://docs.godotengine.org/en/4.7/tutorials/editor/inspector_dock.html)).
  The docs describe a vertical property list per resource; they describe no
  side-by-side table of array elements.
- Field types are the engine's own here: `Vector3`, `StringName` and
  `PackedScene` are stored exactly as in today's `.tres` files.
- Edit Resources as Table can open such an array as a table through its
  `path::property` form (see (a)).

**Inferred**

- By itself this option changes where the data is stored, not how it is
  viewed: the stock Inspector still shows one weapon at a time, each as a
  collapsible block.
- Git, embedded variant: all weapons in one file, each property still on its
  own line, so a stat change is a one-line diff, but the line reads
  `damage = 2` with the weapon identified only by the enclosing
  `[sub_resource ... id="Resource_xxxxx"]` header above it. Two branches
  editing different weapons touch the same file but different hunks.
- Git, reference variant: the holder file is a short list of
  `ExtResource(...)` entries and changes only when a weapon is added or
  removed; stat diffs stay in the per-weapon files as today.
- With embedded sub-resources, code that now does
  `load("res://resources/weapons/carbine.tres")` would have to look weapons
  up in the holder instead.

## (d) Changes showing up in a running game

### What the editor does by itself

**Verified** in Godot 4.7 source and docs

- Remote scene tree: "While using Remote you can inspect or change the
  nodes' parameters in the running project"
  ([debugging tools](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/overview_of_debugging_tools.html#remote-in-scene-dock)).
  A remote edit is sent as `scene:set_object_property` and applied with
  `obj->set(...)` on the live object
  ([`scene_debugger.cpp` L747](https://github.com/godotengine/godot/blob/4.7-stable/scene/debugger/scene_debugger.cpp#L747)).
  It changes the running game only; nothing is written to the `.tres`.
- Debug > Synchronize Scene Changes: "any changes made to the scene in the
  editor will be replicated in the running project" (same docs page). In
  source this toggle is `live_debug`
  ([`debugger_editor_plugin.cpp` L88](https://github.com/godotengine/godot/blob/4.7-stable/editor/debugger/debugger_editor_plugin.cpp#L88)),
  on by default. It also covers saved Resources: when an undo-redo action
  sets a property on a Resource that has a path, the editor sends
  `scene:live_res_prop`
  ([`script_editor_debugger.cpp` L1504](https://github.com/godotengine/godot/blob/4.7-stable/editor/debugger/script_editor_debugger.cpp#L1504)),
  and the game sets that property on the cached Resource at the same path
  ([`scene_debugger.cpp` L994](https://github.com/godotengine/godot/blob/4.7-stable/scene/debugger/scene_debugger.cpp#L994)).
  Conditions in that code: live debug on, a scene open in the editor, the
  Resource has a path, and the game currently has that path in its resource
  cache. The hook is the undo-redo property callback
  ([`editor_debugger_node.cpp` L241](https://github.com/godotengine/godot/blob/4.7-stable/editor/debugger/editor_debugger_node.cpp#L241)).
- Reimported files: since Godot 4.4, when the editor reimports a file it
  tells the running game to reload it
  ([PR #98710](https://github.com/godotengine/godot/pull/98710)). The game
  calls `reload_from_file()` on each cached Resource with that path
  ([`scene_debugger.cpp` L819](https://github.com/godotengine/godot/blob/4.7-stable/scene/debugger/scene_debugger.cpp#L819)),
  which loads a fresh copy and copies it into the existing instance
  ([`resource.cpp` L263](https://github.com/godotengine/godot/blob/4.7-stable/core/io/resource.cpp#L263)).
  This path is for imported files. A plain `.tres` is not imported: when one
  changes on disk the editor reloads its own copy
  ([`editor_node.cpp` `_resources_changed`](https://github.com/godotengine/godot/blob/4.7-stable/editor/editor_node.cpp#L1291))
  but that function sends nothing to the game.
- Debug > Synchronize Script Changes reloads edited scripts in the running
  game (same docs page). It concerns code, not Resource data.
- The related proposal to live-reload nodes when their scene file is
  reimported is still open
  ([godot-proposals #9519](https://github.com/godotengine/godot-proposals/issues/9519)).

**Inferred**

- Editing a weapon `.tres` in the stock Inspector while the game runs should
  change the live weapon, because the Inspector sets properties through
  undo-redo and the Pirate holds the cached Resource. Not tested here.
- Edits made in the Edit Resources as Table grid probably do not travel that
  way: the addon registers its undo-redo step as a method call on its own
  view (`add_do_method(self, &"_update_resources", ...)` in
  [`editor_view.gd`](https://github.com/don-tnowe/godot-resources-as-sheets-plugin/blob/master/addons/resources_spreadsheet_view/editor_view.gd)),
  not as `add_do_property` on the Resource, so the property callback has
  nothing to forward. Edits the addon routes through the Inspector for
  multi-selected cells may behave differently. Not tested.
- A CSV or JSON turned into Resources by an `EditorImportPlugin` would ride
  the reimport path above: save the file, the editor reimports, the game
  reloads cached Resources at that path. This needs the editor window to
  notice the change (it rescans on focus). Not tested.

### What a script can do at runtime

**Verified**

- `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)`: cached
  resources "have their data refreshed from storage into the already
  existing instances", so every holder of the old reference sees new values.
  `CACHE_MODE_REPLACE_DEEP` does the same through external dependencies
  ([ResourceLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html#enum-resourceloader-cachemode)).
- `Resource.reload_from_file` is not bound for scripts in 4.7 (no
  `bind_method` for it in
  [`resource.cpp`](https://github.com/godotengine/godot/blob/4.7-stable/core/io/resource.cpp));
  `CACHE_MODE_REPLACE` is the scripted equivalent.
- There is no file-watcher class in the engine API. A script can poll
  `FileAccess.get_modified_time(path)`
  ([FileAccess](https://docs.godotengine.org/en/4.7/classes/class_fileaccess.html#class-fileaccess-method-get-modified-time)).
- The `changed` signal "is not emitted automatically for properties of
  custom resources. If necessary, a setter needs to be created to emit the
  signal"
  ([Resource](https://docs.godotengine.org/en/4.7/classes/class_resource.html#class-resource-signal-changed)).
- `EditorFileSystem` signals (`resources_reload`, `resources_reimported`,
  `filesystem_changed`) exist only in the editor process, not in the game
  ([EditorFileSystem](https://docs.godotengine.org/en/4.7/classes/class_editorfilesystem.html)).

**Inferred**

- Whether a reloaded value takes effect depends on how the game reads it.
  The header comment of `weapon_profile.gd` says the Pirate "reads whichever
  Profile he holds and never keeps a weapon number of his own", which suits
  in-place refresh; anything that copied a value at spawn (a timer length, an
  instantiated `model`) would keep the old one until rebuilt. The game code
  was not audited for this.
- A polling reloader would be debug-only code written for this project; no
  maintained addon for runtime Resource hot reload was found in the asset
  library or GitHub searches run for this note.
- A game launched from the editor reads `res://` straight from the project
  folder, so a polled `.tres`, CSV or JSON is the file being edited. In an
  exported build the data is packed and this does not apply.

## Side by side

| | Maintenance | Godot 4.7 | Vector3 | StringName | PackedScene | Git diff of one stat change |
|---|---|---|---|---|---|---|
| Edit Resources as Table over existing `.tres` | Active, master pushed 2026-10-31; no tagged releases | Fix merged on master 2026-10-31; asset-library build is older | Text cell with the `Vector3(...)` literal (inferred) | String cell, saved as `StringName` | Preview cell, changed via Inspector | One line in that weapon's `.tres`; `saved_state.json` noise |
| Godot Resource Manager | One release, last push 2025-12 | Not stated | Listed as editable | Listed as editable | `Resource` listed as editable | One line in that weapon's `.tres` |
| Pandora | Alpha, last release 2026-07 | Not stated | Own property type | Not listed | Own resource property type | Its own `data.pandora` file |
| CSV, hand-written loader or import plugin | Project-owned code | Engine API, stable | Three columns or one literal cell | Plain string, cast on load | Path string, not updated on rename (inferred) | Whole weapon row, or one stat row if transposed |
| JSON, hand-written loader | Project-owned code | Engine API, stable | Array or `from_native` dictionary | Plain string, or `"sn:..."` | Path string | One line per stat if one key per line |
| One Resource with `Array[WeaponProfile]` | Engine feature | Yes | Native | Native | Native | One line; weapon identified by sub-resource header |

Live-update routes, independent of the storage choice:

| Route | Writes to disk | Needs project code | Status |
|---|---|---|---|
| Remote tree / remote inspector edit | No | No | Documented |
| Inspector edit of a saved `.tres` with Synchronize Scene Changes on | On save | No | Read in source, not tested |
| Reimport of an imported data file (4.4+) | Yes | An import plugin | Read in source, not tested |
| Script reload with `CACHE_MODE_REPLACE`, triggered by key or by polling modified time | Yes | A small debug reloader | API documented, not tested |

## Open questions this note could not settle

- Whether Edit Resources as Table at master runs cleanly on 4.7.2 with a
  34-column Resource, and how wide that table is to use in practice.
- Whether its grid edits reach a running game (the inference above says
  probably not).
- Whether any game code caches `WeaponProfile` values in a way that defeats
  in-place reload.
- Whether Godot Resource Manager works on 4.7 at all.
