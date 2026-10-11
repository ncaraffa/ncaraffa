shader_type spatial;
render_mode unshaded, cull_back;

// A body that swallows light: one flat, even darkness with no shading at all,
// so no limb, joint or curve can be read inside it — only the outline, like a
// hole cut out of the room. In darkness it is a hair lighter than black
// (`rim_strength`) so the shape can still be made out. The edge is ragged and
// slowly crawling. `dissolve` 0..1 erodes it (appear/vanish).
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(0.07, 0.075, 0.09);
uniform float rim_power = 4.0;
uniform float rim_strength = 0.35;
uniform float edge_noise = 0.8;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y);
	float b = mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y);
	return mix(a, b, f.z);
}

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fres = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), rim_power);
	float n = noise3(wp * 9.0 + vec3(0.0, TIME * 0.35, 0.0)) * 0.6 + noise3(wp * 23.0 - vec3(TIME * 0.2)) * 0.4;
	// ragged silhouette: near grazing angles some fragments drop out
	float edge = fres * edge_noise * n;
	float keep = n * (1.0 - dissolve * 1.15) + 0.35 - edge - dissolve * 0.6;
	if (keep < 0.18) {
		discard;
	}
	// pure black in light; only when asked to read in the dark (rim > 0.4) a hair lighter
	ALBEDO = rim_color * max(rim_strength - 0.4, 0.0) * 0.25;
}
