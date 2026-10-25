extends Node
## JSON config store in user://configs/ with safe filenames.

const CONFIGS_DIR: String = "user://configs/"

func _ready() -> void:
    _ensure_directory()

func _ensure_directory() -> bool:
    var absolute_path: String = ProjectSettings.globalize_path(CONFIGS_DIR)
    var err: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
    return err == OK or DirAccess.dir_exists_absolute(absolute_path)

func _safe_config_name(value: String) -> String:
    var cleaned := value.strip_edges()
    var regex := RegEx.new()
    regex.compile("[^A-Za-z0-9_-]")
    cleaned = regex.sub(cleaned, "", true)
    return cleaned.substr(0, 40) if not cleaned.is_empty() else "default"

func save_config(name: String) -> bool:
    if not _ensure_directory():
        push_error("Не удалось создать папку конфигов")
        return false
    var path: String = CONFIGS_DIR + _safe_config_name(name) + ".json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Не удалось создать конфиг: " + path)
        return false
    file.store_line(JSON.stringify(CheatRegistry.to_dict(), "\t"))
    file.close()
    return true

func load_config(name: String, player: Node = null) -> bool:
    var path: String = CONFIGS_DIR + _safe_config_name(name) + ".json"
    if not FileAccess.file_exists(path):
        push_error("Конфиг не найден: " + path)
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Не удалось прочитать конфиг: " + path)
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        push_error("Неверный формат конфигурации")
        return false
    CheatRegistry.from_dict(parsed, player)
    return true

func list_configs() -> Array[String]:
    var result: Array[String] = []
    if not _ensure_directory():
        return result
    var dir := DirAccess.open(CONFIGS_DIR)
    if dir == null:
        return result
    dir.list_dir_begin()
    var filename := dir.get_next()
    while filename != "":
        if not dir.current_is_dir() and filename.ends_with(".json"):
            result.append(filename.get_basename())
        filename = dir.get_next()
    dir.list_dir_end()
    result.sort()
    return result
