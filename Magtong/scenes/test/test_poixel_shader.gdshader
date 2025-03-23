shader_type canvas_item;
render_mode unshaded;
uniform float pixel_size;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {

    vec2 uv = SCREEN_UV;
    uv = floor(uv * pixel_size) / pixel_size;
    COLOR = texture(SCREEN_TEXTURE, uv);
}
