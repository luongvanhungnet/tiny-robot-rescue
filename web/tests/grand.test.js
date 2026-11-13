import { validateStroke } from "../src/stroke.js";
import test from "node:test";
import assert from "node:assert/strict";
import { levels, LEVEL_COUNT } from "../src/levels.js";
import { Simulation } from "../src/simulation.js";
import { Progress } from "../src/save.js";
const grand = levels.filter((l) => l.id >= 41),
  run = (s) => {
    for (let i = 0; i < 1100 && s.state === "SIMULATING"; i++)
      s.step(1000 / 60);
  };
test("Campaign reaches exactly 50 ordered levels with ten distinct Grand Circuit challenges", () => {
  assert.equal(LEVEL_COUNT, 50);
  assert.deepEqual(
    levels.map((l) => l.id),
    Array.from({ length: 50 }, (_, i) => i + 1),
  );
  assert.equal(grand.length, 10);
  assert.equal(new Set(grand.map((l) => l.mechanic_id)).size, 10);
  const signatures = new Set();
  for (const l of levels) {
    const key = JSON.stringify({
      objects: l.objects,
      objective: l.objective,
      solution: l.solution,
    });
    assert.ok(!signatures.has(key), l.title);
    signatures.add(key);
  }
  const mechanics = new Set();
  for (const l of grand) {
    const count = (type) => l.objects.filter((o) => o.type === type).length,
      robot = l.objects.find((o) => o.type === "robot"),
      goal = l.objects.find((o) => o.type === "goal");
    const key = JSON.stringify({
      goal: l.objective.type,
      robots: count("robot"),
      cargo: count("cell"),
      fans: count("fan"),
      rings: count("checkpoint"),
      beams: count("laser"),
      gates: count("gate"),
      rise: goal ? Math.abs(goal.y - robot.y) : 0,
    });
    assert.ok(!mechanics.has(key), l.title);
    mechanics.add(key);
  }
});
test("All ten new levels tolerate small mouse and touch sampling differences", () => {
  for (const l of grand)
    for (let i = 0; i < 12; i++) {
      const s = new Simulation(l),
        shift = ((i % 4) - 1.5) * 0.6,
        points = l.solution.map(([x, y]) => [
          x + shift,
          y + Math.floor(i / 4) * 0.3,
        ]);
      assert.equal(s.start(points), null);
      run(s);
      assert.equal(s.state, "WON", `${l.id}, variant ${i}: ${s.reason}`);
      s.destroy();
    }
});
test("Opposing Currents needs a stop for each cargo lane", () => {
  for (const points of [
    [
      [55, 500],
      [55, 1020],
    ],
    [
      [665, 500],
      [665, 1020],
    ],
  ]) {
    const s = new Simulation(levels[40]);
    s.start(points);
    run(s);
    assert.equal(s.state, "LOST");
    assert.ok(s.delivered.size < 2);
    s.destroy();
  }
});
test("Robot lifts are required, and each crossing needs its authored shield", () => {
  for (const id of [45, 46]) {
    const original = levels[id - 1],
      l = structuredClone(original);
    l.objects = l.objects.filter((o) => o.type !== "fan");
    const noLift = new Simulation(l);
    noLift.start(l.solution);
    run(noLift);
    assert.equal(noLift.state, "LOST", `Level ${id} must need its lift`);
    noLift.destroy();
    const exposed = new Simulation(original);
    exposed.start([
      [50, 400],
      [100, 400],
    ]);
    run(exposed);
    assert.equal(exposed.state, "LOST");
    assert.match(exposed.reason, /laser/);
    exposed.destroy();
  }
  const s = new Simulation(levels[42]);
  s.start([
    [238, 943],
    [300, 915],
    [650, 915],
  ]);
  run(s);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /laser/);
  s.destroy();
});
test("Receiving Stack waits for both docks and its upper delivery gate link", () => {
  const l = structuredClone(levels[46]);
  delete l.objects.find((o) => o.type === "socket" && o.trigger_action)
    .trigger_action;
  const s = new Simulation(l);
  s.start(l.solution);
  run(s);
  assert.equal(s.delivered.size, 2);
  assert.equal(s.goals.size, 0);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /charger/);
  s.destroy();
});
test("Split Inspection requires the stamp belonging to each cargo lane", () => {
  const l = structuredClone(levels[47]);
  l.objects
    .filter((o) => o.type === "cell")
    .forEach((o) => (o.route = o.channel === "cyan" ? ["right"] : ["left"]));
  const s = new Simulation(l);
  s.start(l.solution);
  run(s);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /inspection/);
  s.destroy();
});
test("Level 50 completes two deliveries, both robot rescues, and a persistent final badge", () => {
  const s = new Simulation(levels[49]);
  s.start(s.level.solution);
  run(s);
  assert.equal(s.state, "WON");
  assert.equal(s.delivered.size, 2);
  assert.equal(s.goals.size, 2);
  assert.equal(s.stamps.size, 2);
  for (const stamps of s.stamps.values())
    assert.deepEqual([...stamps], ["scan", "weigh", "stamp"]);
  s.destroy();
  const data = new Map(),
    store = {
      getItem: (k) => data.get(k) ?? null,
      setItem: (k, v) => data.set(k, v),
      removeItem: (k) => data.delete(k),
    };
  const p = new Progress(store);
  p.win(50, 900, 1050);
  const saved = new Progress(store);
  assert.equal(saved.data.unlocked, 50);
  assert.ok(saved.data.cosmetics.includes("grand-circuit-hero"));
});

test("Draw-zone edges tolerate floating-point noise while rejecting genuinely outside strokes", () => {
  const l = levels[0];
  assert.equal(
    validateStroke(
      [
        [200, 300 - 1e-8],
        [300, 300 - 1e-8],
      ],
      l,
    ),
    null,
  );
  assert.ok(
    validateStroke(
      [
        [200, 299.9],
        [300, 299.9],
      ],
      l,
    ),
  );
  assert.ok(
    levels[49].solution.every((p) => p[1] > 300),
    "The finale must allow room for browser pointer quantization",
  );
});
