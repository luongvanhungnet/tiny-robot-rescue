import Matter from "matter-js";
const { Body } = Matter;
export const machineTypes = [
  "portal",
  "gravity",
  "magnet",
  "launcher",
  "plate",
];
export const inside = (body, machine) =>
  Math.abs(body.position.x - machine.position.x) < machine.plugin.w / 2 &&
  Math.abs(body.position.y - machine.position.y) < machine.plugin.h / 2;

// All forces and machine clocks advance with the shared fixed-step simulation.
export function applyMachines(sim) {
  const cargo = sim.entities.filter((b) => b.label === "cell");
  for (const m of sim.entities) {
    const o = m.plugin;
    if (m.label === "gravity") {
      for (const b of cargo.filter((b) => inside(b, m))) {
        Body.applyForce(b, b.position, {
          x: b.mass * (o.gx ?? 0),
          y: b.mass * ((o.gy ?? -0.001) - 0.001),
        });
        sim.usedMachines.add(o.id);
      }
    }
    if (m.label === "magnet") {
      o.energized = sim.elapsed < (o.until ?? Infinity);
      if (!o.energized) continue;
      for (const b of cargo) {
        const dx = m.position.x - b.position.x,
          dy = m.position.y - b.position.y;
        const d = Math.hypot(dx, dy);
        if (
          d < o.radius &&
          d > 5 &&
          (!o.channel || o.channel === b.plugin.channel)
        ) {
          const sign = o.repel ? -1 : 1;
          Body.applyForce(b, b.position, {
            x: (b.mass * sign * o.strength * dx) / d,
            y: (b.mass * sign * o.strength * dy) / d,
          });
          sim.usedMachines.add(o.id);
        }
      }
    }
  }
}

export function updateMachines(sim) {
  const cargo = sim.entities.filter((b) => b.label === "cell");
  for (const m of sim.entities) {
    const o = m.plugin;
    if (["portal", "launcher"].includes(m.label)) {
      for (const b of cargo) {
        if (!inside(b, m) || (o.channel && o.channel !== b.plugin.channel))
          continue;
        if (sim.elapsed < (b.plugin.machineReady ?? 0)) continue;
        if (m.label === "portal") {
          Body.setPosition(b, { x: o.to_x, y: o.to_y });
          Body.setVelocity(b, { x: o.vx ?? 0, y: o.vy ?? 0 });
          Body.setAngularVelocity(b, 0);
        } else {
          Body.setVelocity(b, { x: o.vx, y: o.vy });
        }
        b.plugin.machineReady = sim.elapsed + 0.3;
        sim.usedMachines.add(o.id);
        o.active = true;
      }
    }
    if (m.label === "plate") {
      const count = cargo.filter((b) => inside(b, m)).length;
      o.held = count >= (o.required ?? 1) ? (o.held ?? 0) + 1 / 60 : 0;
      o.active = count >= (o.required ?? 1) && o.held >= (o.hold_for ?? 0);
      if (o.active) {
        sim.usedMachines.add(o.id);
        sim.openGates(o.channel);
      } else {
        // Pressure gates close again: cargo must stay on the pad.
        for (const gate of sim.entities.filter(
          (b) => b.label === "gate" && b.plugin.channel === o.channel,
        )) {
          if (gate.plugin.open) {
            gate.plugin.open = false;
            gate.isSensor = false;
            Matter.Composite.add(sim.engine.world, gate);
          }
        }
      }
    }
  }
}
