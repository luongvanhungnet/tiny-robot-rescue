extends RefCounted

const FONT = preload("res://assets/fonts/Nunito.ttf")
const INK: = Color("493b60")
const MUTED: = Color("746782")
const BACKGROUND: = Color("f8f5ff")
const PAPER: = Color("fffdfd")
const PURPLE: = Color("7357a3")
const ROSE: = Color("b8526e")
const MINT: = Color("367d70")
const PASTELS: = [Color("f4a8b4"), Color("accbed"), Color("a7d7c4"), Color("f3d38b")]
const MARKS: = [Color("99405b"), Color("3d6294"), Color("276a59"), Color("805d20")]
static var _bold: FontVariation
static var _regular: FontVariation

static func regular_font() -> Font:
	if _regular == null:
		_regular = FontVariation.new()
		_regular.base_font = FONT
		_regular.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	return _regular

static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = FONT
		_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800.0}
	return _bold

static func box(color: Color, radius: = 26, border: = Color.TRANSPARENT, shadow: = false) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	if border.a > 0:
		style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	if shadow:
		style.shadow_color = Color(0.39, 0.27, 0.53, 0.1)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 5)
	return style
