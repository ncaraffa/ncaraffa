shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_tex : source_color, filter_linear;
uniform float power = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	// barrel distortion
	uv = 0.5 + c * (1.0 + dot(c, c) * 0.12);
	vec3 col = texture(screen_tex, uv).rgb;
	// a hint of chromatic bleed
	col.r = texture(screen_tex, uv + vec2(0.0012, 0.0)).r;
	float scan = 0.82 + 0.18 * sin(uv.y * 480.0 * 3.14159);
	float vign = smoothstep(0.75, 0.25, length(c * vec2(1.0, 1.15)));
	float flick = 0.97 + 0.03 * sin(TIME * 60.0);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) col = vec3(0.0);
	col *= scan * vign * flick * power;
	vec3 glass = vec3(0.03, 0.035, 0.035);
	ALBEDO = col + glass;
	EMISSION = col * 1.8;
}
