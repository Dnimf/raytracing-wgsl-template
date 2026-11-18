fn hit_sphere(center: vec3f, radius: f32, r: ray, record: ptr<function, hit_record>, max: f32)
{
  var d_quadrado = dot(r.direction,r.direction);
  var e = r.origin-center;
  var b = dot(r.direction,e);
  b = 2*b;
  var c = dot(e,e)-(radius*radius);
  var delta = (b*b)-4*(d_quadrado*c);
  var normal = vec3f(0.);
  if (delta<0){
      record.hit_anything = false;
      return;
  }
  if(delta == 0){
    var t = -b/(2*d_quadrado);
    if(t<RAY_TMIN ||t>max){
    // return false;
    record.hit_anything = false;
    return;
    }
    record.t = t;
    var intersection = ray_at(r, t);
    record.p = intersection;
    normal = normalize(intersection-center);
  
  }
  if(delta > 0){
    var t1 = (-b+sqrt(delta))/(2*d_quadrado);
    var t2 = (-b-sqrt(delta))/(2*d_quadrado);
    var t = t2;
    if(t2<RAY_TMIN || t2>max){
      if(t1<RAY_TMIN || t1>max){
        record.hit_anything = false;
        return; 
      }
        t = t1;
    }
    // if(t<RAY_TMIN ||t>RAY_TMAX){
    // // return false;
    // record.hit_anything = false;
    // return;
    // }
    record.t = t;
    var intersection = ray_at(r, t);
    record.p = intersection;
    normal = normalize(intersection-center);
  }
    if(dot(normalize(r.direction),normal)<0.){
      record.frontface =true;
      record.normal = normal;

    }
    else{
      record.frontface = false;
      record.normal = -normal;

    }
      record.hit_anything = true;
      return;
}

fn hit_quad(r: ray, Q: vec4f, u: vec4f, v: vec4f, record: ptr<function, hit_record>, max: f32)
{
  var n = cross(u.xyz, v.xyz);
  var normal = normalize(n);
  var D = dot(normal, Q.xyz);
  var w = n / dot(n.xyz, n.xyz);

  var denom = dot(normal, r.direction);
  if (abs(denom) < 0.0001)
  {
    record.hit_anything = false;
    return;
  }

  var t = (D - dot(normal, r.origin)) / denom;
  if (t < RAY_TMIN || t > max)
  {
    record.hit_anything = false;
    return;
  }

  var intersection = ray_at(r, t);
  var planar_hitpt_vector = intersection - Q.xyz;
  var alpha = dot(w, cross(planar_hitpt_vector, v.xyz));
  var beta = dot(w, cross(u.xyz, planar_hitpt_vector));

  if (alpha < 0.0 || alpha > 1.0 || beta < 0.0 || beta > 1.0)
  {
    record.hit_anything = false;
    return;
  }

  if (dot(normal, r.direction) > 0.0)
  {
    record.hit_anything = false;
    return;
  }

  record.t = t;
  record.p = intersection;
  record.normal = normal;
  record.hit_anything = true;
}

fn hit_triangle(r: ray, v0: vec3f, v1: vec3f, v2: vec3f, record: ptr<function, hit_record>, max: f32)
{
  var v1v0 = v1 - v0;
  var v2v0 = v2 - v0;
  var rov0 = r.origin - v0;

  var n = cross(v1v0, v2v0);
  var q = cross(rov0, r.direction);

  var d = 1.0 / dot(r.direction, n);

  var u = d * dot(-q, v2v0);
  var v = d * dot(q, v1v0);
  var t = d * dot(-n, rov0);

  if (u < 0.0 || u > 1.0 || v < 0.0 || (u + v) > 1.0)
  {
    record.hit_anything = false;
    return;
  }

  if (t < RAY_TMIN || t > max)
  {
    record.hit_anything = false;
    return;
  }

  record.t = t;
  record.p = ray_at(r, t);
  record.normal = normalize(n);
  record.hit_anything = true;
}

fn hit_box(r: ray, center: vec3f, rad: vec3f, record: ptr<function, hit_record>, t_max: f32)
{
  var m = 1.0 / r.direction;
  var n = m * (r.origin - center);
  var k = abs(m) * rad;

  var t1 = -n - k;
  var t2 = -n + k;

  var tN = max(max(t1.x, t1.y), t1.z);
  var tF = min(min(t2.x, t2.y), t2.z);

  if (tN > tF || tF < 0.0)
  {
    record.hit_anything = false;
    return;
  }

  var t = tN;
  if (t < RAY_TMIN || t > t_max)
  {
    record.hit_anything = false;
    return;
  }

  record.t = t;
  record.p = ray_at(r, t);
  record.normal = -sign(r.direction) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
  record.hit_anything = true;

  return;
}


fn hit_cilinder(r: ray, center: vec3f, rad:f32, height:f32, record: ptr<function, hit_record>, t_max: f32)
{
  var o = r.origin-center;
  var a = (r.direction.x*r.direction.x)+(r.direction.z*r.direction.z);
  var b = 2*(o.x*r.direction.x +o.z*r.direction.z);
  var c = (o.x*o.x)+(o.z*o.z)-(rad*rad);
  var delta = (b*b)-4*a*c;
  var normal = vec3f(0.);
  if (delta<0){
      record.hit_anything = false;
      return;
  }
  if(delta == 0){
    var t = -b/(2*a);
    if(t<RAY_TMIN ||t>t_max){
    record.hit_anything = false;
    return;
    }
    record.t = t;
    var intersection = ray_at(r, t);
    record.p = intersection;
    normal = normalize(intersection-center);
  
  }
  if(delta > 0){
    var t1 = (-b+sqrt(delta))/(2*a);
    var t2 = (-b-sqrt(delta))/(2*a);
    var t = t2;
    if(t2<RAY_TMIN || t2>t_max){
      if(t1<RAY_TMIN || t1>t_max){
        record.hit_anything = false;
        return; 
      }
        t = t1;
    }
    var intersection = ray_at(r, t);
    if(intersection.y > center.y+height || intersection.y <center.y){
        record.hit_anything = false;
        return;
    }
    record.t = t;

    record.p = intersection;
    normal = normalize(intersection-center);
  }
      if(dot(normalize(r.direction),normal)<0.){
      record.frontface =true;
      record.normal = normal;

    }
    else{
      record.frontface = false;
      record.normal = -normal;

    }
      record.hit_anything = true;
      return;
}