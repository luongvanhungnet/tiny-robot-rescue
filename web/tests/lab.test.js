import test from "node:test";
import assert from "node:assert/strict";
import Matter from "matter-js";
import { levels, validateLevel } from "../src/levels.js";
import { Simulation } from "../src/simulation.js";
import { traceBeam } from "../src/optics.js";
const lab = levels.filter((l) => l.id >= 31 && l.id <= 36),
  run = (s) => {
    for (let i = 0; i < 1000 && s.state === "SIMULATING"; i++)
      s.step(1000 / 60);
  };
test("Power Lab adds six distinct mechanic goals and no reused layouts", () => {
  assert.equal(lab.length, 6);
  assert.equal(new Set(lab.map((l) => l.mechanic_id)).size, 6);
  const signatures = new Set();
  for (const l of levels) {
    const signature = JSON.stringify({
      objects: l.objects,
      objective: l.objective,
      solution: l.solution,
    });
    assert.ok(!signatures.has(signature), l.title);
    signatures.add(signature);
  }
  assert.ok(
    lab.every((l) => l.objects.some((o) => ["cell", "laser"].includes(o.type))),
  );
});
test("Every Power Lab solution tolerates pointer sampling variations", () => {
  for (const l of lab)
    for (let i = 0; i < 12; i++) {
      const shift = ((i % 4) - 1.5) * 0.6,
        stroke = l.solution.map(([x, y]) => [
          x + shift,
          y + Math.floor(i / 4) * 0.3,
        ]);
      const s = new Simulation(l);
      assert.equal(s.start(stroke), null);
      run(s);
      assert.equal(s.state, "WON", `${l.title}, variation ${i}: ${s.reason}`);
      s.destroy();
    }
});
test("A fan changes the cargo path and is required for Air Freight", () => {
  const l = structuredClone(levels[31]);
  l.objects = l.objects.filter((o) => o.type !== "fan");
  const s = new Simulation(l);
  s.start(l.solution);
  run(s);
  assert.equal(s.state, "LOST");
  assert.equal(s.delivered.size, 0);
  s.destroy();
});
test("Laser rays stop at the nearest rotated ink surface, independent of body order", () => {
  const ink = Matter.Bodies.rectangle(150, 100, 20, 100, { angle: 0.2 }),
    robot = Matter.Bodies.rectangle(250, 100, 40, 50);
  const hit = traceBeam({ x: 0, y: 100 }, { x: 400, y: 100 }, [robot, ink]);
  assert.equal(hit.body, ink);
  assert.ok(hit.x < 150);
  assert.equal(
    traceBeam({ x: 0, y: 200 }, { x: 400, y: 200 }, [robot, ink]).body,
    null,
  );
});
test("Planning, pauses, warmup, and ink all respect laser timing", () => {
  const l = levels[32],
    s = new Simulation(l);
  s.step(9000);
  assert.equal(s.state, "READY");
  assert.equal(s.elapsed, 0);
  s.start([
    [50, 400],
    [100, 400],
  ]);
  for (let n = 0; n < 30; n++) s.step(1000 / 60);
  assert.equal(s.state, "SIMULATING");
  assert.equal(
    s.entities.find((b) => b.label === "laser").plugin.active,
    false,
  );
  run(s);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /laser/);
  s.destroy();
  const shield = new Simulation(l);
  shield.start(l.solution);
  run(shield);
  assert.equal(shield.state, "WON");
  assert.ok(
    shield.entities.find((b) => b.label === "laser").plugin.beamEnd.x < 400,
  );
  shield.destroy();
});
test("A delivered core never kills Pip or pays out twice", () => {
  const l = levels[30],
    s = new Simulation(l);
  s.start(l.solution);
  const cell = s.entities.find((b) => b.label === "cell"),
    socket = s.entities.find((b) => b.label === "socket"),
    robot = s.entities.find((b) => b.label === "robot");
  s.collide(robot, cell);
  assert.equal(s.state, "SIMULATING");
  s.collide(socket, cell);
  s.collide(socket, cell);
  assert.equal(s.delivered.size, 1);
  assert.equal(cell.isStatic, true);
  assert.equal(cell.label, "delivered");
  s.destroy();
});
test("Color Dispatch rejects wrong colors, not merely any cargo in either dock", () => {
  const l = structuredClone(levels[34]);
  l.objects
    .filter((o) => o.type === "socket")
    .forEach((o) => (o.accepts = o.accepts === "cyan" ? "amber" : "cyan"));
  const s = new Simulation(l);
  s.start(l.solution);
  run(s);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /other dock/);
  s.destroy();
});
test("Inspection stamps are per core and required before delivery", () => {
  const s = new Simulation(levels[35]);
  s.start(s.level.solution);
  const cell = s.entities.find((b) => b.label === "cell"),
    socket = s.entities.find((b) => b.label === "socket");
  s.collide(socket, cell);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /inspection/);
  assert.equal(s.delivered.size, 0);
  s.destroy();
  const good = new Simulation(levels[35]);
  good.start(good.level.solution);
  run(good);
  assert.equal(good.state, "WON");
  assert.ok(
    [...good.stamps.values()].some((stamps) => stamps.has("inspection")),
  );
  good.destroy();
});
test("Shield and Ship still requires survival after cargo arrives", () => {
  const s = new Simulation(levels[33]);
  s.start([
    [50, 400],
    [100, 400],
  ]);
  const cell = s.entities.find((b) => b.label === "cell"),
    socket = s.entities.find((b) => b.label === "socket");
  s.collide(socket, cell);
  s.step(1000 / 60);
  assert.equal(s.state, "SIMULATING");
  run(s);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /laser/);
  s.destroy();
});
test("Invalid mechanic data is rejected during level validation", () => {
  const l = structuredClone(levels[32]);
  l.objects.find((o) => o.type === "laser").to_x = NaN;
  assert.equal(validateLevel(l), false);
  const d = structuredClone(levels[30]);
  d.objective.required_cells = 3;
  assert.equal(validateLevel(d), false);
});

test("New content has distinct mechanical requirements, not reflected copies of existing puzzles", () => {
  const fingerprint = (l) =>
    JSON.stringify({
      goal: l.objective.type,
      cells: l.objects.filter((o) => o.type === "cell").length,
      fans: l.objects.filter((o) => o.type === "fan").length,
      lasers: l.objects.filter((o) => o.type === "laser").length,
      rings: l.objects.filter((o) => o.type === "checkpoint").length,
      colors: new Set(
        l.objects.filter((o) => o.type === "socket").map((o) => o.accepts),
      ).size,
    });
  const previous = new Set(levels.filter((l) => l.id < 31).map(fingerprint)),
    seen = new Set();
  for (const l of lab) {
    const key = fingerprint(l);
    assert.ok(!previous.has(key), l.title);
    assert.ok(!seen.has(key), l.title);
    seen.add(key);
  }
});
test("Inspection stamps are not shared between separate cargo cores", () => {
  const l = structuredClone(levels[35]);
  l.objects.push({ type: "cell", x: 300, y: 350, channel: "cyan" });
  const s = new Simulation(l);
  s.start(l.solution);
  const [first, second] = s.entities.filter((b) => b.label === "cell"),
    ring = s.entities.find((b) => b.label === "checkpoint"),
    socket = s.entities.find((b) => b.label === "socket");
  s.collide(ring, first);
  assert.ok(s.stamps.get(first.id).has("inspection"));
  s.collide(socket, second);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /inspection/);
  s.destroy();
});
