class_name UIThemeHelper
extends RefCounted

static func make_box(bg: Color, border: Color, radius: int = 14, bottom_extra: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2 + bottom_extra
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0 + float(bottom_extra) * 0.5
	return s

static func style_button(btn: Button, bg: Color, border: Color, font_col: Color = Color.WHITE) -> void:
	btn.add_theme_stylebox_override("normal", make_box(bg, border, 14, 4))
	btn.add_theme_stylebox_override("hover", make_box(bg.lightened(0.08), border, 14, 4))
	btn.add_theme_stylebox_override("pressed", make_box(bg.darkened(0.12), border, 14, 1))
	btn.add_theme_stylebox_override("disabled", make_box(Color("#334155", 0.6), Color("#1e293b", 0.6), 14, 2))
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col)
	btn.add_theme_color_override("font_pressed_color", font_col)
	btn.add_theme_color_override("font_disabled_color", Color("#94a3b8"))
