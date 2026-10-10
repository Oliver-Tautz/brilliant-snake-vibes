// Old-film treatment over the whole screen: gate weave, flicker, grain, scratches, dust, vignette.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float grain = 0.09;
uniform float desaturate = 0.2;

float rand(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

float rand2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 18.0);  // film runs at a jumpy 18 fps
	vec2 uv = SCREEN_UV + (vec2(rand(frame), rand(frame + 1.7)) - 0.5) * 0.002;
	vec3 col = texture(screen_tex, uv).rgb;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate);  // dirty, off colours
	col *= 0.93 + 0.07 * rand(frame + 3.1);  // flicker
	col += (rand2(floor(FRAGCOORD.xy / 1.5) + frame) - 0.5) * grain;

	for (int i = 0; i < 3; i++) {  // vertical scratches that come and go
		float fi = float(i);
		float x = rand(floor(TIME * 4.0) * 0.37 + fi * 13.1);
		float on = step(0.55, rand(floor(TIME * 4.0) + fi * 7.7));
		col = mix(col, vec3(0.92), on * 0.55 * smoothstep(0.0012, 0.0, abs(uv.x - x)));
	}
	float speck = step(0.9993, rand2(floor(FRAGCOORD.xy / 3.0) + frame * 1.31));
	col = mix(col, vec3(0.04), speck);  // dust

	vec2 d = (SCREEN_UV - 0.5) * vec2(1.15, 1.0);
	col *= 1.0 - 0.75 * smoothstep(0.45, 0.85, length(d));  // vignette
	COLOR = vec4(col, 1.0);
}
