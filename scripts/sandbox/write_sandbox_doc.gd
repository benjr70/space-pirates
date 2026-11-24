extends SceneTree
## Rewrites `docs/sandbox.md` from the resources on disk, the same way the
## in-Raid sheet's Save does. Run after editing a weapon or the Sandbox in
## the Inspector, or the test suite's stale check fails:
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://scripts/sandbox/write_sandbox_doc.gd


func _initialize() -> void:
	var err := SandboxSheet.from_disk().write_doc()
	if err != OK:
		printerr("could not write %s: %s" % [SandboxSheet.DOC_PATH, error_string(err)])
	else:
		print("wrote %s" % SandboxSheet.DOC_PATH)
	quit(0 if err == OK else 1)
