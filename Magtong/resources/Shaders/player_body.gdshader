shader_type canvas_item;
uniform vec2 center;
uniform vec4 pos_col : source_color;
uniform vec4 neg_col : source_color;
uniform float polarity: hint_range(-1.0, 1.0);
uniform float ripple: hint_range(0.0, 1.0);
uniform float force;
uniform float size;
uniform float thickness;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	float dist = distance(UV, center) * 2.0;
	dist = 1.0 - min(1, max(dist, 0.0));
	vec4 add_col = pos_col * max(0.0, polarity) + neg_col * max(0.0, -polarity);
	add_col *= dist;
	vec4 col = textureLod(screen_texture, SCREEN_UV, 0.0);
	//COLOR = mix(add_col, col, dist);
	//add_col *= dist;
	//add_col *= strength;

	//// distortion
	float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
	vec2 scaledUV = UV; //(UV - vec2(0.5, 0.0)) / vec2(ratio, 1.0) + vec2(0.5, 0.0);
	float mask = (1.0 - smoothstep(size-0.1, size, length(scaledUV - center))) *
			smoothstep(size-0.1- thickness, size-thickness, length(scaledUV - center));
	vec2 disp = normalize(scaledUV - center) * force * mask;
	COLOR = textureLod(screen_texture, SCREEN_UV - disp, 0.0) + add_col;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
