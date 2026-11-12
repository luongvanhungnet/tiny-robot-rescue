import { test, expect } from "@playwright/test";
test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__rescue?.screen === "home");
});
async function draw(page, points, touch = false) {
  const box = await page.locator("canvas").boundingBox();
  const coords = points.map(([x, y]) => ({
    x: box.x + (x * box.width) / 720,
    y: box.y + (y * box.height) / 1280,
  }));
  if (touch) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchStart",
      touchPoints: [coords[0]],
    });
    for (let i = 1; i <= 20; i++) {
      const a = coords[0],
        b = coords.at(-1);
      await cdp.send("Input.dispatchTouchEvent", {
        type: "touchMove",
        touchPoints: [
          { x: a.x + ((b.x - a.x) * i) / 20, y: a.y + ((b.y - a.y) * i) / 20 },
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
test("Home → real drawn rescue → next level → progress survives reload", async ({
  page,
}, info) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
  await expect(
    page.getByRole("heading", { name: "First Shield" }),
  ).toBeVisible();
  await draw(
    page,
    [
      [260, 700],
      [460, 700],
    ],
    info.project.name === "mobile",
  );
  await page.waitForFunction(() => window.__rescue.sim.state === "SIMULATING");
  await expect(page.getByRole("dialog")).toBeVisible({ timeout: 30000 });
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Next little adventure" }).click();
  await expect(
    page.getByRole("heading", { name: "Side Impact" }),
  ).toBeVisible();
  await page.reload();
  await page.getByRole("button", { name: "Levels", exact: false }).click();
  await expect(
    page.getByRole("button", { name: "Level 2: Side Impact" }),
  ).toBeEnabled();
  await expect(
    page.getByRole("button", { name: "Level 3: Bouncy Surprise, locked" }),
  ).toBeDisabled();
  expect(errors).toEqual([]);
});
test("Invalid strokes, pause, retry and settings work", async ({ page }) => {
  await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
  await draw(page, [
    [330, 1018],
    [390, 1018],
  ]);
  await expect(page.getByRole("status")).toHaveText("Give Pip a little space.");
  expect(await page.evaluate(() => window.__rescue.sim.state)).toBe("READY");
  await page.getByRole("button", { name: "Pause game", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "A little breather." }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Keep going" }).click();
  await page.getByRole("button", { name: "Retry level" }).click();
  expect(await page.evaluate(() => window.__rescue.sim.elapsed)).toBe(0);
  await page.getByRole("button", { name: "Level select", exact: true }).click();
  await page.getByRole("button", { name: "Back to home" }).click();
  await page.getByRole("button", { name: /Settings/ }).click();
  await page.getByRole("checkbox", { name: "Reduced motion" }).check();
  await page.reload();
  await page.getByRole("button", { name: /Settings/ }).click();
  await expect(
    page.getByRole("checkbox", { name: "Reduced motion" }),
  ).toBeChecked();
});
test("Resizing keeps canvas visible, and a failed rescue can be retried immediately", async ({
  page,
}) => {
  await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
  await draw(page, [
    [50, 400],
    [100, 400],
  ]);
  await expect(
    page.getByRole("heading", { name: "A tiny setback." }),
  ).toBeVisible({ timeout: 30000 });
  await page.getByRole("button", { name: "Let’s try again" }).click();
  expect(await page.evaluate(() => window.__rescue.sim.state)).toBe("READY");
  for (const [width, height] of [
    [320, 568],
    [768, 1024],
    [1280, 720],
  ]) {
    await page.setViewportSize({ width, height });
    await page.waitForTimeout(100);
    const box = await page.locator("canvas").boundingBox();
    expect(box.x).toBeGreaterThanOrEqual(-1);
    expect(box.y).toBeGreaterThanOrEqual(-1);
    expect(box.x + box.width).toBeLessThanOrEqual(width + 1);
    expect(box.y + box.height).toBeLessThanOrEqual(height + 1);
  }
});
