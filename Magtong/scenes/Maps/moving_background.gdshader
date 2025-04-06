shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable; // Noise texture to be used
uniform vec2 scroll_speed; // Scrolling speed

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Calculate the scrolling offset
	vec2 offset = UV + TIME * scroll_speed;

	// Sample the noise texture with the offset
	vec4 noise_color = texture(noise_texture, offset);
	vec4 test_color = texture(noise_texture, UV + vec2(0.1));
	// Set the fragment color based on the noise texture
	COLOR = noise_color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
