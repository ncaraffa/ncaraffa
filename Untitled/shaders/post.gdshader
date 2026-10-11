shader_type canvas_item;
// Subtle film grain + vignette, with an optional discreet VHS treatment.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.045;
uniform float vignette = 0.32;
uniform float vhs = 0.0;
uniform float fade = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	if (vhs > 0.0) {
		float line = floor(uv.y * 240.0);
		float jitter = (hash(vec2(line, floor(TIME * 24.0))) - 0.5) * 0.0012 * vhs;
		float wob = sin(uv.y * 6.0 + TIME * 1.3) * 0.0006 * vhs;
		uv.x += jitter + wob;
	}
	vec3 col = texture(screen_texture, uv).rgb;
	if (vhs > 0.0) {
		float ca = 0.0016 * vhs;
		col.r = texture(screen_texture, uv + vec2(ca, 0.0)).r;
		col.b = texture(screen_texture, uv - vec2(ca, 0.0)).b;
		col *= 0.94 + 0.06 * sin(SCREEN_UV.y * 900.0);
		float bandpos = fract(TIME * 0.05);
		col += vec3(0.03) * smoothstep(0.02, 0.0, abs(SCREEN_UV.y - bandpos)) * vhs;
		col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), 0.12 * vhs);
	}
	float g = hash(SCREEN_UV * vec2(1013.0, 619.0) + fract(TIME * 7.13)) - 0.5;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col += g * grain * (1.0 - lum * 0.6);
	vec2 c = SCREEN_UV - 0.5;
	col *= 1.0 - dot(c, c) * vignette * 2.0;
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
