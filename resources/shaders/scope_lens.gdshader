// A Sight's glass: a scope's rear glass, or the Reflex Sight's window
// (`scripts/scoped_view.gd`). A scope's lens shows the lens camera's
// picture, sampled by where each pixel is on screen rather than by the glass's
// own UVs, so the picture stays put and the glass moves over it. The reticle
// is drawn the same way at the middle of the screen, the shot line, so it is
// seen only through the glass and the gun sways around it.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

// The Viewmodel's wall-clipping flags (`Viewmodel._flag_materials`), which a
// ShaderMaterial does not take: its own field of view and depth scale.
uniform float fov_override = 50.0;
uniform float z_clip_scale = 0.35;
// The lens camera's picture, and how many of the screen's half-heights it
// covers either side of the middle.
uniform sampler2D picture : source_color, filter_linear, repeat_disable;
uniform bool magnifies = false;
uniform float picture_span = 1.15;
// 0 a dot, 1 a cross.
uniform int reticle = 1;
uniform vec3 reticle_colour : source_color = vec3(1.0, 0.12, 0.08);
// How much the glass tints what is behind it when it shows no picture.
uniform float glass = 0.10;
// A round lens darkens toward its rim: its middle and radius in the mesh's
// own space. No rim with a radius of 0.
uniform vec2 glass_centre = vec2(0.0);
uniform float glass_radius = 0.0;

varying vec2 from_centre;

void vertex() {
	from_centre = VERTEX.xy - glass_centre;
	float f = 1.0 / tan(radians(fov_override) * 0.5);
	float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
	PROJECTION_MATRIX[1][1] = sign(PROJECTION_MATRIX[1][1]) * f;
	PROJECTION_MATRIX[0][0] = sign(PROJECTION_MATRIX[0][0]) * f / aspect;
	Z_CLIP_SCALE = z_clip_scale;
}

// How much of the reticle covers a pixel [param px] pixels from the middle.
float mark(vec2 px) {
	if (reticle == 0) {
		return 1.0 - smoothstep(2.5, 4.0, length(px));
	}
	float gap = step(7.0, max(abs(px.x), abs(px.y)));
	float line = (1.0 - smoothstep(0.8, 1.8, min(abs(px.x), abs(px.y)))) * gap;
	return max(line, 1.0 - smoothstep(1.2, 2.2, length(px)));
}

void fragment() {
	// Where this pixel is from the middle of the screen, in half-heights.
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	p.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec3 colour = vec3(0.03, 0.05, 0.06);
	float alpha = glass;
	if (magnifies) {
		vec2 uv = 0.5 + p * 0.5 / picture_span;
		colour = texture(picture, uv).rgb;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			colour = vec3(0.0);
		}
		alpha = 1.0;
	}
	if (glass_radius > 0.0) {
		colour *= 1.0 - smoothstep(0.8, 1.0, length(from_centre) / glass_radius);
	}
	float m = mark(p * VIEWPORT_SIZE.y * 0.5);
	ALBEDO = mix(colour, reticle_colour, m);
	ALPHA = max(alpha, m);
}
