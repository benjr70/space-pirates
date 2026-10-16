shader_type sky;
// Deep space for the main menu: three layers of hashed stars over two
// colours of drifting nebula, bright enough that the brightest stars bloom.

uniform vec3 nebula_a : source_color = vec3(0.32, 0.08, 0.38);
uniform vec3 nebula_b : source_color = vec3(0.04, 0.16, 0.4);
uniform float star_energy = 3.0;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float stars(vec3 dir, float scale, float threshold) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h < threshold) {
		return 0.0;
	}
	vec3 jitter = vec3(hash(cell + 11.0), hash(cell + 23.0), hash(cell + 37.0)) - 0.5;
	float d = length(fract(p) - 0.5 - jitter * 0.6);
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.1, 0.0, d) * (h - threshold) / (1.0 - threshold) * twinkle;
}

void sky() {
	vec3 d = EYEDIR;
	float n = fbm(d * 2.2 + vec3(0.0, 0.0, TIME * 0.004));
	float m = fbm(d * 4.0 + vec3(7.0, 3.0, 1.0));
	vec3 col = vec3(0.004, 0.005, 0.01);
	col += nebula_a * pow(n, 3.0) * 1.6;
	col += nebula_b * pow(m, 3.0) * 1.4;
	float s = stars(d, 400.0, 0.965) * 0.6 + stars(d, 180.0, 0.985) + stars(d, 90.0, 0.993) * 1.6;
	col += vec3(0.9, 0.95, 1.0) * s * star_energy;
	COLOR = col;
}
