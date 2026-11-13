import { test, expect } from "@playwright/test";
import { levels } from "../../src/levels.js";

async function draw(page, points, mobile) {
  const box = await page.locator("canvas").boundingBox();
  const xy = ([x, y]) => ({
    x: box.x + (x * box.width) / 720,
    y: box.y + (y * box.height) / 1280,
  });
  if (mobile) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchStart",
      touchPoints: [xy(points[0])],
    });
    for (let k = 1; k < points.length; k++)
      for (let i = 1; i <= 25; i++) {
        const a = xy(points[k - 1]),
          b = xy(points[k]);
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchMove",
          touchPoints: [
            {
              x: a.x + ((b.x - a.x) * i) / 25,
              y: a.y + ((b.y - a.y) * i) / 25,
            },
          ],
        });
      }
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchEnd",
      touchPoints: [],
    });
    await cdp.detach();
  } else {
    const p = xy(points[0]);
    await page.mouse.move(p.x, p.y);
    await page.mouse.down();
    for (const point of points.slice(1)) {
      const q = xy(point);
      await page.mouse.move(q.x, q.y, { steps: 25 });
    }
    await page.mouse.up();
  }
}
test("New chapter machinery, instructions, hints and all five real-input rescues work", async ({
  page,
}, info) => {
  test.setTimeout(150000);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await page.waitForFunction(() => window.__rescue?.screen === "home");
  const mobile = info.project.name === "mobile";
  for (const id of [51, 61, 71, 81, 91, 100]) {
    await page.evaluate((id) => window.__rescue.startLevel(id), id);
    await expect(
      page.getByRole("heading", { name: levels[id - 1].title, exact: true }),
    ).toBeVisible();
    const help = page.getByRole("button", { name: "Machines", exact: true });
    if (mobile) await help.tap();
    else await help.click();
    await expect(
      page.getByRole("heading", { name: "Meet the machines." }),
    ).toBeVisible();
    const before = await page.evaluate(() => window.__rescue.sim.elapsed);
    await page.waitForTimeout(150);
    expect(await page.evaluate(() => window.__rescue.sim.elapsed)).toBe(before);
    await page.getByRole("button", { name: "Back to the rescue" }).click();
    const hint = page.locator(".hintbtn");
    if (mobile) await hint.tap();
    else await hint.click();
    await page.waitForFunction(
      () => window.__rescue.hint.elapsed >= window.__rescue.hint.duration,
    );
    await page.screenshot({
      path: `test-results/machinery-${id}-${info.project.name}.png`,
    });
    await draw(page, levels[id - 1].solution, mobile);
    await expect(
      page.getByRole("heading", {
        name: id === 100 ? "Workshop rescued!" : "Little robot. Big relief.",
      }),
    ).toBeVisible({ timeout: 20000 });
    expect(
      await page.evaluate(() => window.__rescue.sim.usedMachines.size),
    ).toBeGreaterThan(0);
  }
  expect(errors).toEqual([]);
});
test("A completed 50-level save continues into Portal Post and retains its paint and badge", async ({
  page,
}) => {
  await page.addInitScript(() => {
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: 50,
        lastLevel: 50,
        stars: { 50: 3, 30: 3 },
        paint: "rose",
        cosmetics: ["grand-circuit-hero", "skyworks-hero"],
      }),
    );
  });
  await page.goto("/");
  await page.getByRole("button", { name: "Levels", exact: false }).click();
  await expect(page.locator(".level-card")).toHaveCount(100);
  await expect(page.locator('[data-level="51"]')).toBeEnabled();
  await expect(page.locator('[data-level="52"]')).toBeDisabled();
  expect(await page.evaluate(() => window.__rescue.progress.data.paint)).toBe(
    "rose",
  );
  await page.locator('[data-level="51"]').click();
  await expect(
    page.getByRole("heading", { name: "Through the Looking Glass" }),
  ).toBeVisible();
});
