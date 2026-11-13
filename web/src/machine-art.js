import { machineTypes } from "./machines.js";

// Symbols duplicate color cues: paired diamonds, gravity arrows, +/- poles,
// a launch arrow, and pressure pips remain readable without color perception.
export function drawMachine(g, b, sim) {
  if (!machineTypes.includes(b.label)) return false;
  const { x, y } = b.position,
    o = b.plugin;
  const arrow = (cx, cy, angle, size = 20, color = 0xc6a7ef) => {
    const dx = Math.cos(angle),
      dy = Math.sin(angle);
    g.lineStyle(3, color, 0.8).lineBetween(
      cx - dx * size,
      cy - dy * size,
      cx + dx * size,
      cy + dy * size,
    );
    for (const side of [-1, 1])
      g.lineBetween(
        cx + dx * size,
        cy + dy * size,
        cx + dx * (size - 10) - dy * side * 8,
        cy + dy * (size - 10) + dx * side * 8,
      );
  };
  switch (b.label) {
    case "portal": {
      const color = o.channel === "amber" ? 0xf6c675 : 0x9fa8ff;
      g.lineStyle(1, color, 0.16).lineBetween(x, y, o.to_x, o.to_y);
      for (const [px, py, out] of [
        [x, y, false],
        [o.to_x, o.to_y, true],
      ]) {
        g.fillStyle(0x17283f, 0.85).fillEllipse(px, py, 62, 62);
        g.lineStyle(out ? 2 : 5, color).strokeEllipse(px, py, 62, 62);
        g.lineStyle(2, color, 0.7).strokeCircle(px, py, 22);
        arrow(px, py, Math.atan2(o.vy ?? 0, o.vx ?? 0), out ? 13 : 8, color);
        // The same number of pips identifies entry/exit pairs.
        for (let n = 0; n <= o.id % 3; n++)
          g.fillStyle(color).fillCircle(px - 12 + n * 12, py - 40, 3);
      }
      break;
    }
    case "gravity": {
      g.fillStyle(0xc6a7ef, 0.065).fillRect(x - o.w / 2, y - o.h / 2, o.w, o.h);
      g.lineStyle(2, 0xc6a7ef, 0.3).strokeRect(
        x - o.w / 2,
        y - o.h / 2,
        o.w,
        o.h,
      );
      const angle = Math.atan2(o.gy ?? -0.001, o.gx ?? 0);
      for (let px = x - o.w / 2 + 45; px < x + o.w / 2; px += 90)
        for (let py = y - o.h / 2 + 45; py < y + o.h / 2; py += 100) {
          if (!(o.gx ?? 0) && o.gy === 0) {
            g.lineStyle(2, 0xc6a7ef, 0.6).strokeCircle(px, py, 10);
          } else arrow(px, py, angle, 13);
        }
      break;
    }
    case "magnet": {
      const color =
        o.energized === false ? 0x667383 : o.repel ? 0xf5a6ba : 0x79d8db;
      g.lineStyle(1, color, 0.13).strokeCircle(x, y, o.radius);
      g.fillStyle(0x172b3b).fillRoundedRect(x - 24, y - 24, 48, 48, 8);
      g.lineStyle(5, color).strokeRoundedRect(x - 20, y - 20, 40, 40, 7);
      g.lineStyle(3, color).lineBetween(x - 11, y, x + 11, y);
      if (!o.repel) g.lineBetween(x, y - 11, x, y + 11);
      for (const a of [Math.PI * 1.1, Math.PI * 1.4, Math.PI * 1.7])
        arrow(
          x + Math.cos(a) * 65,
          y + Math.sin(a) * 65,
          a + (o.repel ? 0 : Math.PI),
          9,
          color,
        );
      if (o.until) g.lineStyle(3, color).strokeCircle(x, y, 32);
      break;
    }
    case "launcher":
      g.fillStyle(0x513c2b, 0.6).fillRoundedRect(
        x - o.w / 2,
        y - o.h / 2,
        o.w,
        o.h,
        10,
      );
      g.lineStyle(3, 0xf2ba78).strokeRoundedRect(
        x - o.w / 2,
        y - o.h / 2,
        o.w,
        o.h,
        10,
      );
      arrow(x, y, Math.atan2(o.vy, o.vx), 22, 0xf2ba78);
      if (o.channel)
        g.lineStyle(
          2,
          o.channel === "amber" ? 0xf6c675 : 0x70ddea,
        ).strokeCircle(x, y, 29);
      break;
    case "plate": {
      const color = o.active ? 0xb6f36d : 0xf2ba78;
      for (const gate of sim.entities.filter(
        (body) => body.label === "gate" && body.plugin.channel === o.channel,
      )) {
        g.lineStyle(1, color, 0.3).lineBetween(
          x,
          y,
          gate.position.x,
          gate.position.y,
        );
        g.lineStyle(2, color).strokeCircle(gate.position.x, gate.position.y, 8);
      }
      g.fillStyle(color, 0.07).fillRect(x - o.w / 2, y - o.h / 2, o.w, o.h);
      g.lineStyle(3, color).strokeRect(x - o.w / 2, y - o.h / 2, o.w, o.h);
      const ratio = Math.min(1, (o.held ?? 0) / (o.hold_for || 1));
      g.fillStyle(color, 0.5).fillRect(
        x - o.w / 2,
        y + o.h / 2 - 7,
        o.w * ratio,
        7,
      );
      for (let i = 0; i < (o.required ?? 1); i++)
        g.fillStyle(color).fillCircle(
          x + (i - ((o.required ?? 1) - 1) / 2) * 22,
          y,
          7,
        );
      break;
    }
  }
  return true;
}
