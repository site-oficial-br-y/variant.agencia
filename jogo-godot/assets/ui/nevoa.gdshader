shader_type canvas_item;
render_mode blend_add;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int k = 0; k < 5; k++) { v += a * ruido(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec2 uv = UV * vec2(3.0, 1.6);
	float t = TIME * 0.06;
	float n = fbm(uv + vec2(t, t * 0.3)) * 0.6 + fbm(uv * 1.7 - vec2(t * 1.4, -t * 0.2)) * 0.4;
	float baixo = smoothstep(0.25, 0.85, UV.y);          // mais névoa embaixo, perto do pedestal
	float a = smoothstep(0.45, 0.85, n) * baixo * 0.32;
	COLOR = vec4(vec3(0.55, 0.3, 1.0) * a, a);
}
