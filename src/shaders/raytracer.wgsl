const THREAD_COUNT = 16;
const RAY_TMIN = 0.0001;
const RAY_TMAX = 100.0;
const PI = 3.1415927f;
const FRAC_1_PI = 0.31830987f;
const FRAC_2_PI = 1.5707964f;

@group(0) @binding(0)  
  var<storage, read_write> fb : array<vec4f>;

@group(0) @binding(1)
  var<storage, read_write> rtfb : array<vec4f>;

struct UniformData {
  values : array<vec4f, 8>,
};

@group(1) @binding(0)
  var<uniform> uniforms : UniformData;

fn get_uniform(index : u32) -> f32 {
  return uniforms.values[index / 4u][index % 4u];
}

@group(2) @binding(0)
  var<storage, read_write> spheresb : array<sphere>;

@group(2) @binding(1)
  var<storage, read_write> quadsb : array<quad>;

@group(2) @binding(2)
  var<storage, read_write> boxesb : array<box>;

@group(2) @binding(3)
  var<storage, read_write> trianglesb : array<triangle>;

@group(2) @binding(4)
  var<storage, read_write> meshb : array<mesh>;

@group(2) @binding(5)
  var<storage, read_write> cilindersb : array<cilindro>;
struct ray {
  origin : vec3f,
  direction : vec3f,
};

struct sphere {
  transform : vec4f,
  color : vec4f,
  material : vec4f,
};

struct quad {
  Q : vec4f,
  u : vec4f,
  v : vec4f,
  color : vec4f,
  material : vec4f,
};

struct box {
  center : vec4f,
  radius : vec4f,
  rotation: vec4f,
  color : vec4f,
  material : vec4f,
};

struct cilindro {
  center : vec4f,
  axis : vec4f,
  rotation : vec4f,
  color : vec4f,
  material : vec4f,
};

struct triangle {
  v0 : vec4f,
  v1 : vec4f,
  v2 : vec4f,
};

struct mesh {
  transform : vec4f,
  scale : vec4f,
  rotation : vec4f,
  color : vec4f,
  material : vec4f,
  min : vec4f,
  max : vec4f,
  show_bb : f32,
  start : f32,
  end : f32,
};

struct material_behaviour {
  scatter : bool,
  direction : vec3f,
};

struct camera {
  origin : vec3f,
  lower_left_corner : vec3f,
  horizontal : vec3f,
  vertical : vec3f,
  u : vec3f,
  v : vec3f,
  w : vec3f,
  lens_radius : f32,
};

struct hit_record {
  t : f32,
  p : vec3f,
  normal : vec3f,
  object_color : vec4f,
  object_material : vec4f,
  frontface : bool,
  hit_anything : bool,
};

fn ray_at(r: ray, t: f32) -> vec3f
{
  return r.origin + t * r.direction;
}

fn get_ray(cam: camera, uv: vec2f, rng_state: ptr<function, u32>) -> ray
{
  var rd = cam.lens_radius * rng_next_vec3_in_unit_disk(rng_state);
  var offset = cam.u * rd.x + cam.v * rd.y;
  return ray(cam.origin + offset, normalize(cam.lower_left_corner + uv.x * cam.horizontal + uv.y * cam.vertical - cam.origin - offset));
}

fn get_camera(lookfrom: vec3f, lookat: vec3f, vup: vec3f, vfov: f32, aspect_ratio: f32, aperture: f32, focus_dist: f32) -> camera
{
  var camera = camera();
  camera.lens_radius = aperture / 2.0;

  var theta = degrees_to_radians(vfov);
  var h = tan(theta / 2.0);
  var w = aspect_ratio * h;

  camera.origin = lookfrom;
  camera.w = normalize(lookfrom - lookat);
  camera.u = normalize(cross(vup, camera.w));
  camera.v = cross(camera.u, camera.w);

  camera.lower_left_corner = camera.origin - w * focus_dist * camera.u - h * focus_dist * camera.v - focus_dist * camera.w;
  camera.horizontal = 2.0 * w * focus_dist * camera.u;
  camera.vertical = 2.0 * h * focus_dist * camera.v;

  return camera;
}

