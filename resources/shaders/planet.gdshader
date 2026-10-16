shader_type spatial;
render_mode unshaded;
// The main menu's planet: noise oceans and land under drifting cloud, lit
// from `sun_dir` with a soft terminator and a blue atmosphere on the limb.

uniform vec3 sun_dir = vec3(-0.5, -0.5, 0.7);
uniform vec3 ocean : source_color = vec3(0.03, 0.09, 0.2);
uniform vec3 land : source_color = vec3(0.18, 0.2, 0.14);
uniform vec3 atmosphere : source_color = vec3(0.3, 0.55, 1.0);

varying vec3 local_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_pos = normalize(VERTEX);
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float lit = smoothstep(-0.15, 0.35, dot(n, -normalize(sun_dir)));
	float h = fbm(local_pos * 3.0);
	vec3 surface = mix(ocean, land, smoothstep(0.5, 0.56, h));
	float cloud = smoothstep(0.5, 0.75, fbm(local_pos * 5.0 + vec3(TIME * 0.003, 0.0, 0.0)));
	surface = mix(surface, vec3(0.75, 0.8, 0.85), cloud * 0.8);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = surface * lit * 1.4 + atmosphere * rim * (lit * 1.8 + 0.05);
	ALBEDO = col;
}
