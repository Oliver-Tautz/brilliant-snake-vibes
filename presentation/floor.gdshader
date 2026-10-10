// Paper-grey checkered floor, like a 1920s cartoon kitchen, with paper fibre noise.
shader_type canvas_item;

uniform float cell = 24.0;
uniform vec4 light : source_color = vec4(0.84, 0.84, 0.83, 1.0);
uniform vec4 dark : source_color = vec4(0.80, 0.80, 0.79, 1.0);

varying vec2 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = VERTEX;
}

void fragment() {
	vec2 c = floor(world / cell);
	vec3 col = mix(light.rgb, dark.rgb, mod(c.x + c.y, 2.0));
	// Slightly uneven hand-painted tiles and paper fibre.
	col *= 0.97 + 0.03 * hash(c);
	col *= 0.975 + 0.025 * hash(floor(world / 2.0));
	COLOR = vec4(col, 1.0);
}
