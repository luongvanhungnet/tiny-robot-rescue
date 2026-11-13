import { chapters, paints, paintUnlocked } from "./content.js";
import { LEVEL_COUNT } from "./levels.js";
export const SAVE_KEY = "tiny-robot-rescue.v1";
export const defaults = () => ({
  version: 1,
  unlocked: 1,
  lastLevel: 1,
  stars: {},
  bestInk: {},
  attempts: {},
  cosmetics: [],
  paint: "aqua",
  settings: {
    sound: true,
    music: false,
    vibration: true,
    reducedMotion: false,
  },
});
function sanitize(raw) {
  if (
    !raw ||
    typeof raw !== "object" ||
    Array.isArray(raw) ||
    ![undefined, 1].includes(raw.version)
  )
    throw Error("Unsupported save");
  const fresh = defaults();
  const int = (n, min, max) =>
    Number.isInteger(n) ? Math.max(min, Math.min(max, n)) : min;
  fresh.unlocked = int(raw.unlocked ?? raw.unlocked_level, 1, LEVEL_COUNT);
  fresh.lastLevel = int(
    raw.lastLevel ?? raw.last_selected_level,
    1,
    fresh.unlocked,
  );
  for (const key of ["stars", "bestInk", "attempts"]) {
    for (const [id, value] of Object.entries(raw[key] ?? {})) {
      if (
        +id >= 1 &&
        +id <= LEVEL_COUNT &&
        Number.isFinite(value) &&
        value >= 0
      )
        fresh[key][id] = key === "stars" ? int(value, 0, 3) : value;
    }
  }
  const highestWon = Math.max(
    0,
    ...Object.keys(fresh.stars)
      .filter((id) => fresh.stars[id] > 0)
      .map(Number),
  );
  fresh.unlocked = Math.min(
    LEVEL_COUNT,
    Math.max(fresh.unlocked, highestWon + 1),
  );
  for (const key of Object.keys(fresh.settings))
    if (typeof raw.settings?.[key] === "boolean")
      fresh.settings[key] = raw.settings[key];
  if (Array.isArray(raw.cosmetics))
    fresh.cosmetics = raw.cosmetics.filter((v) =>
      chapters.some((c) => c.badge === v),
    );
  for (const chapter of chapters) {
    if (
      fresh.stars[chapter.last] > 0 &&
      !fresh.cosmetics.includes(chapter.badge)
    )
      fresh.cosmetics.push(chapter.badge);
  }
  const paint = paints.find((p) => p.id === raw.paint);
  if (paint && paintUnlocked(paint, fresh)) fresh.paint = paint.id;
  return fresh;
}
export class Progress {
  constructor(storage) {
    this.storage = storage;
    this.data = defaults();
    this.persistent = true;
    this.load();
  }
  load() {
    for (const key of [SAVE_KEY, SAVE_KEY + ".backup"]) {
      try {
        const item = this.storage.getItem(key);
        if (item) {
          this.data = sanitize(JSON.parse(item));
          return;
        }
      } catch {
        /* Try the previous complete transaction. */
      }
    }
    this.data = defaults();
  }
  save() {
    try {
      const serialized = JSON.stringify(sanitize(this.data));
      this.storage.setItem(SAVE_KEY + ".pending", serialized);
      const old = this.storage.getItem(SAVE_KEY);
      if (old) {
        try {
          sanitize(JSON.parse(old));
          this.storage.setItem(SAVE_KEY + ".backup", old);
        } catch {
          /* Do not back up a corrupt primary. */
        }
      }
      this.storage.setItem(SAVE_KEY, serialized);
      this.storage.removeItem(SAVE_KEY + ".pending");
      this.persistent = true;
    } catch {
      this.persistent = false;
    }
    return this.persistent;
  }
  selectPaint(id) {
    const paint = paints.find((p) => p.id === id);
    if (!paint || !paintUnlocked(paint, this.data)) return false;
    this.data.paint = id;
    this.save();
    return true;
  }
  attempt(id) {
    this.data.lastLevel = id;
    this.data.attempts[id] = (this.data.attempts[id] ?? 0) + 1;
    this.save();
  }
  win(id, ink, max) {
    const stars = ink <= max * 0.65 ? 3 : ink <= max * 0.9 ? 2 : 1;
    this.data.stars[id] = Math.max(stars, this.data.stars[id] ?? 0);
    this.data.bestInk[id] = Math.min(ink, this.data.bestInk[id] ?? Infinity);
    this.data.unlocked = Math.min(
      LEVEL_COUNT,
      Math.max(this.data.unlocked, id + 1),
    );
    const chapter = chapters.find((c) => c.last === id);
    if (chapter && !this.data.cosmetics.includes(chapter.badge))
      this.data.cosmetics.push(chapter.badge);
    this.save();
    return stars;
  }
}
