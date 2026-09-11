extends Object
class_name UITheme

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()

	var base_color := Color(0.1, 0.12, 0.2)
	var accent := Color(0.4, 0.7, 1.0)
	var text_color := Color(0.9, 0.92, 1.0)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.border_color = Color(0.25, 0.3, 0.45)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8

	var style_hover := style_normal.duplicate()
	style_hover.bg_color = base_color.lightened(0.15)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = accent.darkened(0.3)

	var style_focus := StyleBoxFlat.new()
	style_focus.bg_color = base_color.lightened(0.25)
	style_focus.border_color = accent
	style_focus.set_border_width_all(1)
	style_focus.set_corner_radius_all(6)

	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = Color(0.15, 0.15, 0.2)
	style_disabled.border_color = Color(0.2, 0.2, 0.3)

	_theme.default_font_size = 18

	_theme.set_stylebox("normal", "Button", style_normal)
	_theme.set_stylebox("hover", "Button", style_hover)
	_theme.set_stylebox("pressed", "Button", style_pressed)
	_theme.set_stylebox("focus", "Button", style_focus)
	_theme.set_stylebox("disabled", "Button", style_disabled)
	_theme.set_color("font_color", "Button", text_color)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.6))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.09, 0.15, 0.92)
	panel_style.border_color = Color(0.3, 0.35, 0.5, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	_theme.set_stylebox("panel", "PanelContainer", panel_style)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.05, 0.06, 0.11)
	input_style.border_color = Color(0.3, 0.35, 0.5)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(6)
	_theme.set_stylebox("normal", "LineEdit", input_style)
	_theme.set_stylebox("focus", "LineEdit", input_style)

	return _theme

static func title_label(text: String, font_size: int = 42) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	return label

static func subtitle_label(text: String, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

static func make_button(text: String, size: Vector2 = Vector2(280, 48), font_size: int = 20) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", font_size)
	return button