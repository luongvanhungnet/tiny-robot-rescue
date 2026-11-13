import test from "node:test";
import assert from "node:assert/strict";
import { levels, validateLevel } from "../src/levels.js";
import { Simulation } from "../src/simulation.js";
import { validateStroke, length, simplify } from "../src/stroke.js";
import { Progress, SAVE_KEY } from "../src/save.js";
import { ads, billing } from "../src/services.js";
const run = (s) => {
  for (let i = 0; i < 1000 && s.state === "SIMULATING"; i++) s.step(1000 / 60);
};
for (const level of levels)
  test(`Level ${level.id}: authored solution wins in real Matter.js physics`, () => {
    assert.ok(validateLevel(level));
    const s = new Simulation(level);
    assert.equal(s.start(level.solution), null);
    assert.equal(s.state, "SIMULATING");
    run(s);
    assert.equal(s.state, "WON", s.reason);
    assert.ok(s.elapsed > 0);
    if (level.objective.type === "switch")
      assert.equal(s.activated.size, level.objective.required_switches);
    if (level.objective.type === "delivery")
      assert.equal(s.delivered.size, level.objective.required_cells);
    if (level.objective.type === "exit")
      assert.equal(
        s.goals.size,
        level.objects.filter((o) => o.type === "robot").length,
      );
    s.destroy();
  });
test("Unprotected robots are hit: failure is real, not an automatic countdown win", () => {
  for (const id of levels.map((level) => level.id)) {
    const s = new Simulation(levels[id - 1]);
    assert.equal(
      s.start([
        [50, 400],
        [100, 400],
      ]),
      null,
    );
    run(s);
    assert.equal(s.state, "LOST", `Level ${id} should lose`);
    assert.match(
      s.reason,
      /Hit|fell|waiting|switch|laser|dock|inspection|core/,
    );
    s.destroy();
  }
});
test("Drawing rejects short, infinite, duplicate, self-crossing, out-of-ink and forbidden strokes", () => {
  const l = levels[0];
  for (const pts of [
    [],
    [[200, 500]],
    [
      [200, 500],
      [200, 500],
    ],
    [
      [200, 500],
      [Infinity, 600],
    ],
    [
      [0, 300],
      [20, 400],
    ],
    [
      [330, 1018],
      [390, 1018],
    ],
    [
      [100, 1050],
      [600, 1050],
    ],
    [
      [50, 500],
      [650, 500],
    ],
    [
      [200, 500],
      [400, 700],
      [200, 700],
      [400, 500],
    ],
  ])
    assert.ok(validateStroke(pts, l));
  assert.ok(
    validateStroke(
      [
        [100, 500],
        [200, 500],
      ],
      { ...l, forbidden_zones: [[150, 480, 10, 40]] },
    ),
  );
  assert.ok(
    validateStroke(
      [
        [100, 500],
        [200, 500],
      ],
      { ...l, objects: [{ type: "platform", x: 150, y: 500, w: 2, h: 100 }] },
    ),
  );
  assert.equal(validateStroke(l.solution, l), null);
});
test("Simplification preserves corners and endpoints, removes redundant touch samples", () => {
  const pts = [
    [0, 0],
    [1, 0],
    [2, 0],
    [50, 0],
    [50, 40],
  ];
  assert.deepEqual(simplify(pts), [
    [0, 0],
    [50, 0],
    [50, 40],
  ]);
  assert.equal(length(simplify(pts)), 90);
});
test("Planning and pauses do not consume the simulation timer; second stroke rejected; restart resets", () => {
  const s = new Simulation(levels[0]);
  s.step(10000);
  assert.equal(s.elapsed, 0);
  s.state = "DRAWING";
  s.step(10000);
  assert.equal(s.elapsed, 0);
  s.start(s.level.solution);
  assert.ok(s.start(s.level.solution));
  s.step(1000 / 60);
  assert.ok(s.elapsed > 0);
  s.destroy();
  const fresh = new Simulation(levels[0]);
  assert.equal(fresh.state, "READY");
  assert.equal(fresh.elapsed, 0);
  assert.equal(fresh.stroke.length, 0);
  assert.equal(fresh.activated.size, 0);
  fresh.destroy();
});
const memory = () => {
  const m = new Map();
  return {
    getItem: (k) => m.get(k) ?? null,
    setItem: (k, v) => m.set(k, v),
    removeItem: (k) => m.delete(k),
  };
};
test("Winning unlocks progress; retries preserve best stars/ink; settings and attempts persist", () => {
  const store = memory(),
    p = new Progress(store);
  p.attempt(1);
  assert.equal(p.win(1, 200, 480), 3);
  p.win(1, 450, 480);
  p.data.settings.sound = false;
  p.save();
  const next = new Progress(store);
  assert.equal(next.data.unlocked, 2);
  assert.equal(next.data.stars[1], 3);
  assert.equal(next.data.bestInk[1], 200);
  assert.equal(next.data.attempts[1], 1);
  assert.equal(next.data.settings.sound, false);
});
test("Corrupt/interrupted writes recover from backup, migrate and sanitize invalid data", () => {
  const store = memory(),
    p = new Progress(store);
  p.win(1, 200, 480);
  p.save();
  store.setItem(SAVE_KEY, "{broken");
  store.setItem(SAVE_KEY + ".pending", "{partial");
  assert.equal(new Progress(store).data.unlocked, 2);
  store.setItem(
    SAVE_KEY,
    JSON.stringify({
      unlocked_level: 4,
      last_selected_level: 3,
      stars: { 1: 999 },
      settings: { sound: "bad" },
    }),
  );
  const migrated = new Progress(store);
  assert.equal(migrated.data.unlocked, 4);
  assert.equal(migrated.data.stars[1], 3);
  assert.equal(migrated.data.settings.sound, true);
});
test("Denied storage never crashes gameplay", () => {
  const p = new Progress({
    getItem() {
      throw Error("blocked");
    },
    setItem() {
      throw Error("quota");
    },
    removeItem() {},
  });
  p.win(1, 200, 480);
  assert.equal(p.persistent, false);
  assert.equal(p.data.unlocked, 2);
});
test("No monetization path invents purchases or blocks play offline", async () => {
  assert.equal((await ads.showRewarded()).rewarded, false);
  assert.equal(await ads.showInterstitial(), false);
  assert.equal((await billing.purchase()).purchased, false);
  assert.deepEqual(await billing.restore(), []);
});

