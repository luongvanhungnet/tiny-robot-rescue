import { chromium } from "@playwright/test";
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
import { levels } from "../src/levels.js";
const server = spawn(
  process.execPath,
  [
    "node_modules/vite/bin/vite.js",
    "preview",
    "--host",
    "127.0.0.1",
    "--port",
    "4175",
    "--strictPort",
  ],
  { stdio: "pipe" },
);
let browser;
try {
  await new Promise((resolve, reject) => {
    server.stdout.on("data", (d) => {
      if (d.toString().includes("4175")) resolve();
    });
    server.on("error", reject);
    server.on("exit", (code) => reject(Error(`Preview exited ${code}`)));
  });
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
    args: ["--no-sandbox"],
  });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("http://127.0.0.1:4175/");
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await new Promise((resolve) =>
        navigator.serviceWorker.addEventListener("controllerchange", resolve, {
          once: true,
        }),
      );
  });
  await context.setOffline(true);
  await page.reload();
  await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
  assert.equal(
    await page.getByRole("heading", { name: "First Shield" }).isVisible(),
    true,
  );
  await page.locator(".hintbtn").click();
  assert.equal(
    await page.locator(".hintbtn").getAttribute("aria-pressed"),
    "true",
  );
  assert.match(
    await page.locator(".instruction").innerText(),
    /draw the dashed path yourself/,
  );
  const box = await page.locator("canvas").boundingBox();
  await page.mouse.move(
    box.x + (260 * box.width) / 720,
    box.y + (700 * box.height) / 1280,
  );
  await page.mouse.down();
  await page.mouse.move(
    box.x + (460 * box.width) / 720,
    box.y + (700 * box.height) / 1280,
    { steps: 20 },
  );
  await page.mouse.up();
  await page
    .getByRole("heading", { name: "Little robot. Big relief." })
    .waitFor({ timeout: 15000 });
  await page.addInitScript(() => {
    const id = Number(sessionStorage.getItem("offline-target"));
    if (!id) return;
    localStorage.setItem(
      "tiny-robot-rescue.v1",
      JSON.stringify({
        version: 1,
        unlocked: id,
        lastLevel: id,
        stars: Object.fromEntries(
          Array.from({ length: id - 1 }, (_, i) => [i + 1, 3]),
        ),
        settings: { sound: false },
      }),
    );
  });
  for (const id of [51, 100]) {
    // Seed after reload: the previous page saves its live progress on pagehide.
    await page.evaluate(
      (id) => sessionStorage.setItem("offline-target", String(id)),
      id,
    );
    await page.reload();
    await page.getByRole("button", { name: /LET’S RESCUE/ }).click();
    await page
      .getByRole("heading", { name: levels[id - 1].title, exact: true })
      .waitFor();
    await page.getByRole("button", { name: "Machines", exact: true }).click();
    await page.getByRole("button", { name: "Back to the rescue" }).click();
    await page.locator(".hintbtn").click();
    assert.equal(
      await page.locator(".hintbtn").getAttribute("aria-pressed"),
      "true",
    );
    const bounds = await page.locator("canvas").boundingBox();
    const xy = ([x, y]) => [
      bounds.x + (x * bounds.width) / 720,
      bounds.y + (y * bounds.height) / 1280,
    ];
    await page.mouse.move(...xy(levels[id - 1].solution[0]));
    await page.mouse.down();
    for (const point of levels[id - 1].solution.slice(1))
      await page.mouse.move(...xy(point), { steps: 25 });
    await page.mouse.up();
    await page
      .getByRole("heading", {
        name: id === 100 ? "Workshop rescued!" : "Little robot. Big relief.",
      })
      .waitFor({ timeout: 20000 });
  }
  assert.deepEqual(errors, []);
  console.log(
    "PASS: production assets reload offline; levels 1, 51 and 100 win with player-drawn ink, hints and machine help without networking.",
  );
} finally {
  await browser?.close();
  server.kill();
}
