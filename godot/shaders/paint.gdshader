shader_type canvas_item;
// Cat tembok + motif dan jenis lantai untuk satu kamar.
// mask: R = tembok, G = lantai (dibuat dari kost-shell.jpg).
uniform sampler2D mask : filter_linear;
uniform vec4 region_uv;          // xy = asal, zw = ukuran wilayah kamar dalam UV tekstur
uniform vec2 room_size;          // ukuran kamar (px gedung)
uniform float floor_y;           // garis lantai (px kamar)
uniform bool wall_on = false;
uniform vec4 wall_col : source_color = vec4(1.0);
uniform vec4 wall_col2 : source_color = vec4(1.0);
uniform int motif = 0;           // 0 polos 1 garis 2 polkadot 3 kotak 4 bata 5 wajik
uniform int floor_kind = 0;      // 0 asli 1 kayu (warna) 2 keramik 3 karpet
uniform vec4 floor_col : source_color = vec4(1.0);
uniform vec4 floor_col2 : source_color = vec4(1.0);

float luma(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

void fragment() {
	vec4 o = texture(TEXTURE, UV);
	vec2 m = texture(mask, UV).rg;
	vec2 lp = (UV - region_uv.xy) / region_uv.zw * room_size;
	vec3 c = o.rgb;
	if (wall_on && m.r > 0.01) {
		float sh = clamp(luma(o.rgb) / 0.88, 0.0, 1.08);
		vec3 a = wall_col.rgb;
		vec3 b = wall_col2.rgb;
		float k = 0.0;
		if (motif == 1) {
			k = step(0.5, fract(lp.x / 44.0));
		} else if (motif == 2) {
			vec2 g = vec2(lp.x, lp.y + step(0.5, fract(lp.x / 76.0)) * 19.0);
			vec2 q = mod(g, vec2(38.0)) - 19.0;
			k = 1.0 - smoothstep(5.0, 7.0, length(q));
		} else if (motif == 3) {
			vec2 q = floor(lp / 34.0);
			k = mod(q.x + q.y, 2.0);
		} else if (motif == 4) {
			float row = floor(lp.y / 22.0);
			float x = lp.x + mod(row, 2.0) * 24.0;
			float gx = abs(fract(x / 48.0) - 0.5) * 48.0;
			float gy = abs(fract(lp.y / 22.0) - 0.5) * 22.0;
			k = (gx > 22.0 || gy > 9.4) ? 1.0 : 0.0;
			b = mix(wall_col.rgb, vec3(1.0), 0.55);
		} else if (motif == 5) {
			vec2 q = abs(fract(lp / vec2(40.0, 52.0)) - 0.5);
			k = 1.0 - smoothstep(0.24, 0.27, q.x + q.y * 0.77);
		}
		vec3 w = mix(a, b, k) * sh;
		c = mix(c, w, m.r);
	}
	if (floor_kind > 0 && m.g > 0.01) {
		vec3 f = c;
		if (floor_kind == 1) {
			// Kayu warna lain: pertahankan garis papan lewat terang-gelap aslinya.
			float sh = clamp(luma(o.rgb) / 0.74, 0.35, 1.15);
			f = floor_col.rgb * sh;
		} else if (floor_kind == 2) {
			// Keramik perspektif: titik hilang di atas tengah kamar.
			float d = max(lp.y - (floor_y - 260.0), 1.0);
			float u = (lp.x - room_size.x * 0.5) / d * 4.2;
			float v = 900.0 / d;
			float gu = abs(fract(u) - 0.5);
			float gv = abs(fract(v) - 0.5);
			float line = 1.0 - smoothstep(0.47, 0.49, max(gu, gv));
			vec2 cell = floor(vec2(u, v));
			float alt = mod(cell.x + cell.y, 2.0);
			vec3 base = mix(floor_col.rgb, floor_col2.rgb, alt);
			float shade = 0.9 + 0.1 * clamp((lp.y - floor_y) / (room_size.y - floor_y), 0.0, 1.0);
			f = mix(base * 0.72, base, line) * shade;
		} else if (floor_kind == 3) {
			float n = fract(sin(dot(floor(lp / 3.0), vec2(12.9898, 78.233))) * 43758.5453);
			float edge = 1.0;
			f = floor_col.rgb * (0.92 + 0.08 * n) * edge;
		}
		c = mix(c, f, m.g);
	}
	COLOR = vec4(c, o.a);
}
