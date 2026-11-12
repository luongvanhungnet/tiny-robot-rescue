import Phaser from "phaser";
import { Capacitor } from "@capacitor/core";
import { App } from "@capacitor/app";
import { Haptics, ImpactStyle } from "@capacitor/haptics";
import { levels } from "./levels.js";
import { Progress } from "./save.js";
import { Simulation } from "./simulation.js";
import { distance, length, simplify, validateStroke } from "./stroke.js";
import "./style.css";

let storage;
try {
  storage = window.localStorage;
} catch {
  storage = {
    getItem: () => null,
    setItem: () => {
      throw Error("Storage unavailable");
    },
    removeItem: () => {},
  };
}
const progress = new Progress(storage);
const ui = document.querySelector("#ui");
let scene,
  screen = "home",
  current =
    levels[Math.min(progress.data.lastLevel, progress.data.unlocked) - 1],
  sim,
  points = [],
  paused = false,
  toastTimer,
  audio,
  musicNodes = [];
const $ = (selector) => ui.querySelector(selector);
const button = (label, action, kind = "secondary") =>
  `<button class="${kind}" data-action="${action}">${label}</button>`;
const icon = (label, action, symbol) =>
  `<button class="iconbtn" aria-label="${label}" data-action="${action}">${symbol}</button>`;
