export const chapters = [
  { name: "Workshop", first: 1, last: 10, badge: "workshop-hero" },
  { name: "Foundry", first: 11, last: 20, badge: "foundry-hero" },
  { name: "Skyworks", first: 21, last: 30, badge: "skyworks-hero" },
  { name: "Power Lab", first: 31, last: 36, badge: "power-lab-hero" },
  { name: "Relay Hub", first: 37, last: 40, badge: "relay-hub-hero" },
  { name: "Grand Circuit", first: 41, last: 50, badge: "grand-circuit-hero" },
  { name: "Portal Post", first: 51, last: 60, badge: "portal-post-hero" },
  {
    name: "Gravity Gardens",
    first: 61,
    last: 70,
    badge: "gravity-gardens-hero",
  },
  { name: "Magnetic Works", first: 71, last: 80, badge: "magnetic-works-hero" },
  { name: "Launch Academy", first: 81, last: 90, badge: "launch-academy-hero" },
  {
    name: "Counterweight Keep",
    first: 91,
    last: 100,
    badge: "counterweight-keep-hero",
  },
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
  {
    id: "periwinkle",
    name: "Periwinkle",
    color: 0x9fa8ff,
    highlight: 0xdce0ff,
    requires: "portal-post-hero",
  },
  {
    id: "mint",
    name: "Mint",
    color: 0x8ee0b8,
    highlight: 0xd4ffe7,
    requires: "gravity-gardens-hero",
  },
  {
    id: "gold",
    name: "Gold",
    color: 0xf6cd72,
    highlight: 0xffe9b3,
    requires: "magnetic-works-hero",
  },
  {
    id: "coral",
    name: "Coral",
    color: 0xf7a28c,
    highlight: 0xffd8c8,
    requires: "launch-academy-hero",
  },
  {
    id: "starlight",
    name: "Starlight",
    color: 0xdae8f7,
    highlight: 0xffffff,
    requires: "counterweight-keep-hero",
  },
];
export const chapterForLevel = (id) =>
  chapters.find((c) => id >= c.first && id <= c.last) ?? chapters[0];
export const paintUnlocked = (paint, data) =>
  !paint.requires || data.cosmetics.includes(paint.requires);
