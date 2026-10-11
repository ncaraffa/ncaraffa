shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// An eye in the dark. Pale, wet, too big, almost greyscale: the sclera, a dark
// iris, a black pupil, two hard highlights, the lids. Everything around it
// falls away into black. `look` moves the iris (-1..1), `open` closes the lids.

uniform vec2 look = vec2(0.0);
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float dilate = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow = 1.0;
uniform float surround = 0.85;   // how much dark skin around it (0 = only the eye)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float x = p.x;
	float hmax = 0.5 * pow(max(0.0, 1.0 - x * x), 0.8);
	float top = hmax * open + 0.03 * sin(x * 2.4 + 0.6) * open;
	float bot = -hmax * open * 0.78;
	float inside = smoothstep(0.0, 0.025, top - p.y) * smoothstep(0.0, 0.025, p.y - bot);
	vec2 c = look * vec2(0.42, 0.2);
	float r = length(p - c);
	// sclera: pale, shadowed under the upper lid and towards the corners
	float sh = 0.62 + 0.22 * (1.0 - abs(x));
	sh *= 0.55 + 0.45 * smoothstep(-0.02, 0.22, top - p.y);
	sh *= 0.85 + 0.15 * vnoise(p * 9.0);
	vec3 col = vec3(sh) * vec3(0.96, 0.94, 0.92);
	// iris with fibres and a dark limbal ring
	float ir = 0.27;
	float iris = smoothstep(ir, ir - 0.012, r);
	float ang = atan(p.y - c.y, p.x - c.x);
	float fib = vnoise(vec2(ang * 9.0, r * 22.0));
	vec3 icol = vec3(0.05 + 0.13 * fib * smoothstep(0.08, ir, r));
	icol *= 1.0 - 0.6 * smoothstep(ir - 0.06, ir, r);
	col = mix(col, icol, iris);
	// pupil
	float pr = 0.115 * dilate;
	col = mix(col, vec3(0.0), smoothstep(pr, pr - 0.01, r));
	// highlights on the wet surface
	float hl = smoothstep(0.034, 0.02, length(p - c - vec2(-0.05, 0.06)));
	hl += 0.7 * smoothstep(0.022, 0.012, length(p - c - vec2(0.04, 0.065)));
	hl += 0.25 * smoothstep(0.06, 0.0, abs(p.y - bot - 0.02)) * inside * (1.0 - abs(x));
	col += vec3(hl) * open;
	// lids and the skin around: almost black, a little texture
	float skin_mask = smoothstep(1.0, 0.25, length(p * vec2(0.8, 1.5)));
	vec3 skin = vec3(0.03 + 0.02 * vnoise(p * 14.0)) * skin_mask;
	col = mix(skin, col, inside);
	ALBEDO = col * glow;
	ALPHA = clamp(inside + (1.0 - inside) * skin_mask * surround, 0.0, 1.0) * fade;
}
