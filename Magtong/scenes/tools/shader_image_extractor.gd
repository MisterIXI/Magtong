extends Node2D

@onready var subvp: SubViewport = get_node("SubViewport")

# func _ready():
# 	await get_tree().create_timer(0.5).timeout
# 	var tex = subvp.get_texture()
# 	await RenderingServer.frame_post_draw
# 	var img = tex.get_image()
# 	var image_tex = ImageTexture.create_from_image(img)
# 	var path = "res://cool_img.tres"

# 	ResourceSaver.save(image_tex, path)
# 	img.save_png("res://cool_png.png")
# 	# quit
# 	get_tree().quit()
# 	pass