fn envoriment_color(direction: vec3f, color1: vec3f, color2: vec3f) -> vec3f
{
  var unit_direction = normalize(direction);
  var t = 0.5 * (unit_direction.y + 1.0);
  var col = (1.0 - t) * color1 + t * color2;

  var sun_direction = normalize(vec3(get_uniform(13u), get_uniform(14u), get_uniform(15u)));
  var sun_color = int_to_rgb(i32(get_uniform(17u)));
  var sun_intensity = get_uniform(16u);
  var sun_size = get_uniform(18u);

  var sun = clamp(dot(sun_direction, unit_direction), 0.0, 1.0);
  col += sun_color * max(0, (pow(sun, sun_size) * sun_intensity));

  return col;
}

fn check_ray_collision(r: ray, max: f32) -> hit_record
{
  var spheresCount = i32(get_uniform(19u));
  var quadsCount = i32(get_uniform(20u));
  var boxesCount = i32(get_uniform(21u));
  var trianglesCount = i32(get_uniform(22u));
  var meshCount = i32(get_uniform(27u));
  var cilinderCount = i32(get_uniform(28u));

  var record = hit_record(RAY_TMAX, vec3f(0.0), vec3f(0.0), vec4f(1.0), vec4f(1.0), true, false); // vec4 [e a cor]
  var temp_record = hit_record(RAY_TMAX, vec3f(0.0), vec3f(0.0), vec4f(1.0), vec4f(1.0), true, false); // vec4 [e a cor]
  var anterior = record.t;
  if(spheresCount>0){
    for(var i: i32 = 0; i< spheresCount; i++)
  {
    let esfera = spheresb[i];
    hit_sphere( esfera.transform.xyz, esfera.transform.w, r,&temp_record, max);
    if (!temp_record.hit_anything) 
    {
      continue;
    }

    if(temp_record.t > anterior)
    {
      continue;
    }
    
    if(spheresb[i].material[3] < 0.1){
    temp_record.object_color = spheresb[i].color;
    }
    else
    {
      var temp = emmisive(spheresb[i].color.xyz, spheresb[i].material[3]);
      temp_record.object_color = vec4f(temp.direction, temp_record.object_color.w);
    }

    temp_record.object_material= spheresb[i].material;
    // temp_record.frontface= !temp_record.frontface;
    anterior = temp_record.t;
    record = temp_record;
    // hit_boxc
  }  
  }
  if(boxesCount>0){
    for(var i: i32 = 0; i< boxesCount; i++)
  {
    let esfera = boxesb[i];
    var rotacao = quaternion_from_euler(boxesb[i].rotation.xyz);
    var q_inv =  q_conjugate(rotacao);
    var raio = rotate_ray_quaternion(r, boxesb[i].center.xyz,q_inv);

    hit_box(raio,  boxesb[i].center.xyz,  boxesb[i].radius.xyz,&temp_record,max);
    temp_record.p = ray_at(r,temp_record.t);
    temp_record.normal = normalize(rotate_vector(temp_record.normal, rotacao));
    // r = raio;
    if (!temp_record.hit_anything) 
    {
      continue;
    }

    if(temp_record.t > anterior)
    {
      continue;
    }
    
    if(boxesb[i].material[3] < 0.1){
    temp_record.object_color = boxesb[i].color;
    }
    else
    {
      var temp = emmisive(boxesb[i].color.xyz, boxesb[i].material[3]);
      temp_record.object_color = vec4f(temp.direction, temp_record.object_color.w);
    }

    temp_record.object_material= boxesb[i].material;
    // temp_record.frontface= !temp_record.frontface;
    anterior = temp_record.t;
    record = temp_record;
    // hit_boxc
  }  
  }

  if(cilinderCount>0){
    for(var i: i32 = 0; i< cilinderCount; i++)
  {
    let esfera = cilindersb[i];
    // var rotacao = quaternion_from_euler(boxesb[i].rotation.xyz);
    // var q_inv =  q_conjugate(rotacao);
    // var raio = rotate_ray_quaternion(r, boxesb[i].center.xyz,q_inv);

    hit_cilinder(r,cilindersb[i].center.xyz, cilindersb[i].center.w,cilindersb[i].axis.w, &temp_record, max);
    // temp_record.p = ray_at(r,temp_record.t);
    // temp_record.normal = normalize(rotate_vector(temp_record.normal, rotacao));
    // r = raio;
    if (!temp_record.hit_anything) 
    {
      continue;
    }

    if(temp_record.t > anterior)
    {
      continue;
    }
    
    if(cilindersb[i].material[3] < 0.1){
    temp_record.object_color = cilindersb[i].color;
    }
    else
    {
      var temp = emmisive(cilindersb[i].color.xyz, cilindersb[i].material[3]);
      temp_record.object_color = vec4f(temp.direction, temp_record.object_color.w);
    }

    temp_record.object_material= cilindersb[i].material;
    // temp_record.frontface= !temp_record.frontface;
    anterior = temp_record.t;
    record = temp_record;
    // hit_boxc
  }  
  }

  if(quadsCount>0){
    for(var i: i32 = 0; i< quadsCount; i++)
  {
    let esfera = quadsb[i];
    hit_quad(r,  quadsb[i].Q, quadsb[i].u, quadsb[i].v,&temp_record, max);
    if (!temp_record.hit_anything) 
    {
      continue;
    }

    if(temp_record.t > anterior)
    {
      continue;
    }
    
    if(quadsb[i].material[3] < 0.1){
    temp_record.object_color = quadsb[i].color;
    }
    else
    {
      var temp = emmisive(quadsb[i].color.xyz, quadsb[i].material[3]);
      temp_record.object_color = vec4f(temp.direction, temp_record.object_color.w);
    }

    temp_record.object_material= quadsb[i].material;
    // temp_record.frontface= !temp_record.frontface;
    anterior = temp_record.t;
    record = temp_record;
    // hit_boxc
  }  
  }
  if(trianglesCount>0){
    for(var j: i32 = 0; j< meshCount; j++)
  {
    for(var i: i32 = i32(meshb[j].start); i<i32(meshb[j].end);i++){
    let q = quaternion_from_euler(meshb[j].rotation.xyz);
    var q_inv =  q_conjugate(q);

    let triangulo = trianglesb[i];
    // var rotacao = quaternion_from_euler(meshb[j].rotation.xyz);
    // var centro = meshb[j].max-meshb[j].min;
    // var raio = rotate_ray_quaternion(r, centro.xyz,rotacao);
    var v0 = rotate_vector((trianglesb[i].v0*meshb[j].scale).xyz,q_inv)+meshb[j].transform.xyz;
    var v1 = rotate_vector((trianglesb[i].v1*meshb[j].scale).xyz,q_inv)+meshb[j].transform.xyz;
    var v2 = rotate_vector((trianglesb[i].v2*meshb[j].scale).xyz,q_inv)+meshb[j].transform.xyz;
    hit_triangle(r,  v0, v1, v2,&temp_record, max);
    if (!temp_record.hit_anything) 
    {
      continue;
    }

    if(temp_record.t > anterior)
    {
      continue;
    }
    
    if(meshb[j].material[3] < 0.1){
    temp_record.object_color =meshb[j].color;
    }
    else
    {
      var temp = emmisive(meshb[j].color.xyz, meshb[j].material[3]);
      temp_record.object_color = vec4f(temp.direction, temp_record.object_color.w);
    }

    temp_record.object_material= meshb[0].material;
    temp_record.frontface= !temp_record.frontface;
    anterior = temp_record.t;
    record = temp_record;
    // hit_boxc
    }
  }  
  }
  var closest = record;

  return closest;
}

