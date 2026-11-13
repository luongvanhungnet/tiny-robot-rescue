import test from "node:test";
import assert from "node:assert/strict";
import { levels, validateLevel } from "../src/levels.js";
import { Simulation } from "../src/simulation.js";
const relay = levels.filter((l) => l.id >= 37 && l.id <= 40),
  run = (s) => {
    for (let i = 0; i < 1100 && s.state === "SIMULATING"; i++)
      s.step(1000 / 60);
  };
test("Relay Hub has four distinct challenges and no duplicated level definitions", () => {
  assert.equal(relay.length, 4);
  assert.equal(new Set(relay.map((l) => l.mechanic_id)).size, 4);
  const previous = new Set(
    levels
      .filter((l) => l.id < 37)
      .map((l) =>
        JSON.stringify({
          objects: l.objects,
          objective: l.objective,
          solution: l.solution,
        }),
      ),
  );
  for (const l of relay)
    assert.ok(
      !previous.has(
        JSON.stringify({
          objects: l.objects,
          objective: l.objective,
          solution: l.solution,
        }),
      ),
      l.title,
    );
});
test("All four Relay Hub solutions tolerate pointer sampling variation", () => {
  for (const l of relay)
    for (let i = 0; i < 12; i++) {
      const s = new Simulation(l),
        shift = ((i % 4) - 1.5) * 0.6,
        points = l.solution.map(([x, y]) => [
          x + shift,
          y + Math.floor(i / 4) * 0.3,
        ]);
      assert.equal(s.start(points), null);
      run(s);
      assert.equal(s.state, "WON", `${l.id}, ${i}: ${s.reason}`);
      s.destroy();
    }
});
test("Crosswind Cradle needs its cargo backstop as well as its beam shield", () => {
  const s = new Simulation(levels[36]);
  s.start([
    [180, 730],
    [180, 1020],
  ]);
  run(s);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /core/);
  s.destroy();
});
test("Ordered inspections reject the second ring before the first and ignore repeated visits", () => {
  const s = new Simulation(levels[37]);
  s.start(s.level.solution);
  const core = s.entities.find((b) => b.label === "cell"),
    rings = s.entities.filter((b) => b.label === "checkpoint");
  s.collide(rings[1], core);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /order/);
  s.destroy();
  const good = new Simulation(levels[37]);
  good.start(good.level.solution);
  const c = good.entities.find((b) => b.label === "cell"),
    r = good.entities.filter((b) => b.label === "checkpoint");
  good.collide(r[0], c);
  good.collide(r[0], c);
  good.collide(r[1], c);
  assert.equal(good.state, "SIMULATING");
  assert.deepEqual([...good.stamps.get(c.id)], ["scan", "stamp"]);
  good.destroy();
});
test("Upward Clearance cannot deliver by leaving out the backstop", () => {
  const s = new Simulation(levels[37]);
  s.start([
    [50, 400],
    [100, 400],
  ]);
  run(s);
  assert.equal(s.state, "LOST");
  assert.equal(s.delivered.size, 0);
  s.destroy();
});
test("Both beam planes need shielding, and the second emitter really pulses", () => {
  const l = levels[38];
  for (const stroke of [
    [
      [140, 650],
      [350, 650],
    ],
    [
      [590, 850],
      [590, 1014],
    ],
  ]) {
    const s = new Simulation(l);
    assert.equal(s.start(stroke), null);
    run(s);
    assert.equal(s.state, "LOST");
    assert.match(s.reason, /laser/);
    s.destroy();
  }
  const s = new Simulation(l);
  s.start(l.solution);
  const pulse = s.entities.find((b) => b.label === "laser" && b.plugin.period);
  for (let i = 0; i < 144; i++) s.step(1000 / 60);
  assert.equal(s.state, "SIMULATING");
  assert.equal(pulse.plugin.active, true);
  for (let i = 0; i < 84; i++) s.step(1000 / 60);
  assert.equal(pulse.plugin.active, false);
  for (let i = 0; i < 102; i++) s.step(1000 / 60);
  assert.equal(pulse.plugin.active, true);
  s.destroy();
});
test("Liftgate Express requires the bridge, delivery, and a functioning gate link", () => {
  const l = levels[39];
  for (const points of [
    [
      [238, 943],
      [482, 943],
    ],
    [
      [635, 340],
      [635, 915],
    ],
  ]) {
    const s = new Simulation(l);
    s.start(points);
    run(s);
    assert.equal(s.state, "LOST");
    s.destroy();
  }
  const broken = structuredClone(l);
  delete broken.objects.find((o) => o.type === "socket").trigger_action;
  const s = new Simulation(broken);
  s.start(s.level.solution);
  run(s);
  assert.equal(s.delivered.size, 1);
  assert.equal(s.goals.size, 0);
  assert.equal(s.state, "LOST");
  assert.match(s.reason, /charger/);
  s.destroy();
});
test("Cargo docking opens only the linked gate and does not win before robot arrival", () => {
  const l = structuredClone(levels[39]);
  l.objects.push({
    type: "gate",
    x: 60,
    y: 500,
    w: 20,
    h: 90,
    channel: "other",
  });
  const s = new Simulation(l);
  s.start(s.level.solution);
  const core = s.entities.find((b) => b.label === "cell"),
    socket = s.entities.find((b) => b.label === "socket");
  s.stamps.set(core.id, new Set(["scan", "stamp"]));
  s.collide(socket, core);
  s.step(1000 / 60);
  assert.equal(s.state, "SIMULATING");
  assert.equal(
    s.entities.find((b) => b.label === "gate" && b.plugin.channel === "freight")
      .plugin.open,
    true,
  );
  assert.notEqual(
    s.entities.find((b) => b.label === "gate" && b.plugin.channel === "other")
      .plugin.open,
    true,
  );
  s.destroy();
});
test("Invalid route and gate link metadata is rejected", () => {
  const l = structuredClone(levels[39]);
  l.objects.find((o) => o.type === "cell").route = ["scan", "scan"];
  assert.equal(validateLevel(l), false);
  const other = structuredClone(levels[39]);
  other.objects.find((o) => o.type === "socket").gate_channel = "missing";
  assert.equal(validateLevel(other), false);
});
