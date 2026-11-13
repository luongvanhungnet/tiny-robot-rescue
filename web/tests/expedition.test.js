import test from "node:test";
import assert from "node:assert/strict";
import Matter from "matter-js";
import { levels, LEVEL_COUNT, validateLevel } from "../src/levels.js";
import { Simulation } from "../src/simulation.js";
import { machineTypes } from "../src/machines.js";
import { Progress, SAVE_KEY } from "../src/save.js";
import { chapters, paints, paintUnlocked } from "../src/content.js";

const run = (s) => {
  for (let i = 0; i < 1000 && s.state === "SIMULATING"; i++) s.step(1000 / 60);
  return s;
};
const newLevels = levels.slice(50);
test("100-level campaign adds five complete chapters and 50 distinct machine layouts", () => {
  assert.equal(LEVEL_COUNT, 100);
  assert.equal(newLevels.length, 50);
  assert.equal(new Set(newLevels.map((l) => l.title)).size, 50);
  assert.deepEqual(
    chapters.slice(-5).map((c) => [c.first, c.last]),
    [
      [51, 60],
      [61, 70],
      [71, 80],
      [81, 90],
      [91, 100],
    ],
  );
  assert.ok(
    levels
      .slice(0, 50)
      .every((l) => l.objects.every((o) => !machineTypes.includes(o.type))),
  );
  assert.ok(
    newLevels.every((l) =>
      l.objects.some((o) => machineTypes.includes(o.type)),
    ),
  );
  const layouts = new Set(
    levels.map((l) => JSON.stringify([l.objects, l.objective])),
  );
  assert.equal(layouts.size, 100);
});
for (const level of newLevels) {
  test(`Level ${level.id} requires ink AND the new machinery`, () => {
    const families = [...new Set(level.objects.map((o) => o.type))].filter(
      (type) => machineTypes.includes(type),
    );
    for (const mode of ["ink", "machines", ...families]) {
      const l = structuredClone(level);
      if (mode === "machines")
        l.objects = l.objects.filter((o) => !machineTypes.includes(o.type));
      else if (mode !== "ink")
        l.objects = l.objects.filter((o) => o.type !== mode);
      const s = new Simulation(l);
      assert.equal(
        s.start(
          mode === "ink"
            ? [
                [50, 400],
                [100, 400],
              ]
            : l.solution,
        ),
        null,
      );
      run(s);
      assert.equal(s.state, "LOST", `${level.title}: missing ${mode}`);
      s.destroy();
    }
  });
  test(`Level ${level.id} tolerates mouse/touch quantization and uses every advertised machine`, () => {
    assert.ok(validateLevel(level));
    for (const [dx, dy] of [
      [0, 0],
      [-0.9, 0.5],
      [0.9, -0.5],
      [0.4, 0.9],
    ]) {
      const s = new Simulation(level);
      assert.equal(
        s.start(level.solution.map(([x, y]) => [x + dx, y + dy])),
        null,
      );
      run(s);
      assert.equal(
        s.state,
        "WON",
        `${level.title} at ${dx},${dy}: ${s.reason}`,
      );
      const machines = s.entities.filter((b) => machineTypes.includes(b.label));
      assert.equal(
        s.usedMachines.size,
        machines.length,
        `${level.title}: a machine was bypassed`,
      );
      s.destroy();
    }
  });
}
test("Portals respect channel, cooldown, exit momentum, and do not advance during planning", () => {
  const l = structuredClone(levels[50]),
    s = new Simulation(l);
  const b = s.entities.find((b) => b.label === "cell"),
    p = s.entities.find((b) => b.label === "portal");
  Matter.Body.setPosition(b, p.position);
  s.step(100);
  assert.equal(s.usedMachines.size, 0);
  p.plugin.channel = "amber";
  s.start(l.solution);
  s.step(1000 / 60);
  assert.equal(s.usedMachines.size, 0);
  p.plugin.channel = "cyan";
  s.step(1000 / 60);
  assert.equal(s.usedMachines.size, 1);
  assert.equal(b.position.x, p.plugin.to_x);
  assert.equal(b.velocity.x, p.plugin.vx);
  assert.ok(b.plugin.machineReady > s.elapsed);
  s.destroy();
});
test("Pressure gates require a sustained load and close when the weight is removed", () => {
  const l = levels[91],
    s = new Simulation(l);
  s.start(l.solution);
  const pad = s.entities.find((b) => b.label === "plate");
  const cargo = s.entities.filter((b) => b.label === "cell");
  const gate = s.entities.find((b) => b.label === "gate");
  pad.plugin.hold_for = 0;
  s.step(1000 / 60);
  assert.equal(pad.plugin.active, false, "A zero-delay pad still needs cargo");
  pad.plugin.hold_for = 1.5;
  cargo.forEach((b, i) => {
    Matter.Body.setPosition(b, { x: 280 + i * 40, y: 715 });
    Matter.Body.setVelocity(b, { x: 0, y: 0 });
  });
  s.step(1000 / 60);
  assert.equal(gate.plugin.open, undefined);
  for (let i = 0; i < 140; i++) s.step(1000 / 60);
  assert.equal(pad.plugin.active, true);
  assert.equal(gate.plugin.open, true);
  Matter.Body.setPosition(cargo[0], { x: 420, y: 450 });
  s.step(1000 / 60);
  assert.equal(pad.plugin.active, false);
  assert.equal(gate.plugin.open, false);
  assert.equal(
    Matter.Composite.allBodies(s.engine.world).filter((b) => b.id === gate.id)
      .length,
    1,
  );
  s.destroy();
});
test("A pulsed magnetic feed switches off on simulation time", () => {
  const s = new Simulation(levels[76]);
  s.start(s.level.solution);
  for (let i = 0; i < 60; i++) s.step(1000 / 60);
  assert.equal(
    s.entities.find((b) => b.label === "magnet").plugin.energized,
    false,
  );
  s.destroy();
});
test("The hundredth rescue needs each of its five machine systems", () => {
  for (const type of machineTypes) {
    const l = structuredClone(levels[99]);
    l.objects = l.objects.filter((o) => o.type !== type);
    const s = new Simulation(l);
    assert.equal(s.start(l.solution), null);
    run(s);
    assert.equal(s.state, "LOST", `Finale must need ${type}`);
    s.destroy();
  }
});
test("Old level-50 completion opens level 51; new chapter rewards and level 100 persist", () => {
  const data = new Map([
    [
      SAVE_KEY,
      JSON.stringify({
        version: 1,
        unlocked: 50,
        lastLevel: 50,
        stars: { 50: 3 },
        cosmetics: ["grand-circuit-hero"],
        paint: "aqua",
      }),
    ],
  ]);
  const storage = {
    getItem: (k) => data.get(k) ?? null,
    setItem: (k, v) => data.set(k, v),
    removeItem: (k) => data.delete(k),
  };
  const p = new Progress(storage);
  assert.equal(p.data.unlocked, 51);
  assert.equal(p.data.stars[50], 3);
  for (const c of chapters.slice(-5)) {
    const paint = paints.find((paint) => paint.requires === c.badge);
    assert.equal(paintUnlocked(paint, p.data), false);
    p.win(c.last, 500, 1800);
    assert.equal(paintUnlocked(paint, p.data), true);
  }
  assert.equal(p.selectPaint("starlight"), true);
  const restored = new Progress(storage);
  assert.equal(restored.data.unlocked, 100);
  assert.equal(restored.data.paint, "starlight");
  assert.ok(restored.data.cosmetics.includes("grand-circuit-hero"));
});
test("Machine definitions reject invalid forces, destinations, and unlinked plates", () => {
  for (const [id, type, field, value] of [
    [51, "portal", "to_x", NaN],
    [61, "gravity", "gy", Infinity],
    [71, "magnet", "radius", -1],
    [81, "launcher", "vx", NaN],
    [91, "plate", "channel", "missing"],
    [91, "plate", "required", 0],
  ]) {
    const l = structuredClone(levels[id - 1]);
    l.objects.find((o) => o.type === type)[field] = value;
    assert.equal(validateLevel(l), false);
  }
});
