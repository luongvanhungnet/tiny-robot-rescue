import { test, expect } from "@playwright/test";
import { levels } from "../../src/levels.js";
async function press(locator, mobile) {
  if (mobile) await locator.tap();
  else await locator.click();
}
async function stroke(page, points, mobile) {
  const box = await page.locator("canvas").boundingBox(),
    coords = points.map(([x, y]) => ({
      x: box.x + (x * box.width) / 720,
      y: box.y + (y * box.height) / 1280,
    }));
  if (mobile) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchStart",
      touchPoints: [coords[0]],
    });
    for (let k = 1; k < coords.length; k++)
      for (let i = 1; i <= 20; i++) {
        const a = coords[k - 1],
          b = coords[k];
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchMove",
          touchPoints: [
            {
              x: a.x + ((b.x - a.x) * i) / 20,
              y: a.y + ((b.y - a.y) * i) / 20,
            },
          ],
        });
      }
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchEnd",
      touchPoints: [],
    });
  } else {
    await page.mouse.move(coords[0].x, coords[0].y);
    await page.mouse.down();
    for (const p of coords.slice(1))
      await page.mouse.move(p.x, p.y, { steps: 20 });
    await page.mouse.up();
  }
}
test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__rescue?.screen === "home");
});
test("Hint draws an animated nonphysical example and the player still draws their own stroke", async ({
  page,
}, info) => {
  const mobile = info.project.name === "mobile";
  await press(page.getByRole("button", { name: /LET’S RESCUE/ }), mobile);
  const before = await page.evaluate(() => ({
    bodies: window.__rescue.sim.engine.world.bodies.length,
    attempts: window.__rescue.progress.data.attempts[1] ?? 0,
  }));
  await press(page.locator(".hintbtn"), mobile);
  await expect(page.locator(".hintbtn")).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  await expect(page.locator(".instruction")).toContainText(
    "draw the dashed path yourself",
  );
  expect(await page.evaluate(() => window.__rescue.hint.points)).toEqual(
    levels[0].solution,
  );
  await page.waitForFunction(
    () => window.__rescue.hint.elapsed >= window.__rescue.hint.duration,
  );
  expect(
    await page.evaluate(() => ({
      bodies: window.__rescue.sim.engine.world.bodies.length,
      attempts: window.__rescue.progress.data.attempts[1] ?? 0,
    })),
  ).toEqual(before);
  expect(
    await page.evaluate(() => [
      window.__rescue.sim.state,
      window.__rescue.sim.elapsed,
      window.__rescue.sim.stroke.length,
    ]),
  ).toEqual(["READY", 0, 0]);
  await expect(page.locator("#ink-value")).toHaveText("100%");
  await page.screenshot({
    path: `test-results/example-line-${info.project.name}.png`,
  });
  await stroke(page, levels[0].solution, mobile);
  await page.waitForFunction(() => window.__rescue.sim.state === "SIMULATING");
  expect(await page.evaluate(() => window.__rescue.hint.active)).toBe(false);
  await expect(page.locator(".hintbtn")).toHaveText("Retry + hint");
  await press(page.locator(".hintbtn"), mobile);
  expect(
    await page.evaluate(() => [
      window.__rescue.sim.state,
      window.__rescue.sim.elapsed,
      window.__rescue.hint.active,
    ]),
  ).toEqual(["READY", 0, true]);
  await press(page.getByRole("button", { name: "Retry level" }), mobile);
  expect(await page.evaluate(() => window.__rescue.hint.active)).toBe(false);
});
test("Reduced-motion examples show the whole multi-corner route and can be hidden", async ({
  page,
}, info) => {
  const mobile = info.project.name === "mobile";
  await page.evaluate(() => {
    window.__rescue.progress.data.settings.reducedMotion = true;
    window.__rescue.startLevel(50);
  });
  await press(page.locator(".hintbtn"), mobile);
  expect(await page.evaluate(() => window.__rescue.hint.path)).toEqual(
    levels[49].solution,
  );
  await press(page.locator(".hintbtn"), mobile);
  expect(await page.evaluate(() => window.__rescue.hint.active)).toBe(false);
  await page.evaluate(() => window.__rescue.startLevel(37));
  await press(page.locator(".hintbtn"), mobile);
  expect(await page.evaluate(() => window.__rescue.hint.points)).toEqual(
    levels[36].solution,
  );
  await press(
    page.getByRole("button", { name: "Level select", exact: true }),
    mobile,
  );
  expect(await page.evaluate(() => window.__rescue.hint.active)).toBe(false);
});
test("A lost-result hint returns to planning with a visible example", async ({
  page,
}, info) => {
  const mobile = info.project.name === "mobile";
  await press(page.getByRole("button", { name: /LET’S RESCUE/ }), mobile);
  await stroke(
    page,
    [
      [50, 400],
      [100, 400],
    ],
    mobile,
  );
  await expect(
    page.getByRole("heading", { name: "A tiny setback." }),
  ).toBeVisible({ timeout: 15000 });
  await press(
    page.getByRole("button", { name: "A little hint", exact: true }),
    mobile,
  );
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(
    await page.evaluate(() => [
      window.__rescue.sim.state,
      window.__rescue.hint.active,
    ]),
  ).toEqual(["READY", true]);
});
test("Level 37 alternative backstop wins without wind pushing Pip off at the last second", async ({
  page,
}, info) => {
  const mobile = info.project.name === "mobile";
  await page.evaluate(() => window.__rescue.startLevel(37));
  await stroke(
    page,
    [
      [630, 680],
      [630, 1020],
    ],
    mobile,
  );
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible({ timeout: 15000 });
  expect(await page.evaluate(() => window.__rescue.sim.delivered.size)).toBe(1);
  const robot = await page.evaluate(
    () =>
      window.__rescue.sim.entities.find((b) => b.label === "robot").position,
  );
  expect(robot.x).toBeLessThan(135);
  expect(robot.y).toBeLessThan(950);
});
