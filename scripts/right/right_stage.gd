extends Node2D

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const BackgroundCarouselScene = preload("res://scripts/right/background_carousel.gd")
const LanternManagerScene = preload("res://scripts/right/lantern_manager.gd")

var _background_carousel: BackgroundCarousel
var _lantern_manager: LanternManager


func configure(right_config: Dictionary, stage_size: Vector2i) -> void:
	if _background_carousel == null:
		_build_scene()
	_background_carousel.configure(ConfigLoader.dictionary_from(right_config.get("background_carousel", {})), stage_size)
	_lantern_manager.configure(ConfigLoader.dictionary_from(right_config.get("lanterns", {})), stage_size)


func add_user_lantern(texture: Texture2D) -> void:
	_lantern_manager.add_user_lantern(texture)


func _build_scene() -> void:
	_background_carousel = BackgroundCarouselScene.new()
	add_child(_background_carousel)
	_lantern_manager = LanternManagerScene.new()
	add_child(_lantern_manager)