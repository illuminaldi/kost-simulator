@tool
extends EditorPlugin
## Game dikunci portrait, sehingga Google Play menganggap "android.hardware.screen.portrait"
## wajib dan menyembunyikan game dari tablet/Chromebook/PC. Fitur itu ditandai opsional di sini.

var _exp: _CozyExport


func _enter_tree() -> void:
	_exp = _CozyExport.new()
	add_export_plugin(_exp)


func _exit_tree() -> void:
	remove_export_plugin(_exp)
	_exp = null


class _CozyExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "CozyAndroidManifest"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '    <uses-feature tools:node="replace" android:name="android.hardware.screen.portrait" android:required="false" />\n'