test("Existing completed campaigns unlock new content without losing progress", () => {
  const store = memory();
  store.setItem(
    SAVE_KEY,
    JSON.stringify({
      version: 1,
      unlocked: 10,
      lastLevel: 10,
      stars: { 1: 3, 10: 2 },
      bestInk: { 10: 423 },
      settings: { sound: false },
      cosmetics: ["workshop-hero"],
    }),
  );
  const p = new Progress(store);
  assert.equal(p.data.unlocked, 11);
  assert.equal(p.data.stars[1], 3);
  assert.equal(p.data.bestInk[10], 423);
  assert.equal(p.data.settings.sound, false);
  p.win(11, 300, 580);
  const reload = new Progress(store);
  assert.equal(reload.data.unlocked, 12);
  assert.ok(reload.data.stars[11] > 0);
  p.win(20, 423, 470);
  assert.ok(p.data.cosmetics.includes("foundry-hero"));
  assert.equal(new Progress(store).data.unlocked, 21);
});

test("Foundry finale tolerates small pointer sampling differences", () => {
  const l = levels[19];
  for (let i = 0; i < 40; i++) {
    const shift = ((i % 10) - 5) * 0.4;
    const stroke = l.solution.map(([x, y], j) => [
      x + shift,
      y + ((i % 4) - 2) * 0.3 * (j ? 1 : -1),
    ]);
    const sim = new Simulation(l);
    assert.equal(sim.start(stroke), null);
    run(sim);
    assert.equal(sim.state, "WON", `Sample variant ${i}: ${sim.reason}`);
    sim.destroy();
  }
});

test("Skyworks solutions tolerate small drawing differences", () => {
  for (const level of levels.filter((l) => l.id >= 21 && l.id <= 30))
    for (let i = 0; i < 12; i++) {
      const shift = ((i % 4) - 1.5) * 0.6;
      const points = level.solution.map(([x, y]) => [
        x + shift,
        y + Math.floor(i / 4) * 0.3,
      ]);
      const s = new Simulation(level);
      assert.equal(s.start(points), null);
      run(s);
      assert.equal(s.state, "WON", `${level.id}, variant ${i}: ${s.reason}`);
      s.destroy();
    }
});
test("Chapter paints are earned, selectable, and preserved across old-save migration", () => {
  const store = memory(),
    p = new Progress(store);
  assert.equal(p.selectPaint("violet"), false);
  assert.equal(p.selectPaint("unknown"), false);
  p.win(10, 100, 500);
  assert.equal(p.selectPaint("copper"), true);
  p.win(20, 100, 500);
  assert.equal(p.selectPaint("violet"), true);
  const reloaded = new Progress(store);
  assert.equal(reloaded.data.unlocked, 21);
  assert.equal(reloaded.data.paint, "violet");
  p.win(30, 100, 500);
  assert.ok(p.data.cosmetics.includes("skyworks-hero"));
  assert.equal(p.selectPaint("rose"), true);
  assert.equal(new Progress(store).data.paint, "rose");
  store.setItem(
    SAVE_KEY,
    JSON.stringify({
      version: 1,
      unlocked: 20,
      lastLevel: 20,
      stars: { 10: 3, 20: 2 },
      paint: "rose",
    }),
  );
  const old = new Progress(store);
  assert.equal(old.data.unlocked, 21);
  assert.equal(old.data.paint, "aqua");
  assert.ok(old.data.cosmetics.includes("foundry-hero"));
});
