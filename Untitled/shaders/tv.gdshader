shader_type spatial;
render_mode unshaded, cull_back;

// 0 off, 1 static, 2 rolling distorted picture, 3 blue no-signal, 4 broadcast
uniform int mode = 0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float vign = 1.0 - dot(c, c) * 1.6;
	vec3 col = vec3(0.02, 0.025, 0.025);
	float t = TIME;
	if (mode == 1) {
		float n = hash(floor(uv * vec2(160.0, 120.0)) + floor(t * 30.0));
		float band = 0.85 + 0.15 * sin(uv.y * 40.0 + t * 8.0);
		col = vec3(n) * band * 0.9;
	} else if (mode == 2) {
		float roll = fract(uv.y + t * 0.37);
		float wob = sin(roll * 50.0 + t * 9.0) * 0.02 + (hash(vec2(floor(roll * 90.0), floor(t * 20.0))) - 0.5) * 0.06;
		float x = uv.x + wob;
		vec3 bars[7] = vec3[](vec3(0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75), vec3(0.0, 0.75, 0.0), vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
		int idx = clamp(int(fract(x) * 7.0), 0, 6);
		col = bars[idx] * 0.7;
		col += vec3(hash(uv * 300.0 + t)) * 0.35;
		col *= smoothstep(0.0, 0.08, roll) * 0.9 + 0.1;
	} else if (mode == 3) {
		col = vec3(0.08, 0.14, 0.55) + vec3(hash(uv * 200.0 + t) * 0.03);
	} else if (mode == 4) {
		// soft, unreadable broadcast: drifting shapes, a figure-ish blob, interlace
		float n1 = noise(uv * 3.0 + vec2(t * 0.05, 0.0));
		float n2 = noise(uv * 6.0 - vec2(0.0, t * 0.08));
		col = mix(vec3(0.18, 0.15, 0.12), vec3(0.55, 0.45, 0.35), n1);
		float fig = smoothstep(0.22, 0.12, length((uv - vec2(0.45 + sin(t * 0.3) * 0.05, 0.6)) * vec2(1.4, 0.8)));
		col = mix(col, vec3(0.12, 0.1, 0.12), fig * 0.7);
		col += (n2 - 0.5) * 0.1;
		col += vec3(hash(uv * 400.0 + t)) * 0.06;
		col *= 0.9 + 0.1 * sin(uv.y * 480.0);
	}
	if (mode == 0) {
		ALBEDO = vec3(0.025, 0.03, 0.03);
		ROUGHNESS = 0.1;
		SPECULAR = 0.4;
	} else {
		ALBEDO = col * max(vign, 0.0);
		EMISSION = col * max(vign, 0.0) * 1.6;
	}
}
