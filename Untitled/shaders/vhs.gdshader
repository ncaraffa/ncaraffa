shader_type canvas_item;
// An old home-video tape, played back on a tired deck. Clearly readable, but
// never clean: grain, chroma bleed, line jitter, a slow tear rolling down the
// picture, washed-out colours, a noisy head-switching band at the bottom.

uniform float noise_amt = 0.075;
uniform float jitter = 0.0016;
uniform float bleed = 0.0022;
uniform float glitch = 0.0;     // 0..1, heavy tracking trouble
uniform float brightness = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float line = floor(uv.y * 240.0);
	float jit = (hash(vec2(line, floor(t * 30.0))) - 0.5) * jitter;
	float bandpos = fract(t * 0.045);
	float band = smoothstep(0.035, 0.0, abs(uv.y - bandpos));
	jit += band * 0.006;
	float bottom = smoothstep(0.935, 0.99, uv.y);
	jit += bottom * (hash(vec2(line, floor(t * 60.0))) - 0.5) * 0.035;
	jit += glitch * (hash(vec2(line * 0.37, floor(t * 60.0))) - 0.5) * 0.09;
	uv.x += jit + sin(t * 1.3 + uv.y * 3.0) * 0.0006;
	uv.y += glitch * (hash(vec2(floor(t * 24.0), 3.0)) - 0.5) * 0.04;
	vec3 col;
	col.r = texture(TEXTURE, uv + vec2(bleed, 0.0)).r;
	col.g = texture(TEXTURE, uv).g;
	col.b = texture(TEXTURE, uv - vec2(bleed * 1.4, 0.0)).b;
	vec3 sm = texture(TEXTURE, uv + vec2(0.0022, 0.0)).rgb + texture(TEXTURE, uv - vec2(0.0022, 0.0)).rgb;
	col = mix(col, sm * 0.5, 0.35);
	// aged: lifted blacks, less saturation, a warm cast
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.6);
	col = col * vec3(1.07, 0.99, 0.85) * brightness + vec3(0.03, 0.026, 0.032);
	float n = hash(uv * vec2(640.0, 480.0) + fract(t * 13.0) * 100.0);
	col += (n - 0.5) * (noise_amt + glitch * 0.35);
	col += band * 0.045;
	col = mix(col, vec3(n * 0.7), bottom * 0.55);
	col *= 0.94 + 0.06 * sin(uv.y * 480.0 * 3.14159);
	vec2 d = UV - 0.5;
	col *= 1.0 - dot(d, d) * 0.85;
	col *= 0.975 + 0.025 * sin(t * 47.0);
	COLOR = vec4(col, 1.0);
}
