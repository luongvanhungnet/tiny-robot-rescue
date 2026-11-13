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
    for (let segment = 1; segment < coords.length; segment++) {
      const a = coords[segment - 1],
        b = coords[segment];
      for (let i = 1; i <= 20; i++) {
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

test("Finished ten-level saves continue into the foundry with cornered mouse/touch strokes", async ({
  page,
}, info) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: 10,
        lastLevel: 10,
        stars: { 10: 3 },
        settings: { sound: false },
        cosmetics: ["workshop-hero"],
      }),
    ),
  );
  await page.reload();
  await page.getByRole("button", { name: /Levels/ }).click();
  await expect(page.locator(".level-card")).toHaveCount(100);
  await expect(
    page.getByRole("button", { name: "Level 11: Cross Traffic", exact: true }),
  ).toBeEnabled();
  await expect(
    page.getByRole("button", {
      name: "Level 12: Pocket Roof, locked",
      exact: true,
    }),
  ).toBeDisabled();
  await page
    .getByRole("button", { name: "Level 11: Cross Traffic", exact: true })
    .click();
  await draw(
    page,
    [
      [320, 1020],
      [320, 720],
      [550, 720],
    ],
    info.project.name === "mobile",
  );
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible({ timeout: 30000 });
  await page.getByRole("button", { name: "Next little adventure" }).click();
  await expect(
    page.getByRole("heading", { name: "Pocket Roof" }),
  ).toBeVisible();
  expect(
    await page.evaluate(() => window.__rescue.progress.data.stars[10]),
  ).toBe(3);
});

test("Skyworks migration keeps earned paints and opens the new chapter", async ({
  page,
}, info) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: 20,
        lastLevel: 20,
        stars: { 10: 3, 20: 2 },
        settings: { sound: false },
      }),
    ),
  );
  await page.reload();
  await page.getByRole("button", { name: /Settings/ }).click();
  await page.getByRole("button", { name: "Robot paints" }).click();
  await expect(page.getByRole("button", { name: /Rose/ })).toBeDisabled();
  await page.getByRole("button", { name: "Violet", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Violet · Selected", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Done", exact: true }).click();
  expect(await page.evaluate(() => window.__rescue.progress.data.paint)).toBe(
    "violet",
  );
  await page.getByRole("button", { name: "Back to home" }).click();
  await page.getByRole("button", { name: /Levels/ }).click();
  await expect(page.locator(".level-card")).toHaveCount(100);
  await page
    .getByRole("button", { name: "Level 21: Air Mail", exact: true })
    .click();
  await draw(
    page,
    [
      [210, 700],
      [510, 700],
    ],
    info.project.name === "mobile",
  );
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible({ timeout: 30000 });
  await page.getByRole("button", { name: "Next little adventure" }).click();
  await expect(page.getByRole("heading", { name: "Sky Bridge" })).toBeVisible();
  expect(
    await page.evaluate(() => window.__rescue.progress.data.stars[20]),
  ).toBe(2);
  expect(await page.evaluate(() => window.__rescue.progress.data.paint)).toBe(
    "violet",
  );
});

test("Power Lab continues an old save and explains the new cargo objective", async ({
  page,
}, info) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: 30,
        lastLevel: 30,
        stars: { 30: 3 },
        paint: "rose",
        settings: { sound: false },
      }),
    ),
  );
  await page.reload();
  await page.getByRole("button", { name: /Levels/ }).click();
  await page
    .getByRole("button", { name: "Level 31: Special Delivery", exact: true })
    .click();
  await expect(
    page.getByText("Draw one continuous line to deliver every energy core."),
  ).toBeVisible();
  await draw(
    page,
    [
      [215, 645],
      [585, 805],
    ],
    info.project.name === "mobile",
  );
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible({ timeout: 30000 });
  await page.getByRole("button", { name: "Next little adventure" }).click();
  await expect(
    page.getByRole("heading", { name: "Air Freight" }),
  ).toBeVisible();
  expect(await page.evaluate(() => window.__rescue.progress.data.paint)).toBe(
    "rose",
  );
  expect(
    await page.evaluate(() => window.__rescue.progress.data.stars[30]),
  ).toBe(3);
});

test("Relay Hub continues a completed lab save with a real cargo cradle", async ({
  page,
}, info) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: 36,
        lastLevel: 36,
        stars: { 30: 3, 36: 2 },
        paint: "rose",
        settings: { sound: false },
      }),
    ),
  );
  await page.reload();
  await page.getByRole("button", { name: /Levels/ }).click();
  await page
    .getByRole("button", { name: "Level 37: Crosswind Cradle", exact: true })
    .click();
  await draw(
    page,
    [
      [180, 730],
      [180, 1020],
      [630, 1020],
      [630, 680],
    ],
    info.project.name === "mobile",
  );
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible({ timeout: 30000 });
  await page.getByRole("button", { name: "Next little adventure" }).click();
  await expect(
    page.getByRole("heading", { name: "Upward Clearance" }),
  ).toBeVisible();
  expect(
    await page.evaluate(() => window.__rescue.progress.data.stars[36]),
  ).toBe(2);
  expect(await page.evaluate(() => window.__rescue.progress.data.paint)).toBe(
    "rose",
  );
});

test("Grand Circuit unlocks from a completed Relay Hub save and plays by touch", async ({
  page,
}, info) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: 40,
        lastLevel: 40,
        stars: { 30: 3, 40: 2 },
        paint: "rose",
        settings: { sound: false },
      }),
    ),
  );
  await page.reload();
  await page.getByRole("button", { name: /Levels/ }).click();
  await expect(page.locator(".level-card")).toHaveCount(100);
  await page
    .getByRole("button", { name: "Level 41: Opposing Currents", exact: true })
    .click();
  await draw(
    page,
    [
      [55, 500],
      [55, 1020],
      [665, 1020],
      [665, 500],
    ],
    info.project.name === "mobile",
  );
  await expect(
    page.getByRole("heading", { name: "Little robot. Big relief." }),
  ).toBeVisible({ timeout: 30000 });
  await page.getByRole("button", { name: "Next little adventure" }).click();
  await expect(
    page.getByRole("heading", { name: "Triple Clearance" }),
  ).toBeVisible();
  expect(
    await page.evaluate(() => window.__rescue.progress.data.stars[40]),
  ).toBe(2);
  expect(await page.evaluate(() => window.__rescue.progress.data.paint)).toBe(
    "rose",
  );
});