function sound(freq = 500, success = false) {
  if (!progress.data.settings.sound) return;
  try {
    audio ??= new (window.AudioContext || window.webkitAudioContext)();
    audio.resume();
    const osc = audio.createOscillator(),
      gain = audio.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(freq, audio.currentTime);
    osc.frequency.exponentialRampToValueAtTime(
      success ? freq * 1.5 : freq * 0.7,
      audio.currentTime + 0.16,
    );
    gain.gain.setValueAtTime(0.055, audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + 0.22);
    osc.connect(gain).connect(audio.destination);
    osc.start();
    osc.stop(audio.currentTime + 0.23);
  } catch {
    /* Audio is optional. */
  }
}
function music() {
  musicNodes.forEach((n) => {
    try {
      n.stop();
    } catch {}
  });
  musicNodes = [];
  if (!progress.data.settings.music || paused || document.hidden) return;
  try {
    audio ??= new (window.AudioContext || window.webkitAudioContext)();
    audio.resume();
    [130.81, 196, 261.63].forEach((f) => {
      const o = audio.createOscillator(),
        g = audio.createGain();
      o.type = "sine";
      o.frequency.value = f;
      g.gain.value = 0.006;
      o.connect(g).connect(audio.destination);
      o.start();
      musicNodes.push(o);
    });
  } catch {}
}
function vibrate() {
  if (Capacitor.isNativePlatform() && progress.data.settings.vibration)
    Haptics.impact({ style: ImpactStyle.Light }).catch(() => {});
}
function toast(message) {
  ui.querySelector(".toast")?.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.setAttribute("role", "status");
  el.textContent = message;
  ui.append(el);
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.remove(), 4000);
}
function cleanup() {
  sim?.destroy();
  sim = null;
  points = [];
  paused = false;
}
function home() {
  cleanup();
  screen = "home";
  ui.innerHTML = `<section class="screen"><div class="brand"><div class="eyebrow">Little machine. Big adventure.</div><div class="pill"><span class="dot"></span>OFFLINE READY</div></div><div class="home-title"><h1>TINY ROBOT<br><span>RESCUE.</span></h1><p>A falling gear. A tiny friend.<br>All that stands between them is your line.</p></div><div class="hero-space"></div><div class="home-bottom"><div class="chapter"><span>01 — THE LITTLE WORKSHOP</span><span>${Object.keys(progress.data.stars).length} / 10 rescued</span></div>${button("▶ &nbsp; LET’S RESCUE PIP", "play", "primary")}<div class="two">${button("▦ &nbsp; Levels", "levels")}${button("⚙ &nbsp; Settings", "settings")}</div><div class="footer"><span>ONE LINE</span><span>·</span><span>ENDLESS POSSIBILITIES</span></div></div></section>`;
  music();
}
function levelSelect() {
  cleanup();
  screen = "levels";
  ui.innerHTML = `<section class="screen"><div class="toprow">${icon("Back to home", "home", "‹")}<div><div class="eyebrow">THE LITTLE WORKSHOP</div><h2>Small steps. Big saves.</h2><p>10 puzzles. One clever line each.</p></div></div><div class="grid">${levels.map((l) => `<button class="level-card ${l.id === progress.data.unlocked ? "current" : ""}" data-level="${l.id}" ${l.id > progress.data.unlocked ? "disabled" : ""} aria-label="Level ${l.id}: ${l.title}${l.id > progress.data.unlocked ? ", locked" : ""}"><div class="level-number">${l.id > progress.data.unlocked ? "⌑" : String(l.id).padStart(2, "0")}</div><div class="level-name">${l.title}</div><div class="stars">${"★".repeat(progress.data.stars[l.id] ?? 0)}${"☆".repeat(3 - (progress.data.stars[l.id] ?? 0))}</div></button>`).join("")}</div><p class="chapter-note">Rescue Pip to unlock the next puzzle.<br>Use less ink to earn more stars. Every rescue counts.</p><div class="settings-foot">${progress.data.cosmetics.includes("workshop-hero") ? "✦ Workshop Hero earned — all ten puzzles rescued!" : "Made for curious minds. Take your time."}</div></section>`;
}
function settings() {
  cleanup();
  screen = "settings";
  ui.innerHTML = `<section class="screen"><div class="toprow">${icon("Back to home", "home", "‹")}<div><div class="eyebrow">MAKE YOURSELF AT HOME</div><h2>Your workshop.</h2></div></div><div class="settings-list">${[
    ["sound", "Sound effects"],
    ["music", "Ambient music"],
    ["vibration", "Haptics (Android)"],
    ["reducedMotion", "Reduced motion"],
  ]
    .map(
      ([key, label]) =>
        `<label class="setting">${label}<input type="checkbox" data-setting="${key}" aria-label="${label}" ${progress.data.settings[key] ? "checked" : ""}></label>`,
    )
    .join(
      "",
    )}</div>${button("Privacy & credits", "privacy")}${button("Restore purchases", "restore")}<div class="settings-foot">Progress lives on this device. Clearing browser/app data or uninstalling removes it. No account, tracking, ads, or purchases in this edition.<br><br>VERSION 0.1 · TEN-LEVEL VERTICAL SLICE</div></section>`;
}
function startLevel(id) {
  cleanup();
  current = levels[id - 1];
  screen = "game";
  progress.data.lastLevel = id;
  progress.save();
  sim = new Simulation(current, finish);
  renderHUD();
  music();
}
function renderHUD() {
  ui.innerHTML = `<div class="game-hud"><div class="hud-top">${icon("Level select", "levels", "‹")}<div class="level-info"><small>PUZZLE ${String(current.id).padStart(2, "0")} / 10</small><h2>${current.title}</h2></div><div class="hud-tools">${icon("Retry level", "retry", "↻")}${icon("Pause game", "pause", "II")}</div></div><div class="ink-row"><span>INK</span><div class="ink-track"><div class="ink-fill" style="width:100%"></div></div><span id="ink-value">100%</span></div><div class="instruction" aria-live="polite">${current.subtitle}<br><strong>Draw one continuous line to ${current.objective.type === "exit" ? "reach the charger" : current.objective.type === "switch" ? "wake the switch" : "keep Pip safe"}.</strong></div></div><div class="game-bottom"><span class="status" id="phase">● TAKE YOUR TIME</span><button class="hintbtn" data-action="hint">✦ Hint</button></div>${current.id === 1 && !progress.data.stars[1] ? '<div class="tutorial"><span>1.</span> Draw a roof &nbsp; <span>2.</span> Release &nbsp; <span>3.</span> Watch the rescue</div>' : ""}`;
}
function modal(title, body, actions, tag = "", symbol = "") {
  ui.querySelector(".modal-wrap")?.remove();
  const wrap = document.createElement("div");
  wrap.className = "modal-wrap";
  wrap.innerHTML = `<section class="modal" role="dialog" aria-modal="true" aria-label="${title}">${symbol ? `<div class="result-icon">${symbol}</div>` : ""}${tag ? `<div class="label-tag">${tag}</div>` : ""}<h2>${title}</h2><p>${body}</p>${actions}</section>`;
  ui.append(wrap);
  wrap.querySelector("button")?.focus();
}
function pause() {
  if (
    screen !== "game" ||
    !sim ||
    ["WON", "LOST"].includes(sim.state) ||
    paused
  )
    return;
  paused = true;
  points = [];
  if (sim.state === "DRAWING") sim.state = "READY";
  progress.save();
  music();
  modal(
    "A little breather.",
    "The workshop can wait. Your line and your time are safe.",
    button("Keep going", "resume", "primary") +
      button("Try again", "retry") +
      button("Level select", "levels"),
    "PAUSED",
  );
}
function finish(won, reason) {
  const ink = length(sim.stroke);
  sound(won ? 660 : 180, won);
  vibrate();
  if (won) {
    const stars = progress.win(current.id, ink, current.max_stroke_length);
    modal(
      current.id === 10 ? "Workshop rescued!" : "Little robot. Big relief.",
      `<span class="stars">${"★".repeat(stars)}${"☆".repeat(3 - stars)}</span><br>${current.id === 10 ? "You earned the Workshop Hero badge. Ten clever lines. Ten happy endings." : `Pip is safe. You used ${Math.round(ink)} of ${current.max_stroke_length} ink.`}`,
      button(
        current.id === 10 ? "Back to the workshop" : "Next little adventure →",
        current.id === 10 ? "levels" : "next",
        "primary",
      ) + button("Try another line", "retry"),
      "RESCUE COMPLETE",
      "✦",
    );
  } else {
    progress.save();
    modal(
      "A tiny setback.",
      `${reason} A different line could change everything.`,
      button("Let’s try again ↻", "retry", "primary") +
        button("A little hint", "hint") +
        button("Choose a level", "levels"),
      "TRY A NEW IDEA",
      "⚙",
    );
  }
}
ui.addEventListener("click", async (e) => {
  const el = e.target.closest("button");
  if (!el || el.disabled) return;
  sound(420);
  if (el.dataset.level) return startLevel(+el.dataset.level);
  switch (el.dataset.action) {
    case "home":
      home();
      break;
    case "play":
      startLevel(Math.min(progress.data.lastLevel, progress.data.unlocked));
      break;
    case "levels":
      levelSelect();
      break;
    case "settings":
      settings();
      break;
    case "retry":
      startLevel(current.id);
      break;
    case "next":
      startLevel(Math.min(10, current.id + 1));
      break;
    case "pause":
      pause();
      break;
    case "resume":
      paused = false;
      ui.querySelector(".modal-wrap")?.remove();
      music();
      break;
    case "hint":
      toast(current.hint);
      break;
    case "privacy":
      modal(
        "Made for play.",
        "No analytics, personal data collection, ads, or purchases. Saves stay on this device. Art and sounds are original code-drawn assets. Built with Phaser (MIT), Matter.js (MIT), and Capacitor (MIT).",
        button("Got it", "close", "primary"),
        "PRIVACY & CREDITS",
      );
      break;
    case "close":
      ui.querySelector(".modal-wrap")?.remove();
      break;
    case "restore":
      toast("No purchases in this edition. Every puzzle is free.");
      break;
  }
});
ui.addEventListener("change", (e) => {
  if (e.target.dataset.setting) {
    progress.data.settings[e.target.dataset.setting] = e.target.checked;
    progress.save();
    music();
  }
});
window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    if (paused) {
      paused = false;
      ui.querySelector(".modal-wrap")?.remove();
      music();
    } else pause();
  }
  if (e.key.toLowerCase() === "r" && screen === "game") startLevel(current.id);
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    pause();
    progress.save();
    audio?.suspend();
  } else music();
});
window.addEventListener("pagehide", () => progress.save());
if (Capacitor.isNativePlatform()) {
  App.addListener("appStateChange", ({ isActive }) => {
    if (!isActive) {
      pause();
      progress.save();
    }
  });
  App.addListener("backButton", () => {
    if (screen === "game") pause();
    else home();
  });
}

