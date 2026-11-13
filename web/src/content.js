export const chapters = [
  { name: "Workshop", first: 1, last: 10, badge: "workshop-hero" },
  { name: "Foundry", first: 11, last: 20, badge: "foundry-hero" },
  { name: "Skyworks", first: 21, last: 30, badge: "skyworks-hero" },
  { name: "Power Lab", first: 31, last: 36, badge: "power-lab-hero" },
  { name: "Relay Hub", first: 37, last: 40, badge: "relay-hub-hero" },
  { name: "Grand Circuit", first: 41, last: 50, badge: "grand-circuit-hero" },
];
export const paints = [
  {
    id: "aqua",
    name: "Aqua",
    color: 0x79d8db,
    highlight: 0xa3f0eb,
    requires: null,
  },
  {
    id: "copper",
    name: "Copper",
    color: 0xf2ba78,
    highlight: 0xffdfaa,
    requires: "workshop-hero",
  },
  {
    id: "violet",
    name: "Violet",
    color: 0xbca2ed,
    highlight: 0xe1ceff,
    requires: "foundry-hero",
  },
  {
    id: "rose",
    name: "Rose",
    color: 0xef9db6,
    highlight: 0xffcfdf,
    requires: "skyworks-hero",
  },
];
export const chapterForLevel = (id) =>
  chapters.find((c) => id >= c.first && id <= c.last) ?? chapters[0];
export const paintUnlocked = (paint, data) =>
  !paint.requires || data.cosmetics.includes(paint.requires);
