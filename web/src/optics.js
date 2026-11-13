// Return the first polygon surface met by a beam, including rotated ink segments.
export function traceBeam(from, to, bodies) {
  const dx = to.x - from.x,
    dy = to.y - from.y;
  let nearest = { t: 1, body: null, x: to.x, y: to.y };
  for (const body of bodies) {
    const vertices = body.vertices;
    for (let i = 0; i < vertices.length; i++) {
      const a = vertices[i],
        b = vertices[(i + 1) % vertices.length];
      const ex = b.x - a.x,
        ey = b.y - a.y,
        denom = dx * ey - dy * ex;
      if (Math.abs(denom) < 1e-9) continue;
      const ax = a.x - from.x,
        ay = a.y - from.y,
        t = (ax * ey - ay * ex) / denom,
        u = (ax * dy - ay * dx) / denom;
      if (t >= 0 && t < nearest.t && u >= 0 && u <= 1)
        nearest = { t, body, x: from.x + dx * t, y: from.y + dy * t };
    }
  }
  return nearest;
}
