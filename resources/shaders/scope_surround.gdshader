// Everything outside a scope's lens out of focus and going black toward the
// screen's edge: the eye is on the glass, not on the room
// (`scripts/scoped_view.gd`). A full-screen layer under the HUD reading the
// screen's mipmaps for the blur, masked by where the lens is on screen.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
// Where the lens is on screen, from the middle, in half-heights.
uniform vec2 lens_centre = vec2(0.0);
uniform float lens_radius = 0.3;
// The screen mipmap level read outside the lens.
uniform float blur = 2.0;
// How dark it goes toward the screen's edge: 1 is black at the corners.
uniform float edge = 1.0;
// How far up the sights are: 0 nothing, 1 all of it.
uniform float amount = 0.0;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	p.x *= size.x / size.y;
	float from_lens = length(p - lens_centre);
	float outside = smoothstep(lens_radius * 0.97, lens_radius * 1.04, from_lens) * amount;
	vec3 soft = textureLod(screen, SCREEN_UV, blur).rgb;
	// Black from a little outside the lens out to the corners.
	float reach = length(vec2(size.x / size.y, 1.0));
	float dark = smoothstep(lens_radius * 1.3, reach, from_lens) * edge;
	dark = max(dark, smoothstep(reach * 0.75, reach, from_lens) * step(0.01, edge));
	COLOR = vec4(soft * (1.0 - dark), outside);
}
