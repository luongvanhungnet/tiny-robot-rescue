import { chromium } from "@playwright/test";
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
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
  assert.deepEqual(errors, []);
  console.log(
    "PASS: production assets reload offline and a drawn level wins with no network.",
  );
} finally {
  await browser?.close();
  server.kill();
}
