shader_type sky;

// Late dusk / early night: deep navy overhead, a faint purple and amber afterglow
// low in one direction, sparse stars, thin clouds lit from below, a moon.
uniform vec3 zenith : source_color = vec3(0.02, 0.025, 0.06);
uniform vec3 mid : source_color = vec3(0.09, 0.06, 0.14);
uniform vec3 horizon : source_color = vec3(0.32, 0.16, 0.18);
uniform vec3 glow_col : source_color = vec3(0.65, 0.3, 0.16);
uniform vec3 glow_dir = vec3(-0.6, 0.0, 0.8);
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 moon_dir = vec3(0.4, 0.45, -0.8);
uniform float star_amount = 1.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h > 0.0) {
		col = mix(horizon, mid, smoothstep(0.0, 0.18, h));
		col = mix(col, zenith, smoothstep(0.12, 0.65, h));
	} else {
		col = mix(horizon * 0.35, vec3(0.01, 0.01, 0.015), smoothstep(0.0, -0.15, h));
	}
	vec3 gd = normalize(glow_dir);
	float g = max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(gd.x, 0.0, gd.z))), 0.0);
	float band = exp(-max(h, 0.0) * 9.0) * step(-0.02, h);
	col += glow_col * pow(g, 3.0) * band * 0.55;
	if (!AT_CUBEMAP_PASS && h > 0.02) {
		// clouds projected on a dome
		vec2 cuv = d.xz / (h + 0.18) * 0.18;
		float c = texture(cloud_tex, cuv).r;
		float c2 = texture(cloud_tex, cuv * 2.3 + 0.37).r;
		float cloud = smoothstep(0.5, 0.78, c * 0.7 + c2 * 0.4);
		vec3 lit = mix(vec3(0.12, 0.08, 0.13), vec3(0.5, 0.26, 0.24), pow(g, 2.0) * exp(-h * 3.0));
		// stars
		vec3 sp = floor(d * 380.0);
		float s = hash(sp);
		float star = step(0.9985, s) * smoothstep(0.08, 0.4, h) * star_amount;
		star *= 0.4 + 0.6 * fract(s * 7919.0);
		col += vec3(star) * (1.0 - cloud) * 0.9;
		col = mix(col, lit, cloud * 0.75 * smoothstep(0.02, 0.12, h));
	}
	// moon
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	col += vec3(0.9, 0.92, 1.0) * smoothstep(0.99955, 0.9997, m) * 1.6;
	col += vec3(0.25, 0.27, 0.35) * pow(max(m, 0.0), 300.0) * 0.5;
	COLOR = col;
}
