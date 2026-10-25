shader_type canvas_item;
// fundo vivo (Block Blast / luta do Geresch): degradê roxo->azul com manchas de luz
// que passeiam, feixes de holofote e brilho nas bordas
uniform float aspecto = 1.777;
uniform float desloc = 0.0;      // parallax horizontal (câmera)
uniform float feixes = 1.0;

float blob(vec2 uv, vec2 c, float r) {
	vec2 d = (uv - c) * vec2(aspecto, 1.0);
	return smoothstep(r, 0.0, length(d));
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.12;
	vec3 topo = vec3(0.13, 0.05, 0.27);
	vec3 baixo = vec3(0.03, 0.17, 0.42);
	vec3 col = mix(topo, baixo, smoothstep(0.0, 1.0, uv.y));
	vec2 pu = uv + vec2(desloc, 0.0);
	col += vec3(0.75, 0.16, 0.55) * 0.55 * blob(pu, vec2(fract(0.22 + 0.1 * sin(t * 1.3)), 0.28 + 0.08 * cos(t)), 0.75);
	col += vec3(0.12, 0.5, 0.95) * 0.45 * blob(pu, vec2(fract(0.78 + 0.1 * cos(t * 0.9)), 0.7 + 0.1 * sin(t * 1.1)), 0.7);
	col += vec3(0.55, 0.25, 0.95) * 0.35 * blob(pu, vec2(fract(0.5 + 0.25 * sin(t * 0.6 + 2.0)), 0.1 + 0.06 * sin(t * 1.7)), 0.55);
	// dois feixes de luz vindo de cima (barato)
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float x0 = fract(0.25 + fk * 0.45 + desloc * 0.4);
		float d = abs((uv.x - x0) - uv.y * 0.3 * sin(TIME * 0.25 + fk * 1.7));
		col += vec3(0.85, 0.55, 1.0) * 0.07 * feixes * smoothstep(0.05 + 0.08 * uv.y, 0.0, d) * (1.0 - uv.y * 0.6);
	}
	vec2 v = (uv - 0.5) * vec2(1.0, 1.15);
	col *= 1.0 - 0.55 * dot(v, v);
	COLOR = vec4(col, 1.0);
}
