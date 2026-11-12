export const SAVE_KEY = "tiny-robot-rescue.v1";
export const defaults = () => ({
  version: 1,
  unlocked: 1,
  lastLevel: 1,
  stars: {},
  bestInk: {},
  attempts: {},
  cosmetics: [],
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
  fresh.unlocked = int(raw.unlocked ?? raw.unlocked_level, 1, 10);
  fresh.lastLevel = int(
    raw.lastLevel ?? raw.last_selected_level,
    1,
    fresh.unlocked,
  );
  for (const key of ["stars", "bestInk", "attempts"]) {
    for (const [id, value] of Object.entries(raw[key] ?? {})) {
      if (+id >= 1 && +id <= 10 && Number.isFinite(value) && value >= 0)
        fresh[key][id] = key === "stars" ? int(value, 0, 3) : value;
    }
  }
  for (const key of Object.keys(fresh.settings))
    if (typeof raw.settings?.[key] === "boolean")
      fresh.settings[key] = raw.settings[key];
  if (Array.isArray(raw.cosmetics))
    fresh.cosmetics = raw.cosmetics.filter((v) => v === "workshop-hero");
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
  attempt(id) {
    this.data.lastLevel = id;
    this.data.attempts[id] = (this.data.attempts[id] ?? 0) + 1;
    this.save();
  }
  win(id, ink, max) {
    const stars = ink <= max * 0.65 ? 3 : ink <= max * 0.9 ? 2 : 1;
    this.data.stars[id] = Math.max(stars, this.data.stars[id] ?? 0);
    this.data.bestInk[id] = Math.min(ink, this.data.bestInk[id] ?? Infinity);
    this.data.unlocked = Math.min(10, Math.max(this.data.unlocked, id + 1));
    if (id === 10 && !this.data.cosmetics.includes("workshop-hero"))
      this.data.cosmetics.push("workshop-hero");
    this.save();
    return stars;
  }
}
