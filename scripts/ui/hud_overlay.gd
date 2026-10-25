extends Control
## Drawn HUD overlay. Kept separate so UI drawing does not depend on a scene hierarchy.

var hud: Variant
const HITMARKER_DURATION: float = 0.45

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var white := Color(0.92, 0.96, 1.0, 0.95)
    var accent := Color(0.18, 0.82, 1.0, 1.0)
    # A small outlined crosshair stays readable over both bright and dark surfaces.
    for offset in [Vector2(-11, 0), Vector2(7, 0)]:
        draw_line(center + offset, center + offset + Vector2(4, 0), Color(0.02, 0.04, 0.08, 0.9), 4.0, true)
        draw_line(center + offset, center + offset + Vector2(4, 0), white, 2.0, true)
    for offset in [Vector2(0, -11), Vector2(0, 7)]:
        draw_line(center + offset, center + offset + Vector2(0, 4), Color(0.02, 0.04, 0.08, 0.9), 4.0, true)
        draw_line(center + offset, center + offset + Vector2(0, 4), white, 2.0, true)
    draw_circle(center, 1.5, accent)

    if hud != null and float(hud.hitmarker_time) > 0.0:
        var progress: float = clampf(float(hud.hitmarker_time) / HITMARKER_DURATION, 0.0, 1.0)
        var hit_color: Color = Color(1.0, 0.36, 0.34, progress)
        if bool(hud.last_hit_killed):
            hit_color = Color(0.25, 1.0, 0.72, progress)
        var arm := 9.0
        var inner := 4.0
        for sign_x in [-1.0, 1.0]:
            for sign_y in [-1.0, 1.0]:
                draw_line(center + Vector2(sign_x * inner, sign_y * inner), center + Vector2(sign_x * arm, sign_y * arm), hit_color, 2.0, true)

    var local_player: Node = get_tree().get_first_node_in_group("local_player")
    var bottom_y: float = size.y - 34.0
    var panel := Rect2(Vector2(26.0, bottom_y - 30.0), Vector2(270.0, 38.0))
    draw_rect(panel, Color(0.025, 0.04, 0.07, 0.84), true)
    draw_rect(Rect2(panel.position, Vector2(3.0, panel.size.y)), accent, true)
    if local_player != null:
        var hp: float = clampf(float(local_player.hp) / 100.0, 0.0, 1.0)
        var hp_color := Color(0.24, 0.92, 0.64, 1.0).lerp(Color(1.0, 0.3, 0.28, 1.0), 1.0 - hp)
        draw_string(ThemeDB.fallback_font, Vector2(40.0, bottom_y - 6.0), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.65, 0.74, 0.86, 1.0))
        draw_string(ThemeDB.fallback_font, Vector2(76.0, bottom_y - 6.0), str(roundi(float(local_player.hp))), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
        draw_rect(Rect2(Vector2(126.0, bottom_y - 17.0), Vector2(150.0, 8.0)), Color(0.12, 0.16, 0.22, 1.0), true)
        draw_rect(Rect2(Vector2(126.0, bottom_y - 17.0), Vector2(150.0 * hp, 8.0)), hp_color, true)
        if not bool(local_player.alive):
            draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 70.0, center.y + 64.0), "RESPAWNING…", HORIZONTAL_ALIGNMENT_CENTER, 140.0, 18, Color(1.0, 0.54, 0.46, 1.0))
    var alive_count := 0
    for player in get_tree().get_nodes_in_group("players"):
        if player.alive:
            alive_count += 1
    draw_string(ThemeDB.fallback_font, Vector2(size.x - 24.0, 32.0), "ARENA  /  %02d PLAYERS" % alive_count, HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 13, Color(0.65, 0.82, 0.95, 0.95))
    if local_player != null:
        var view_label: String = "VIEW: THIRD PERSON" if bool(local_player.get("is_third_person")) else "VIEW: FIRST PERSON"
        draw_string(ThemeDB.fallback_font, Vector2(size.x - 24.0, 54.0), view_label, HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 12, Color(0.18, 0.82, 1.0, 0.95))
    draw_string(ThemeDB.fallback_font, Vector2(28.0, 34.0), "WASD MOVE   SPACE JUMP   LMB FIRE   V VIEW   INS SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.55, 0.65, 0.76, 0.9))
