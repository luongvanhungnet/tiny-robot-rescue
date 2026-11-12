// Original authored layouts in a 720 × 1280 world. Solutions are test metadata only.
const platform = (x, y, w, h = 24) => ({ type: "platform", x, y, w, h });
const robot = (x, y, walk = false) => ({ type: "robot", x, y, walk });
const hazard = (type, x, y, extra = {}) => ({ type, x, y, ...extra });
const ground = platform(360, 1060, 660, 32);
const base = (id, title, subtitle, hint, objects, solution, extra = {}) => ({
  id,
  title,
  subtitle,
  hint,
  background_id: Math.floor((id - 1) / 3),
  world_bounds: [0, 240, 720, 1110],
  draw_zones: [[42, 300, 636, 730]],
  forbidden_zones: [],
  max_stroke_length: 480,
  simulation_duration: 8,
  objective: { type: "survival" },
  difficulty_tag:
    id < 4 ? "Getting started" : id < 8 ? "Think sideways" : "Little genius",
  tutorial_steps:
    id === 1
      ? [
          "Drag to draw a roof.",
          "Release to start the machines.",
          "Keep your little friend safe for 8 seconds.",
        ]
      : [],
  expected_solution_tags: ["shield"],
  objects,
  solution,
  ...extra,
});
export const levels = [
  base(
    1,
    "First Shield",
    "A little roof. A big difference.",
    "Draw a roof above Pip, below the falling gear.",
    [ground, robot(360, 1018), hazard("gear", 360, 370)],
    [
      [260, 700],
      [460, 700],
    ],
  ),
  base(
    2,
    "Side Impact",
    "Give that heavy block a new direction.",
    "A sloping roof can guide a block away from Pip.",
    [platform(340, 1060, 340, 32), robot(340, 1018), hazard("block", 340, 400)],
    [
      [240, 670],
      [440, 740],
    ],
  ),
  base(
    3,
    "Bouncy Surprise",
    "What goes down might come back up.",
    "A wide roof catches the bouncy ball before it hits Pip.",
    [
      ground,
      platform(100, 820, 120),
      robot(390, 1018),
      hazard("ball", 390, 380, { bounce: 0.85 }),
    ],
    [
      [275, 720],
      [520, 700],
    ],
  ),
  base(
    4,
    "Narrow Shelter",
    "Make every drop of ink count.",
    "Use a short roof, just wider than the robot.",
    [
      ground,
      platform(170, 690, 160),
      platform(550, 690, 160),
      robot(360, 1018),
      hazard("gear", 360, 410),
    ],
    [
      [295, 700],
      [425, 700],
    ],
    { max_stroke_length: 155 },
  ),
  base(
    5,
    "Two Robots",
    "One line. Two little lives.",
    "One long roof can shelter both robots.",
    [
      ground,
      robot(260, 1018),
      robot(460, 1018),
      hazard("gear", 260, 380),
      hazard("block", 460, 350),
    ],
    [
      [180, 720],
      [540, 720],
    ],
    { max_stroke_length: 420 },
  ),
  base(
    6,
    "Broken Bridge",
    "Home is on the other side.",
    "Bridge the gap at platform height. Pip will walk to the charger.",
    [
      platform(130, 950, 200, 28),
      platform(590, 950, 200, 28),
      robot(130, 910, true),
      { type: "goal", x: 600, y: 902, w: 64, h: 66 },
    ],
    [
      [238, 943],
      [482, 943],
    ],
    {
      objective: { type: "exit" },
      simulation_duration: 12,
      expected_solution_tags: ["bridge"],
    },
  ),
  base(
    7,
    "Spring Launch",
    "Incoming, with extra enthusiasm.",
    "The ball launches sideways. Put a wall between it and Pip.",
    [ground, robot(465, 1018), hazard("spring", 115, 780, { vx: 5, vy: -3 })],
    [
      [320, 720],
      [320, 1015],
    ],
    { expected_solution_tags: ["wall"] },
  ),
  base(
    8,
    "Gear Conveyor",
    "A machine with somewhere to be.",
    "Block the moving gear before it reaches Pip.",
    [ground, robot(480, 1018), hazard("conveyor", 110, 1010, { vx: 3 })],
    [
      [310, 870],
      [310, 1020],
    ],
    { expected_solution_tags: ["wall", "ramp"] },
  ),
  base(
    9,
    "Switch Rescue",
    "A helpful bounce opens the way.",
    "Slope the line down toward the amber switch on the right.",
    [
      ground,
      platform(680, 860, 22, 370),
      robot(140, 1018, true),
      hazard("ball", 300, 370),
      {
        type: "switch",
        x: 550,
        y: 1022,
        w: 100,
        h: 36,
        trigger_action: "capture_hazard",
      },
      { type: "goal", x: 600, y: 1000, w: 70, h: 90 },
      { type: "gate", x: 480, y: 970, w: 18, h: 145 },
    ],
    [
      [210, 660],
      [610, 850],
    ],
    {
      objective: { type: "switch", required_switches: 1, require_goal: true },
      simulation_duration: 12,
      max_stroke_length: 500,
      expected_solution_tags: ["deflect", "switch"],
    },
  ),
  base(
    10,
    "One-Line Finale",
    "Shield a friend. Wake the workshop.",
    "A sloped roof shelters Pip and rolls the ball onto the switch.",
    [
      ground,
      platform(680, 860, 22, 370),
      robot(300, 1018),
      hazard("ball", 300, 350),
      hazard("gear", 230, 420),
      { type: "switch", x: 570, y: 1022, w: 110, h: 36 },
    ],
    [
      [180, 650],
      [570, 815],
    ],
    {
      objective: { type: "switch", required_switches: 1 },
      max_stroke_length: 520,
      simulation_duration: 12,
      expected_solution_tags: ["shield", "switch"],
    },
  ),
];
export function validateLevel(l) {
  return (
    Number.isInteger(l.id) &&
    !!l.title &&
    !!l.hint &&
    l.objects.some((o) => o.type === "robot") &&
    l.max_stroke_length > 0 &&
    l.solution.length >= 2 &&
    ["survival", "exit", "switch"].includes(l.objective.type)
  );
}
