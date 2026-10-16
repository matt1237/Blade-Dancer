shader_type canvas_item;
render_mode unshaded;
// All masks use untouched source-image pixels, never screen coordinates.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float ambient_time = 0.0;
uniform sampler2D window_matte : filter_linear, repeat_disable;
uniform sampler2D bird_texture : source_color, filter_linear, repeat_disable;
uniform bool bird_visible = false;
uniform vec2 bird_center = vec2(0.0);
uniform float bird_size = 26.0;
uniform bool bird_reverse = false;
float hash_cloud(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash_cloud(i),hash_cloud(i+vec2(1.0,0.0)),f.x),
		mix(hash_cloud(i+vec2(0.0,1.0)),hash_cloud(i+vec2(1.0,1.0)),f.x),f.y);
}
// Slowly advect a broad, irregular exterior transmittance field, not a room blob.
float cloud_cover(vec2 p) {
	vec2 q = (p-vec2(ambient_time*4.0,0.0))/vec2(100.0,62.0);
	float field = cloud_noise(q)*0.65+cloud_noise(q*2.03+3.1)*0.25+cloud_noise(q*4.11+7.2)*0.10;
	return smoothstep(0.36,0.70,field);
}
float mask(vec2 p, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.25, 1.0, length((p-c)/r));
}
float flicker(float t, float phase) {
	return 0.5*sin(t*3.7+phase)+0.3*sin(t*7.13+phase*2.1)+0.2*sin(t*11.31+phase*0.7);
}
void fragment() {
	vec2 p = UV * vec2(1672.0,941.0);
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	// Light breathes through existing bright paint, not a colored ellipse overlay.
	float daylight = mask(p,vec2(1325.0,280.0),vec2(95.0,170.0))*sin(ambient_time*0.16+1.7);
	// Left-window/floor sunlight now belongs to the single cloud field below.
	float warm = smoothstep(0.30,0.85,base.r) * smoothstep(0.02,0.18,base.r-base.b);
	rgb += base.rgb * daylight * warm * 0.025 * strength;
	float lamps = mask(p,vec2(943.0,108.0),vec2(31.0,43.0))*flicker(ambient_time,0.3)
		+ mask(p,vec2(748.0,448.0),vec2(25.0,35.0))*flicker(ambient_time,2.4)
		+ mask(p,vec2(1029.0,397.0),vec2(16.0,26.0))*flicker(ambient_time,4.1)
		+ mask(p,vec2(1261.0,441.0),vec2(18.0,28.0))*flicker(ambient_time,5.8)
		+ mask(p,vec2(1660.0,535.0),vec2(26.0,54.0))*flicker(ambient_time,7.7);
	rgb += base.rgb * lamps * warm * 0.075 * strength;
	// Interior only: the sphere's rim, reflections and gold armillary never move.
	vec2 q = p-vec2(1560.0,554.0);
	float radius = length(q);
	float interior = 1.0-smoothstep(17.0,24.0,radius);
	float purple = smoothstep(0.0,0.12,base.b-base.r);
	float angle = atan(q.y,q.x);
	float swirl = sin(angle*2.0-radius*0.24-ambient_time*0.65+sin(radius*0.17+ambient_time*0.27));
	rgb += vec3(0.045,0.025,0.085)*swirl*interior*purple*strength;
	// Crystal facets catch a rare narrow gleam; no added sparkle geometry.
	vec2 crystal = p-vec2(1615.0,286.0);
	float facet = mask(p,vec2(1615.0,286.0),vec2(13.0,22.0));
	float blue = smoothstep(0.10,0.35,base.b-base.r);
	float cycle = mod(ambient_time+3.0,11.7);
	float glint = exp(-pow((cycle-1.1)/0.3,2.0));
	float sweep = exp(-pow((crystal.x+crystal.y*0.25-(cycle-1.1)*28.0)/2.3,2.0));
	rgb += vec3(0.08,0.15,0.23)*facet*blue*(glint*sweep+0.055*sin(ambient_time*0.73))*strength;
	vec2 matte = texture(window_matte,UV).rg;
	float left_glass = matte.r * (1.0-step(700.0,p.x));
	float cover = cloud_cover(p);
	// Exterior clouds now read clearly in the glass; the slow field also dims
	// only the existing painted sunlight pool on the floor.
	rgb = mix(rgb,vec3(0.97,0.965,0.92),left_glass*cover*0.32*strength);
	rgb *= 1.0-left_glass*cover*0.11*strength;
	vec2 projected = vec2(410.0+(p.x-540.0)*0.30,210.0+(p.y-745.0)*0.8);
	float floor_cloud = cloud_cover(projected);
	rgb *= 1.0-matte.g*floor_cloud*0.29*strength;
	// Occasional broad sunbeams travel down the existing warm floor-light mask.
	// They fade with cloud cover instead of appearing through the clouds.
	float ray_cycle = mod(ambient_time,16.0);
	float ray_pulse = smoothstep(0.2,0.6,ray_cycle)*(1.0-smoothstep(9.0,10.5,ray_cycle));
	float clear_sky = 1.0-cover*0.14-floor_cloud*0.04;
	// Rays begin inside the left window and continue toward the visible floor pool.
	// The old green matte is incomplete, so use a narrow floor-only bound here.
	float window_y = smoothstep(145.0,170.0,p.y)*(1.0-smoothstep(235.0,270.0,p.y));
	float window_center_a = 366.0+(p.y-170.0)*0.10;
	float window_center_b = 381.0+(p.y-170.0)*0.16;
	float window_center_c = 395.0+(p.y-170.0)*0.22;
	float window_pattern = max(max(exp(-pow((p.x-window_center_a)/13.0,2.0)),exp(-pow((p.x-window_center_b)/15.0,2.0))),exp(-pow((p.x-window_center_c)/17.0,2.0)));
	float window_beams = window_pattern*window_y*left_glass*ray_pulse*clear_sky*strength;
	float floor_y = smoothstep(640.0,680.0,p.y)*(1.0-smoothstep(770.0,790.0,p.y));
	float floor_bounds = smoothstep(280.0,315.0,p.x)*(1.0-smoothstep(600.0,635.0,p.x));
	float floor_center_a = 365.0+(p.y-700.0)*0.30;
	float floor_center_b = 405.0+(p.y-700.0)*0.52;
	float floor_center_c = 445.0+(p.y-700.0)*0.74;
	float floor_pattern = max(max(exp(-pow((p.x-floor_center_a)/17.0,2.0)),exp(-pow((p.x-floor_center_b)/20.0,2.0))),exp(-pow((p.x-floor_center_c)/23.0,2.0)));
	float floor_volume = floor_pattern*floor_y*floor_bounds*ray_pulse*clear_sky*strength;
	float floor_shafts = floor_volume*0.78;
	float floor_haze = max(max(exp(-pow((p.x-floor_center_a)/43.0,2.0)),exp(-pow((p.x-floor_center_b)/48.0,2.0))),exp(-pow((p.x-floor_center_c)/53.0,2.0)))*floor_y*floor_bounds*ray_pulse*clear_sky*strength;
	rgb = mix(rgb,vec3(1.0,0.86,0.55),window_beams*0.66);
	rgb = mix(rgb,vec3(1.0,0.78,0.38),floor_haze*0.55);
	rgb = mix(rgb,vec3(1.0,0.62,0.18),floor_volume*0.78);
	rgb = mix(rgb,vec3(1.0,0.94,0.70),floor_shafts*0.94);
	// Slow, individually spaced dust flecks drifting through the window-light patch.
	float mote_halo = 0.0;
	float mote_core = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float offset = hash_cloud(vec2(fi,19.7));
		float vertical = hash_cloud(vec2(fi,43.1));
		float drift = fract(ambient_time*0.012+offset);
		vec2 mote = vec2(335.0+drift*240.0,650.0+vertical*95.0+sin(ambient_time*0.42+fi*2.17)*5.0);
		vec2 mote_delta = p-mote;
		float distance_squared = dot(mote_delta,mote_delta);
		mote_halo += exp(-distance_squared/125.0);
		mote_core += exp(-distance_squared/24.0);
	}
	float dust_bounds = floor_bounds*floor_y*strength;
	float halo_mask = min(mote_halo,1.0)*dust_bounds;
	float core_mask = min(mote_core,1.0)*dust_bounds;
	rgb = mix(rgb,vec3(0.52,0.24,0.07),halo_mask*0.22);
	rgb = mix(rgb,vec3(1.0,0.88,0.55),core_mask*0.78);
	if (bird_visible) {
		vec2 bird_uv = (p-bird_center)/bird_size+vec2(0.5);
		float inside = step(0.0,bird_uv.x)*step(bird_uv.x,1.0)*step(0.0,bird_uv.y)*step(bird_uv.y,1.0);
		if (bird_reverse) { bird_uv.x = 1.0-bird_uv.x; }
		vec4 bird = texture(bird_texture,clamp(bird_uv,vec2(0.0),vec2(1.0)));
		// Glass matte excludes arch/frame/mullions and every foreground leaf or pot.
		rgb = mix(rgb,bird.rgb*0.88+vec3(0.09,0.085,0.06),bird.a*inside*matte.r*strength*0.90);
	}
	COLOR = vec4(rgb,base.a);
}
