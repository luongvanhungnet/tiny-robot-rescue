export const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
export const length = (points) =>
  points.slice(1).reduce((sum, p, i) => sum + distance(points[i], p), 0);
export function pointSegment(p, a, b) {
  const dx = b[0] - a[0],
    dy = b[1] - a[1];
  const t = Math.max(
    0,
    Math.min(
      1,
      ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy || 1),
    ),
  );
  return distance(p, [a[0] + t * dx, a[1] + t * dy]);
}
export function intersects(a, b, c, d) {
  const cross = (p, q, r) =>
    (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]);
  return (
    cross(a, b, c) * cross(a, b, d) < 0 && cross(c, d, a) * cross(c, d, b) < 0
  );
}
export function validateStroke(points, level) {
  if (
    points.length < 2 ||
    points.some((p) => p.length !== 2 || !p.every(Number.isFinite))
  )
    return "Draw a longer line.";
  if (points.length > 96) return "Your line has too many corners.";
  if (length(points) < 24) return "Draw a longer line.";
  if (length(points) > level.max_stroke_length + 0.01)
    return "Out of ink. Try a shorter line.";
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1],
      b = points[i];
    if (distance(a, b) < 0.5) return "Keep your line moving.";
    // Sample at 3 world units to prevent a fast pointer skipping thin obstacles.
    for (let j = 0; j <= Math.ceil(distance(a, b) / 3); j++) {
      const t = j / Math.max(1, Math.ceil(distance(a, b) / 3)),
        p = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
      if (
        !level.draw_zones.some(
          ([x, y, w, h]) =>
            p[0] >= x && p[0] <= x + w && p[1] >= y && p[1] <= y + h,
        )
      )
        return "Draw inside the workshop.";
      if (
        level.forbidden_zones.some(
          ([x, y, w, h]) =>
            p[0] >= x - 7 &&
            p[0] <= x + w + 7 &&
            p[1] >= y - 7 &&
            p[1] <= y + h + 7,
        )
      )
        return "That area needs to stay clear.";
      for (const o of level.objects) {
        if (
          o.type === "robot" &&
          Math.abs(p[0] - o.x) < 32 &&
          Math.abs(p[1] - o.y) < 37
        )
          return "Give Pip a little space.";
        if (
          ["platform", "gate"].includes(o.type) &&
          Math.abs(p[0] - o.x) < o.w / 2 + 6 &&
          Math.abs(p[1] - o.y) < o.h / 2 + 6
        )
          return "Draw around the solid platforms.";
      }
    }
    for (let j = 1; j < i - 1; j++)
      if (intersects(a, b, points[j - 1], points[j]))
        return "Try a line without crossing itself.";
  }
  return null;
}
export function simplify(points, tolerance = 3) {
  if (points.length <= 2) return points;
  let far = 0,
    index = 0;
  for (let i = 1; i < points.length - 1; i++) {
    const d = pointSegment(points[i], points[0], points.at(-1));
    if (d > far) {
      far = d;
      index = i;
    }
  }
  return far > tolerance
    ? [
        ...simplify(points.slice(0, index + 1), tolerance).slice(0, -1),
        ...simplify(points.slice(index), tolerance),
      ]
    : [points[0], points.at(-1)];
}
