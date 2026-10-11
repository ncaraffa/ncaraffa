shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Smoky outer shell around the figure: only fragments near the silhouette
// survive, flickering slowly, so the outline is never a clean CG edge.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y);
	return mix(a, b, f.z);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fres = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float n = noise3(wp * 14.0 + vec3(0.0, TIME * 0.6, TIME * 0.2));
	if (n < 0.62 - fres * 0.35 + dissolve * 0.6) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
