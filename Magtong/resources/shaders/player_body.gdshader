shader_type canvas_item;
uniform vec2 center;
uniform vec4 pos_col : source_color;
uniform vec4 neg_col : source_color;
uniform float polarity: hint_range(-1.0, 1.0);
uniform float ripple: hint_range(0.0, 1.0);
uniform float force;
uniform float size;
uniform float thickness;
// Surge: the distortion ring is tinted in the magnet's color, tint fades out with the ring (0 = none)
uniform vec4 ripple_col : source_color;
uniform float ripple_tint;
uniform float ripple_band = 0.04;
uniform float wiggle = 0.0; // wobble of the ring's radius, as a share of its size (0 = round)
uniform float wiggle_phase = 0.0;
uniform float wiggle_speed = 6.0;

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
	vec2 to_px = scaledUV - center;
	// wiggle: the ring's radius wobbles around the circle (whole-number frequencies, so no seam at the back)
	// and the wobble moves over time; it grows with the ring, so it starts round
	float angle = atan(to_px.y, to_px.x);
	float t = wiggle_phase + TIME * wiggle_speed;
	float wobble = 0.5 * sin(5.0 * angle + t) + 0.3 * sin(8.0 * angle - 1.7 * t + 2.0)
			+ 0.2 * sin(13.0 * angle + 2.3 * t + 4.0);
	float r = length(to_px) - wobble * wiggle * size;
	float mask = (1.0 - smoothstep(size-0.1, size, r)) *
			smoothstep(size-0.1- thickness, size-thickness, r);
	vec2 disp = normalize(to_px) * force * mask;
	// the color gets its own soft band around the ring, so it shows even when the distortion is thin
	float band = 1.0 - smoothstep(0.0, ripple_band, abs(r - (size - 0.05)));
	// blended toward the color, not added: added red on the green rink turns yellow
	vec4 screen = textureLod(screen_texture, SCREEN_UV - disp, 0.0);
	screen.rgb = mix(screen.rgb, ripple_col.rgb, clamp(band * ripple_tint, 0.0, 1.0));
	COLOR = screen + add_col;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
