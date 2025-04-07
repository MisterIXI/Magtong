shader_type canvas_item;

uniform sampler2D base_texture: repeat_enable; // Noise texture to be used
uniform sampler2D noise_texture: repeat_enable; // Noise texture to be used
uniform sampler2D gradient;
uniform vec2 scroll_speed; // Scrolling speed

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Calculate the scrolling offset
	vec2 offset = UV * 5.0 + TIME * scroll_speed;
	vec2 offset2 = UV * 2.5 + (TIME + 1.3)* (scroll_speed*vec2(-1.0,0.9));
	vec2 offset3 = UV + (TIME + 1.3)* (scroll_speed*vec2(-0.3,0.5));

	// Sample the noise texture with the offset
	vec4 noise_color = texture(noise_texture, offset);
	vec4 color2 = texture(noise_texture,offset2);
	vec4 color3 = texture(base_texture,offset3);
	vec4 tex = noise_color * color2 * color3;
	tex = tex * texture(gradient, UV);
	// Set the fragment color based on the noise texture
	COLOR = tex;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
