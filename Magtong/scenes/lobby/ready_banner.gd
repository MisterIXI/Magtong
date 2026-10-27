extends Control
class_name ReadyBanner
@export var upper_banner: PanelContainer
@export var lower_banner: PanelContainer
var tween: Tween
@export var curve_i: Curve
func on_all_ready_changed(is_ready: bool) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	if is_ready:
		tween = create_tween()
		tween.tween_callback(upper_banner.set_deferred.bind("visible", true))
		tween.tween_callback(lower_banner.set_deferred.bind("visible", true))
		tween.tween_property(upper_banner, "position:x", 0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.parallel()
		tween.tween_property(lower_banner, "position:x", 0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.play()
	else:
		tween = create_tween()
		tween.tween_property(upper_banner, "position:x", upper_banner.size.x, 0.3)
		tween.parallel()
		tween.tween_property(lower_banner, "position:x", -lower_banner.size.x, 0.3)
		tween.tween_callback(upper_banner.set_deferred.bind("visible", false))
		tween.tween_callback(lower_banner.set_deferred.bind("visible", false))
		tween.play()
