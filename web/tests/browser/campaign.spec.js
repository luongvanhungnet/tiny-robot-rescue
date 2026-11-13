import { test, expect } from "@playwright/test";
import { levels } from "../../src/levels.js";
import { chapterForLevel } from "../../src/content.js";
test("Campaign puzzles can be rescued in sequence through real pointer input", async ({
  page,
}, info) => {
  test.skip(
    info.project.name !== "desktop",
    "Touch input is covered by the first-rescue test.",
  );
  test.setTimeout(600000);
  const startLevel = Number(process.env.CAMPAIGN_START_LEVEL || 1);
  if (startLevel > 1)
    await page.addInitScript((start) => {
      const stars = Object.fromEntries(
        Array.from({ length: start - 1 }, (_, i) => [i + 1, 3]),
      );
      localStorage.setItem(
        "tiny-robot-rescue.v1",
        JSON.stringify({
          version: 1,
          unlocked: start,
          lastLevel: start,
          stars,
          settings: { sound: false },
        }),
      );
    }, startLevel);
  await page.goto("/");
  await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
  console.log(
    `Playing real input campaign from level ${startLevel} to ${levels.length}`,
  );
  for (const level of levels.slice(startLevel - 1)) {
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
    console.log(`Rescued ${level.id}: ${level.title}`);
    await page
      .getByRole("button", {
        name:
          level.id === levels.length
            ? "Back to the workshop"
            : "Next little adventure",
      })
      .click();
  }
  await expect(
    page.getByText(`${chapterForLevel(levels.length).name} Hero earned`, {
      exact: false,
    }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => Object.keys(window.__rescue.progress.data.stars).length,
    ),
  ).toBe(levels.length);
});
