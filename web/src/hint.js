import { distance, length } from "./stroke.js";

export function partialPath(points, progress) {
  if (!points.length) return [];
  if (progress >= 1) return points.map((p) => [...p]);
  let remaining = length(points) * Math.max(0, Math.min(1, progress));
  const result = [[...points[0]]];
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1],
      b = points[i],
      span = distance(a, b);
    if (span === 0) continue;
    if (remaining >= span) {
      result.push([...b]);
      remaining -= span;
    } else {
      if (remaining > 0)
        result.push([
          a[0] + ((b[0] - a[0]) * remaining) / span,
          a[1] + ((b[1] - a[1]) * remaining) / span,
        ]);
      break;
    }
  }
  return result;
}

export function dashedPath(points, dash = 16, gap = 11) {
  const segments = [],
    cycle = dash + gap;
  let offset = 0;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1],
      b = points[i],
      span = distance(a, b);
    if (span === 0) continue;
    for (let k = Math.floor(offset / cycle); k * cycle < offset + span; k++) {
      const lo = Math.max(offset, k * cycle),
        hi = Math.min(offset + span, k * cycle + dash);
      if (hi <= lo) continue;
      const point = (t) => [
        a[0] + ((b[0] - a[0]) * t) / span,
        a[1] + ((b[1] - a[1]) * t) / span,
      ];
      segments.push([point(lo - offset), point(hi - offset)]);
    }
    offset += span;
  }
  return segments;
}

// Visual state only: this module never creates colliders or changes a run.
export class HintGuide {
  constructor() {
    this.hide();
    this.duration = 1800;
  }
  show(points, reducedMotion = false) {
    this.points = points.map((p) => [...p]);
    this.active = this.points.length >= 2;
    this.elapsed = reducedMotion ? this.duration : 0;
  }
  advance(ms, reducedMotion = false) {
    if (this.active)
      this.elapsed = reducedMotion
        ? this.duration
        : Math.min(this.duration, this.elapsed + Math.max(0, ms));
  }
  get path() {
    return partialPath(this.points, this.elapsed / this.duration);
  }
  hide() {
    this.points = [];
    this.active = false;
    this.elapsed = 0;
  }
}
