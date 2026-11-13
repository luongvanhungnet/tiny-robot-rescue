import { test, expect } from "@playwright/test";
import { levels } from "../../src/levels.js";
test("All campaign puzzles can be rescued in sequence through real pointer input", async ({
  page,
}, info) => {
  test.skip(
    info.project.name !== "desktop",
    "Touch input is covered by the first-rescue test.",
  );
  test.setTimeout(600000);
  await page.goto("/");
  await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
  for (const level of levels) {
    await expect(
      page.getByRole("heading", { name: level.title, exact: true }),
    ).toBeVisible();
    const box = await page.locator("canvas").boundingBox();
    const xy = ([x, y]) => [
      box.x + (x * box.width) / 720,
      box.y + (y * box.height) / 1280,
    ];
    await page.mouse.move(...xy(level.solution[0]));
    await page.mouse.down();
    for (const point of level.solution.slice(1))
      await page.mouse.move(...xy(point), { steps: 25 });
    await page.mouse.up();
    await page
      .getByRole("heading", {
        name:
          level.id === levels.length
            ? "Workshop rescued!"
            : "Little robot. Big relief.",
      })
      .waitFor({ timeout: 30000 });
    await page
      .getByRole("button", {
        name:
          level.id === levels.length
            ? "Back to the workshop"
            : "Next little adventure",
      })
      .click();
  }
  await expect(page.getByText(/Foundry Hero earned/)).toBeVisible();
  expect(
    await page.evaluate(
      () => Object.keys(window.__rescue.progress.data.stars).length,
    ),
  ).toBe(levels.length);
});
