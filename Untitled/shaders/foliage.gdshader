shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.55, 0.62, 0.45);
uniform float sway = 0.06;
uniform float cut = 0.3;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = sin(wp.x * 1.7 + wp.z * 1.3 + TIME * 0.9) * 0.5 + sin(wp.x * 3.1 - TIME * 1.7 + wp.y) * 0.3;
	VERTEX += NORMAL * (hash(floor(VERTEX * 6.0)) - 0.5) * 0.25;
	VERTEX.x += n * sway * (VERTEX.y + 1.0);
	VERTEX.z += n * sway * 0.6 * (VERTEX.y + 1.0);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = wp.xz * 0.6 + wp.y * 0.35;
	vec3 t1 = texture(leaf_tex, uv * 2.0).rgb;
	float l1 = clamp((t1.g - 0.12) / 0.24, 0.0, 1.0);
	float l2 = clamp((texture(leaf_tex, uv * 5.3 + 0.31).g - 0.12) / 0.24, 0.0, 1.0);
	float leaf = l1 * 0.6 + l2 * 0.4;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = tint * t1 * 2.0;
	ROUGHNESS = 0.9;
	ALPHA = step(cut, leaf * 0.65 + facing * 0.75 - 0.25);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	BACKLIGHT = vec3(0.12, 0.16, 0.08);
}
