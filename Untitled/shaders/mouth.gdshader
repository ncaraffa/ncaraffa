shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// A mouth hanging open, too wide: a jagged oval, a red-black throat, small
// crooked teeth along the edges. Alpha outside the opening.

uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 3.0;

float h1(float x) { return fract(sin(x * 91.7 + seed * 13.1) * 43758.5); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	// the opening: taller than wide, the jaw dropped too far
	float w = 0.55 + 0.08 * sin(p.y * 7.0 + seed);
	float hh = mix(0.15, 0.95, open);
	float e = (p.x * p.x) / (w * w) + (p.y * p.y) / (hh * hh);
	// ragged lips
	float rag = 0.07 * sin(atan(p.y, p.x) * 23.0 + seed * 5.0);
	float inside = 1.0 - smoothstep(0.92 + rag, 1.0 + rag, e);
	if (inside < 0.02) {
		discard;
	}
	// teeth: upper and lower rows of uneven points
	float col = floor((p.x + 1.0) * 7.0);
	float tw = fract((p.x + 1.0) * 7.0);
	float len = 0.12 + 0.16 * h1(col);
	float edge_top = hh * sqrt(max(0.0, 1.0 - p.x * p.x / (w * w)));
	float tooth_shape = 1.0 - abs(tw - 0.5) * 2.0;
	float top = step(edge_top - p.y, len * tooth_shape) * step(0.0, p.y);
	float bot = step(edge_top + p.y, len * 0.8 * tooth_shape) * step(p.y, 0.0);
	float teeth = clamp(top + bot, 0.0, 1.0) * step(0.15, h1(col + 7.0));
	// the throat: red-black, darkest in the middle
	float depth = smoothstep(0.0, 0.9, e);
	vec3 throat = mix(vec3(0.0), vec3(0.13, 0.008, 0.006), depth);
	vec3 tooth = vec3(0.62, 0.58, 0.47) * (0.75 + 0.25 * h1(col + 3.0));
	ALBEDO = mix(throat, tooth, teeth);
	ALPHA = inside;
}
