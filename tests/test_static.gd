extends SceneTree
## Headless static check: every script, scene and resource in the project
## loads, so a file no behaviour suite touches cannot break silently. Walks
## res:// and load()s each .gd, .tscn and .tres; a null result, a script that
## did not compile, or a dependency that does not exist fails with its path.
## Each scene is instantiated once (not added to the tree) and freed.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_static.gd
##
## Skipped directories, each with its reason:
## - addons/: third-party packs, not our code.
## - .godot/: Godot's own import cache.
## - tools/: Blender build scripts (Python) behind a .gdignore.
## - any hidden directory (.claude/, .scratch/, .git/): not project content;
##   Godot's own filesystem never scans them either, and agent worktrees under
##   .claude/ hold whole copies of the project.
## No other file or directory is excluded.

const SKIP_DIRS := ["res://addons", "res://.godot", "res://tools"]
const EXTENSIONS := ["gd", "tscn", "tres"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var files: Array[String] = []
	_walk("res://", files)
	files.sort()
	for path in files:
		_check(path)
	_report()
	quit(1 if failures.size() > 0 else 0)


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		failures.append("%s: cannot open directory" % dir_path)
		return
	dir.include_hidden = false
	for sub in dir.get_directories():
		var sub_path := dir_path.path_join(sub)
		if sub_path in SKIP_DIRS or FileAccess.file_exists(sub_path.path_join(".gdignore")):
			continue
		_walk(sub_path, out)
	for file in dir.get_files():
		if file.get_extension() in EXTENSIONS:
			out.append(dir_path.path_join(file))


func _check(path: String) -> void:
	checks += 1
	for dep in ResourceLoader.get_dependencies(path):
		var dep_path := _dependency_path(dep)
		if not ResourceLoader.exists(dep_path):
			failures.append("%s: missing dependency %s" % [path, dep_path])
			return
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if res == null:
		failures.append("%s: failed to load" % path)
		return
	if res is GDScript:
		if not (res as GDScript).can_instantiate():
			failures.append("%s: script did not compile" % path)
		return
	if res is PackedScene:
		var scene := res as PackedScene
		if not scene.can_instantiate():
			failures.append("%s: scene cannot be instantiated" % path)
			return
		var node := scene.instantiate()
		if node == null:
			failures.append("%s: scene instantiated to null" % path)
			return
		node.free()


## get_dependencies() gives "uid://...::Type::res://path" or a bare path;
## the last field is the path, which may itself be a uid.
func _dependency_path(dep: String) -> String:
	var path := dep.get_slice("::", dep.get_slice_count("::") - 1)
	if path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(path)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return path


func _report() -> void:
	for f in failures:
		print("FAIL  ", f)
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		print("FAILED  %d of %d checks" % [failures.size(), checks])