fn lambertian(normal : vec3f, absorption: f32, random_sphere: vec3f, rng_state: ptr<function, u32>) -> material_behaviour
{
  var ponto = rng_next_vec3_in_unit_sphere(rng_state);
  ponto = ponto+normal;
  return material_behaviour(true, normalize(ponto));
}

fn metal(normal : vec3f, direction: vec3f, fuzz: f32, rng_state: ptr<function, u32>) -> material_behaviour
{
  // var vn = dot(direction,normal);
  // var r = v-2*vn;
  var r = reflect(normalize(direction), normalize(normal));
  if(fuzz >0.0){
  var ponto = rng_next_vec3_in_unit_sphere(rng_state);
  ponto = ponto+normal;
  r += fuzz*ponto;
  }
  return material_behaviour(false, r);
}

fn dielectric(normal : vec3f, r_direction: vec3f, refraction_index: f32, frontface: bool, random_sphere: vec3f, fuzz: f32, rng_state: ptr<function, u32>) -> material_behaviour
{  
  var n = 0.;
  if(frontface){
    n = 1./refraction_index;
  }
  else{
    n = refraction_index;
  }
  var rn = dot(-1.*r_direction,normal);
  var cos = min(rn,1.);
  // var cos = rn;
  var r0 = (1-n)/(1+n);
  r0 = r0*r0;
  var r1 = r0+(1-r0)*pow((1.-cos),5.);

  var seno = 1.-(cos*cos);
  seno = sqrt(seno);
  if((n*seno)>1. || r1>rng_next_float(rng_state)){
  var r = reflect(normalize(r_direction), normalize(normal));
  return material_behaviour(false, normalize(r));
  }
  else{
  var rnn = cos*normal;
  rnn = r_direction+rnn;
  var r_p = (n)*rnn;
  var raiz = 1.-(length(r_p)*length(r_p));
  var r_II = -1.*max(sqrt(raiz),0.)*normal;
  var r = r_p+r_II;
  return material_behaviour(false, normalize(r));
  }
}