class Workshop extends Phaser.Scene {
  create() {
    scene = this;
    this.g = this.add.graphics();
    this.labels = [];
    this.input.on("pointerdown", (p) => {
      if (screen !== "game" || paused || sim.state !== "READY") return;
      if (p.y < 280 || p.y > 1040) return;
      points = [[p.x, p.y]];
      sim.state = "DRAWING";
      ui.querySelector(".tutorial")?.remove();
    });
    this.input.on("pointermove", (p) => {
      if (sim?.state !== "DRAWING" || paused || !p.isDown || !points.length)
        return;
      const next = [p.x, p.y],
        prev = points.at(-1);
      if (distance(prev, next) < 5) return;
      if (length(points) + distance(prev, next) > current.max_stroke_length) {
        toast("That’s all your ink. Release to test your line.");
        return;
      }
      if (points.length >= 96) {
        points = simplify(points, 3);
        if (points.length >= 96) {
          toast("Too many corners. Release to try your line.");
          return;
        }
      }
      points.push(next);
    });
    const release = () => {
      if (sim?.state !== "DRAWING" || !points.length) return;
      const stroke = simplify(points, 2);
      const error = validateStroke(stroke, current);
      if (error) {
        sim.state = "READY";
        points = [];
        toast(error);
        sound(190);
        return;
      }
      progress.attempt(current.id);
      const startError = sim.start(stroke);
      if (startError) {
        sim.state = "READY";
        points = [];
        toast(startError);
        return;
      }
      points = [];
      sound(600);
      vibrate();
    };
    this.input.on("pointerup", release);
    this.input.on("pointerupoutside", release);
    this.game.canvas.addEventListener("pointercancel", () => {
      if (sim?.state === "DRAWING") {
        points = [];
        sim.state = "READY";
        toast("Drawing canceled. Try again.");
      }
    });
    home();
  }
  update(time, delta) {
    sim?.state === "SIMULATING" && !paused && sim.step(delta);
    this.draw(time);
    if (screen === "game" && sim) {
      const ink = Math.max(
        0,
        100 *
          (1 -
            length(points.length ? points : sim.stroke) /
              current.max_stroke_length),
      );
      const fill = $(".ink-fill");
      if (fill) fill.style.width = `${ink}%`;
      if ($("#ink-value")) $("#ink-value").textContent = `${Math.round(ink)}%`;
      if ($("#phase"))
        $("#phase").textContent =
          sim.state === "SIMULATING"
            ? `◷ ${Math.max(0, current.simulation_duration - sim.elapsed).toFixed(1)}s · ${sim.level.objective.type === "survival" ? "STAY SAFE" : "LET’S GO"}`
            : sim.state === "DRAWING"
              ? "● RELEASE TO RESCUE"
              : sim.state === "WON"
                ? "✦ SAFE & SOUND"
                : sim.state === "LOST"
                  ? "↻ ANOTHER BRIGHT IDEA?"
                  : "● TAKE YOUR TIME";
    }
  }
  draw(time) {
    const g = this.g;
    g.clear();
    g.fillStyle(0x112338).fillRect(0, 0, 720, 1280);
    g.fillStyle(0x162c3e).fillCircle(650, 670, 410);
    g.fillStyle(0x183344, 0.4).fillCircle(40, 1000, 350);
    g.lineStyle(1, 0x284153, 0.55);
    for (let x = 0; x < 720; x += 48)
      for (let y = 260; y < 1200; y += 48) {
        g.fillStyle(0x38525e, 0.35).fillCircle(x, y, 1.4);
      }
    if (screen === "home") {
      this.homeArt(time);
      return;
    }
    if (screen !== "game") return;
    g.lineStyle(2, 0x345366, 0.6);
    g.strokeRoundedRect(35, 280, 650, 840, 18);
    g.fillStyle(0x122b3c).fillRoundedRect(40, 1110, 640, 15, 7);
    sim.entities.forEach((b) => this.entity(b, time));
    this.stroke(sim.stroke, 0xb6f36d, 14);
    if (points.length) {
      const invalid =
        points.length > 1 && validateStroke(simplify(points, 2), current);
      this.stroke(points, invalid ? 0xffb384 : 0xb6f36d, 14);
      const p = points.at(-1);
      g.lineStyle(2, 0xeaffc5, 0.7).strokeCircle(p[0], p[1], 17);
    }
  }
  stroke(points, color, width) {
    if (points.length < 2) return;
    const g = this.g;
    g.lineStyle(width + 9, 0x071822, 0.3);
    g.beginPath();
    g.moveTo(points[0][0], points[0][1] + 6);
    points.slice(1).forEach((p) => g.lineTo(p[0], p[1] + 6));
    g.strokePath();
    g.lineStyle(width, color, 1);
    g.beginPath();
    g.moveTo(...points[0]);
    points.slice(1).forEach((p) => g.lineTo(...p));
    g.strokePath();
    g.fillStyle(color);
    points.forEach((p) => g.fillCircle(...p, width / 2));
    g.lineStyle(2, 0xe3ffb5, 0.5);
    g.beginPath();
    g.moveTo(points[0][0], points[0][1] - 3);
    points.slice(1).forEach((p) => g.lineTo(p[0], p[1] - 3));
    g.strokePath();
  }
  robot(x, y, scale = 1, mood = "idle", time = 0) {
    const g = this.g;
    g.save();
    g.translateCanvas(x, y);
    g.scaleCanvas(scale, scale);
    g.fillStyle(0x071622, 0.4).fillEllipse(0, 33, 62, 15);
    g.fillStyle(0x396674)
      .fillRoundedRect(-23, 18, 16, 15, 4)
      .fillRoundedRect(7, 18, 16, 15, 4);
    g.fillStyle(0x477e8a)
      .fillRoundedRect(-32, -6, 10, 22, 4)
      .fillRoundedRect(22, -6, 10, 22, 4);
    g.fillStyle(0x79d8db).fillRoundedRect(-23, -27, 46, 50, 12);
    g.fillStyle(0xa3f0eb).fillRoundedRect(-20, -26, 40, 9, 5);
    g.fillStyle(0x142b3b).fillRoundedRect(-17, -15, 34, 23, 7);
    g.lineStyle(4, 0x69b4bd).lineBetween(0, -27, 0, -37);
    g.fillStyle(0xb6f36d).fillCircle(0, -39, 5);
    g.fillStyle(0xb6f36d);
    if (mood === "happy") {
      g.lineStyle(3, 0xb6f36d).beginPath();
      g.arc(-8, -4, 4, Math.PI, 0);
      g.strokePath();
      g.beginPath();
      g.arc(8, -4, 4, Math.PI, 0);
      g.strokePath();
    } else if (mood === "scared") {
      g.fillCircle(-8, -4, 4).fillCircle(8, -4, 4);
    } else {
      const blink = Math.sin(time / 700) > 0.985;
      g.fillRoundedRect(-11, -7, 6, blink ? 2 : 9, 3).fillRoundedRect(
        5,
        -7,
        6,
        blink ? 2 : 9,
        3,
      );
    }
    g.fillStyle(0xf7c777).fillCircle(0, 15, 3);
    g.restore();
  }
  gear(x, y, r, angle = 0, color = 0xec9a73) {
    const g = this.g;
    g.save();
    g.translateCanvas(x, y);
    g.rotateCanvas(angle);
    g.fillStyle(color);
    for (let i = 0; i < 10; i++) {
      g.save();
      g.rotateCanvas((i * Math.PI) / 5);
      g.fillRoundedRect(-r * 0.22, -r * 1.12, r * 0.44, r * 0.4, 3);
      g.restore();
    }
    g.fillCircle(0, 0, r * 0.91);
    g.fillStyle(0x593b35).fillCircle(0, 0, r * 0.52);
    g.fillStyle(0xf4c49b).fillCircle(0, 0, r * 0.23);
    g.restore();
  }
  entity(b, time) {
    const g = this.g,
      { x, y } = b.position,
      o = b.plugin;
    switch (b.label) {
      case "robot":
        this.robot(
          x,
          y,
          1,
          sim.state === "WON"
            ? "happy"
            : sim.state === "SIMULATING"
              ? "scared"
              : "idle",
          time,
        );
        break;
      case "platform":
        g.fillStyle(0x0a1928, 0.4).fillRoundedRect(
          x - o.w / 2,
          y - o.h / 2 + 10,
          o.w,
          o.h,
          6,
        );
        g.fillStyle(0x42566b).fillRoundedRect(
          x - o.w / 2,
          y - o.h / 2,
          o.w,
          o.h,
          6,
        );
        g.fillStyle(0x6e8990).fillRoundedRect(
          x - o.w / 2 + 2,
          y - o.h / 2,
          o.w - 4,
          5,
          2,
        );
        for (let px = x - o.w / 2 + 16; px < x + o.w / 2; px += 38)
          g.fillStyle(0x263e51).fillCircle(px, y + 3, 3);
        break;
      case "gear":
      case "conveyor":
        this.gear(x, y, 29, b.angle);
        break;
      case "block":
        g.save();
        g.translateCanvas(x, y);
        g.rotateCanvas(b.angle);
        g.fillStyle(0xbb8c83).fillRoundedRect(-32, -32, 64, 64, 8);
        g.lineStyle(5, 0x744e51).strokeRoundedRect(-24, -24, 48, 48, 5);
        g.lineBetween(-15, -15, 15, 15).lineBetween(15, -15, -15, 15);
        g.restore();
        break;
      case "ball":
      case "spring":
      case "captured":
        g.fillStyle(0x0b1b26, 0.3).fillEllipse(x, y + 27, 48, 12);
        g.fillStyle(
          b.label === "captured"
            ? 0xb6f36d
            : b.label === "spring"
              ? 0xc798e1
              : 0xf0c474,
        ).fillCircle(x, y, 25);
        g.lineStyle(4, 0x896d4c).strokeCircle(x, y, 17);
        g.fillStyle(0xffedba, 0.6).fillCircle(x - 7, y - 9, 6);
        break;
      case "goal":
        g.fillStyle(0x77d9b4, 0.1).fillRoundedRect(
          x - o.w / 2 - 9,
          y - o.h / 2 - 12,
          o.w + 18,
          o.h + 20,
          12,
        );
        g.lineStyle(3, 0x77d9b4, 0.7).strokeRoundedRect(
          x - o.w / 2,
          y - o.h / 2,
          o.w,
          o.h,
          8,
        );
        g.fillStyle(0xb6f36d).fillPoints(
          [
            { x: x + 3, y: y - 19 },
            { x: x - 12, y: y + 3 },
            { x: x, y: y + 3 },
            { x: x - 4, y: y + 20 },
            { x: x + 13, y: y - 3 },
            { x: x + 2, y: y - 3 },
          ],
          true,
        );
        break;
      case "switch":
        g.fillStyle(o.active ? 0xb6f36d : 0xf2bb6a).fillRoundedRect(
          x - o.w / 2,
          y - o.h / 2,
          o.w,
          o.h,
          8,
        );
        g.fillStyle(0x644f36).fillRoundedRect(
          x - o.w / 2 + 8,
          y + 5,
          o.w - 16,
          5,
          2,
        );
        break;
      case "gate":
        if (!o.open) {
          g.fillStyle(0xf2bb6a, 0.8).fillRoundedRect(
            x - o.w / 2,
            y - o.h / 2,
            o.w,
            o.h,
            5,
          );
          g.lineStyle(3, 0x8f7043);
          for (let gy = y - o.h / 2 + 10; gy < y + o.h / 2; gy += 20)
            g.lineBetween(x - 7, gy, x + 7, gy + 10);
        }
        break;
    }
  }
  homeArt(time) {
    const g = this.g;
    g.lineStyle(2, 0x355164, 0.7).strokeCircle(360, 726, 205);
    g.lineStyle(1, 0x355164, 0.5).strokeCircle(360, 726, 230);
    g.fillStyle(0x28483d, 0.5).fillCircle(360, 720, 173);
    g.fillStyle(0x091925, 0.3).fillEllipse(360, 910, 340, 35);
    g.fillStyle(0x405b69).fillRoundedRect(175, 866, 370, 24, 8);
    g.fillStyle(0x759492).fillRoundedRect(180, 866, 360, 5, 2);
    const bob = progress.data.settings.reducedMotion
      ? 0
      : Math.sin(time / 700) * 4;
    this.robot(360, 789 + bob, 2.9, "idle", time);
    this.stroke(
      [
        [205, 681],
        [252, 617],
        [466, 617],
        [515, 681],
      ],
      0xb6f36d,
      14,
    );
    this.gear(
      400,
      544,
      41,
      progress.data.settings.reducedMotion ? 0 : time / 2200,
    );
    g.fillStyle(0xf3c776, 0.7).fillCircle(204, 565, 5);
    g.fillStyle(0x83ced1, 0.7).fillCircle(528, 765, 5);
    g.lineStyle(2, 0x84bfa4)
      .lineBetween(169, 740, 180, 740)
      .lineBetween(174, 734, 174, 746);
    g.lineStyle(2, 0x84bfa4)
      .lineBetween(526, 584, 537, 584)
      .lineBetween(531, 579, 531, 590);
  }
}
const game = new Phaser.Game({
  type: Phaser.CANVAS,
  parent: "game",
  width: 720,
  height: 1280,
  backgroundColor: "#112338",
  antialias: true,
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.NO_CENTER },
  scene: Workshop,
  input: { activePointers: 1 },
  audio: { noAudio: true },
  render: { powerPreference: "low-power" },
  fps: { target: 60 },
});
new ResizeObserver(() => game.scale.refresh()).observe(
  document.querySelector("#app"),
);
if (import.meta.env.DEV)
  window.__rescue = {
    game,
    get sim() {
      return sim;
    },
    get progress() {
      return progress;
    },
    get screen() {
      return screen;
    },
    get points() {
      return points;
    },
    startLevel,
    pause,
  };
if ("serviceWorker" in navigator && import.meta.env.PROD)
  window.addEventListener("load", () =>
    navigator.serviceWorker.register("/sw.js").catch(() => {}),
  );
