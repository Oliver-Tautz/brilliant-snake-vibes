// Paper-grey 1920s cartoon floor with paper fibre noise. The pattern, tone and contrast come from
// the divine_inspiration seed (presentation/art_direction.gd): 0 checker, 1 floorboards,
// 2 harlequin diamonds, 3 polka dots.
shader_type canvas_item;

uniform float cell = 24.0;
uniform int pattern = 0;
uniform float tone = 0.82;
uniform float contrast = 0.04;

varying vec2 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec2 u = world / cell;
	vec2 c = floor(u);
	float shade = 0.0;
	float ink = 0.0;
	if (pattern == 0) {
		shade = mod(c.x + c.y, 2.0);
	} else if (pattern == 1) {
		float x = u.x + hash(vec2(c.y, 3.0)) * 4.0;  // staggered plank seams
		shade = hash(vec2(floor(x / 4.0), c.y));
		ink = step(fract(u.y), 0.05) + step(fract(x / 4.0), 0.012);
	} else if (pattern == 2) {
		shade = mod(floor(u.x + u.y) + floor(u.x - u.y), 2.0);
	} else {
		shade = 1.0 - step(0.17, length(fract(u) - 0.5));
	}
	vec3 col = mix(vec3(tone + contrast), vec3(tone - contrast), shade);
	col = mix(col, vec3(tone - 0.3), clamp(ink, 0.0, 1.0) * 0.5);
	// Slightly uneven hand-painted tiles and paper fibre.
	col *= 0.97 + 0.03 * hash(c);
	col *= 0.975 + 0.025 * hash(floor(world / 2.0));
	COLOR = vec4(col, 1.0);
}
