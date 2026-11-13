import test from "node:test";
import assert from "node:assert/strict";
import { HintGuide, partialPath, dashedPath } from "../src/hint.js";
import { levels } from "../src/levels.js";
import { Simulation } from "../src/simulation.js";

test("Example path follows length through corners instead of cutting diagonally", () => {
  const p = [
    [0, 0],
    [60, 0],
    [60, 40],
  ];
  assert.deepEqual(partialPath(p, 0.8), [
    [0, 0],
    [60, 0],
    [60, 20],
  ]);
  assert.deepEqual(partialPath(p, 0), [[0, 0]]);
  assert.deepEqual(partialPath(p, 1), p);
});
test("Dashed guide keeps its spacing when crossing corners", () => {
  const segments = dashedPath(
    [
      [0, 0],
      [20, 0],
      [20, 30],
    ],
    16,
    11,
  );
  assert.deepEqual(segments, [
    [
      [0, 0],
      [16, 0],
    ],
    [
      [20, 7],
      [20, 23],
    ],
  ]);
});
test("Guide animation copies its example, supports reduced motion, and clears cleanly", () => {
  const input = [
      [10, 10],
      [100, 10],
    ],
    guide = new HintGuide();
  guide.show(input);
  input[0][0] = 99;
  assert.equal(guide.points[0][0], 10);
  guide.advance(900);
  assert.equal(guide.path.at(-1)[0], 55);
  guide.advance(900);
  assert.deepEqual(guide.path, [
    [10, 10],
    [100, 10],
  ]);
  guide.hide();
  assert.equal(guide.active, false);
  assert.deepEqual(guide.path, []);
  guide.show(
    [
      [10, 10],
      [100, 10],
    ],
    true,
  );
  assert.equal(guide.path.at(-1)[0], 100);
});
test("Every level supplies a complete example and showing it does not start physics", () => {
  for (const level of levels) {
    const guide = new HintGuide(),
      sim = new Simulation(level);
    guide.show(level.solution, true);
    assert.deepEqual(guide.path, level.solution);
    assert.notEqual(guide.points, level.solution);
    assert.equal(sim.state, "READY");
    assert.equal(sim.elapsed, 0);
    assert.equal(sim.stroke.length, 0);
    sim.destroy();
  }
});
test("Level 37 cargo wind cannot blow Pip off the platform just before seven seconds", () => {
  const sim = new Simulation(levels[36]);
  assert.equal(
    sim.start([
      [630, 680],
      [630, 1020],
    ]),
    null,
  );
  for (let i = 0; i < 480 && sim.state === "SIMULATING"; i++) {
    sim.step(1000 / 60);
    const robot = sim.entities.find((b) => b.label === "robot");
    assert.ok(robot.position.x < 135);
    assert.ok(robot.position.y < 950);
  }
  assert.equal(sim.state, "WON");
  assert.equal(sim.delivered.size, 1);
  assert.ok(sim.elapsed >= 7);
  sim.destroy();
});