fn emmisive(color: vec3f, light: f32) -> material_behaviour
{

  return material_behaviour(false, color*light);
}

fn trace(r: ray, rng_state: ptr<function, u32>) -> vec3f
{
  var maxbounces = i32(get_uniform(2u));
  var light = vec3f(0.0);
  var color = vec3f(1.0);
  var r_ = r;
  
  var backgroundcolor1 = int_to_rgb(i32(get_uniform(11u)));
  var backgroundcolor2 = int_to_rgb(i32(get_uniform(12u)));
  var behaviour = material_behaviour(true, vec3f(0.0));

  for (var j = 0; j < maxbounces; j = j + 1)
  {
    var colisao = check_ray_collision(r_, RAY_TMAX);
    if(colisao.hit_anything == true){
      // colisao.object_color.xyz = emmisive();
      if (colisao.object_material[3] > 0.1)
      {
        light += colisao.object_color.xyz * color;
        break;
      }
      color *= colisao.object_color.xyz;
      // if(colisao.object_material[0]>0){
      var lamb = lambertian(colisao.normal, colisao.object_material[1],vec3f(0.0), rng_state);
      var metal = metal(colisao.normal,r_.direction,colisao.object_material[1],rng_state);
      var direcao = normalize(mix(lamb.direction, metal.direction, colisao.object_material[0]));
      if(colisao.object_material[2]<=rng_next_float(rng_state)){
        direcao = lamb.direction;
      }
      if (colisao.object_material[0]<0.){
        var trans = dielectric(colisao.normal, r_.direction,colisao.object_material[2],colisao.frontface, vec3f(0.),0., rng_state);
        // direcao = normalize(mix(direcao,trans.direction,colisao.object_material[1]));
        direcao = trans.direction;
      }
        r_.origin = colisao.p+direcao*0.001;
        r_.direction = direcao;
      // }
    }
    else{
      // light += backgroundcolor1;
      light +=envoriment_color(r_.direction, backgroundcolor1, backgroundcolor2)*color;
      break;
    }
  }

  return light;
}

@compute @workgroup_size(THREAD_COUNT, THREAD_COUNT, 1)
fn render(@builtin(global_invocation_id) id : vec3u)
{
    var rez = get_uniform(1u);
    var time = u32(get_uniform(0u));

    // init_rng (random number generator) we pass the pixel position, resolution and frame
    var rng_state = init_rng(vec2(id.x, id.y), vec2(u32(rez)), time);

    // Get uv
    var fragCoord = vec2f(f32(id.x), f32(id.y));
    var uv = (fragCoord + sample_square(&rng_state)) / vec2(rez);

    // Camera
    var lookfrom = vec3(get_uniform(7u), get_uniform(8u), get_uniform(9u));
    var lookat = vec3(get_uniform(23u), get_uniform(24u), get_uniform(25u));

    // Get camera
    var cam = get_camera(lookfrom, lookat, vec3(0.0, 1.0, 0.0), get_uniform(10u), 1.0, get_uniform(6u), get_uniform(5u));
    var samples_per_pixel = i32(get_uniform(4u));

    // var color = vec3(rng_next_float(&rng_state), rng_next_float(&rng_state), rng_next_float(&rng_state));
    var color = vec3f(0.);
    // Steps:
    // 1. Loop for each sample per pixel
    // 2. Get ray
    // 3. Call trace function
    // 4. Average the color

    var map_fb = mapfb(id.xy, rez);
    // var 
    for(var i: i32 = 0; i< samples_per_pixel; i++){
      let raio = get_ray(cam, uv, &rng_state);
      let traco = trace(raio, &rng_state);
      color += traco;
    }
    // 5. Accumulate the color
    var color_out = vec4(linear_to_gamma(color/f32(samples_per_pixel)), 1.0);
    var should_accumulate = get_uniform(3u);
    // var should_accumulate = color/vec3(a);
    var acumulado = rtfb[map_fb]*should_accumulate +color_out;
    // Set the color to the framebuffer
    rtfb[map_fb] = acumulado;
    fb[map_fb] = (rtfb[map_fb]/rtfb[map_fb].w);
}