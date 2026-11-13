import { length } from "./stroke.js";
// Authored machine puzzles. Shared fixtures keep dimensions consistent; each
// recipe below changes the transport dependency, objective, or cargo topology.
const floor = { type: "platform", x: 100, y: 1060, w: 160, h: 32 };
const core = (x, y, channel = "cyan", extra = {}) => ({
  type: "cell",
  x,
  y,
  channel,
  ...extra,
});
const dock = (x, y, accepts = "cyan", extra = {}) => ({
  type: "socket",
  x,
  y,
  w: 85,
  h: 80,
  accepts,
  ...extra,
});
const portal = (x, y, to_x, to_y, extra = {}) => ({
  type: "portal",
  x,
  y,
  w: 80,
  h: 60,
  to_x,
  to_y,
  ...extra,
});
const gravity = (extra = {}) => ({
  type: "gravity",
  x: 450,
  y: 650,
  w: 450,
  h: 760,
  gy: -0.001,
  ...extra,
});
const magnet = (extra = {}) => ({
  type: "magnet",
  x: 680,
  y: 1060,
  w: 44,
  h: 44,
  radius: 1000,
  strength: 0.002,
  ...extra,
});
const launch = (x = 200, y = 600, extra = {}) => ({
  type: "launcher",
  x,
  y,
  w: 80,
  h: 60,
  vx: 8,
  vy: -8,
  ...extra,
});
const plate = (x = 300, y = 720, extra = {}) => ({
  type: "plate",
  x,
  y,
  w: 100,
  h: 90,
  channel: "load",
  hold_for: 1.5,
  ...extra,
});
const ring = (x, y, key, extra = {}) => ({
  type: "checkpoint",
  x,
  y,
  w: 110,
  h: 110,
  key,
  ...extra,
});
const rightWall = [
  [640, 400],
  [640, 1020],
];
const roof = [
  [220, 500],
  [600, 350],
  [640, 350],
  [640, 700],
];
const basket = [
  [230, 650],
  [230, 750],
  [370, 750],
  [370, 650],
];
const delivery = (objects, solution = rightWall, required_cells = 1) => ({
  objects,
  solution,
  objective: { type: "delivery", required_cells },
});
const warp = () =>
  delivery([
    core(200, 350),
    portal(200, 550, 400, 350, { vx: 5 }),
    dock(600, 980),
  ]);
const rise = () => delivery([core(300, 850), gravity(), dock(600, 400)], roof);
const pull = () =>
  delivery(
    [core(200, 350), magnet(), dock(600, 980)],
    [
      [640, 650],
      [640, 1020],
    ],
  );
const jump = () =>
  delivery(
    [core(200, 350), launch(), dock(600, 980)],
    [
      [640, 500],
      [640, 1020],
    ],
  );
const load = () => ({
  objects: [core(300, 350), plate()],
  solution: basket,
  objective: { type: "exit" },
  escort: true,
});
function escort(p, channel = "exit") {
  p.escort = true;
  p.objects.push({ type: "gate", x: 530, y: 970, w: 20, h: 140, channel });
  p.objects.push({ type: "goal", x: 600, y: 1015, w: 70, h: 80 });
  if (p.objective.type === "delivery") {
    p.objective.require_goal = true;
    const d = p.objects.filter((o) => o.type === "socket").at(-1);
    d.trigger_action = "open_gate";
    d.gate_channel = channel;
  }
  return p;
}
function pressure(p = load()) {
  // A live pressure plate, rather than a one-shot delivery, holds this gate.
  return escort(p, "load");
}
function shield(p) {
  p.objects.push({
    type: "laser",
    x: 100,
    y: 300,
    to_x: 100,
    to_y: 1100,
    delay: 0.4,
  });
  const path = p.solution;
  // Join the beam canopy to the main drawing below the cargo dock.
  p.solution = [[60, 800], [140, 800], [140, 1020], ...path.toReversed()];
  p.objective.survive_until_end = true;
  return p;
}
const replace = (p, type, ...objects) => {
  p.objects = p.objects.filter((o) => o.type !== type).concat(objects);
  return p;
};
const recipes = [
  [
    "Through the Looking Glass",
    "Portal mouths reset momentum. Catch the core leaving the far mouth with a tall right backstop.",
    warp,
  ],
  [
    "Remote Doorbell",
    "A parcel arriving through a portal opens Pip's exit. Catch it before escorting Pip through the door.",
    () => escort(warp()),
  ],
  [
    "Two-Hop Post",
    "The first portal feeds a second mouth. Only the last exit points toward the receiving bay.",
    () => {
      const p = warp();
      replace(
        p,
        "portal",
        portal(200, 550, 320, 350),
        portal(320, 550, 400, 350, { vx: 5 }),
      );
      return p;
    },
  ],
  [
    "Opposite Addresses",
    "Two portal colors leave in opposite directions. Draw both outside walls, connected beneath the docks.",
    () =>
      delivery(
        [
          core(240, 350),
          core(480, 350, "amber"),
          portal(240, 550, 400, 350, { vx: 5, channel: "cyan" }),
          portal(480, 550, 320, 350, { vx: -5, channel: "amber" }),
          dock(600, 870),
          dock(120, 870, "amber"),
        ],
        [
          [80, 500],
          [80, 920],
          [360, 920],
          [640, 920],
          [640, 500],
        ],
        2,
      ),
  ],
  [
    "Passport Before Departure",
    "Stamp the falling parcel before it enters the portal. The far dock checks the passport.",
    () => {
      const p = warp();
      p.objects[0].route = ["depart"];
      p.objects.push(ring(200, 440, "depart"));
      p.objects.at(2).requires_checkpoints = ["depart"];
      return p;
    },
  ],
  [
    "Arrival Inspection",
    "A portal skips the workshop, but not customs: catch the core through the arrival ring beside the wall.",
    () => {
      const p = warp();
      p.objects[0].route = ["arrive"];
      p.objects.push(ring(610, 780, "arrive"));
      p.objects[2].requires_checkpoints = ["arrive"];
      return p;
    },
  ],
  [
    "Warp Cannon",
    "The portal exits onto a launch pad. Catch the ballistic shot on the far side.",
    () =>
      delivery(
        [
          core(200, 350),
          portal(200, 550, 300, 450),
          launch(300, 650, { vx: 6, vy: -8 }),
          dock(600, 980),
        ],
        [
          [640, 450],
          [640, 1020],
        ],
      ),
  ],
  [
    "Upside-Down Arrival",
    "This portal emerges inside reversed gravity. A sloping ceiling leads the rising parcel into its upper dock.",
    () => {
      const p = rise();
      replace(p, "cell", core(180, 350));
      p.objects.push(portal(180, 550, 300, 850));
      return p;
    },
  ],
  [
    "Magnetic Mail",
    "The exit has no sideways launch. Let the magnet pull the parcel, then stop it short of the pole.",
    () => {
      const p = pull();
      replace(p, "cell", core(180, 350));
      p.objects.push(portal(180, 550, 300, 350));
      p.objects.find((o) => o.type === "magnet").radius = 650;
      return p;
    },
  ],
  [
    "Portal Night Shift",
    "Deliver through the portal while the same line shields Pip from the live overhead beam.",
    () => shield(warp()),
  ],

  [
    "Ceiling Freight",
    "Gravity runs upward in the violet field. Draw an inclined ceiling, then a short roof over the upper dock.",
    rise,
  ],
  [
    "Sideways World",
    "A horizontal gravity field cancels the fall. Its right edge releases the core above the dock; add a backstop.",
    () =>
      delivery(
        [
          core(250, 500),
          gravity({ x: 400, y: 600, w: 360, h: 500, gx: 0.0014, gy: 0 }),
          dock(600, 980),
        ],
        [
          [640, 400],
          [640, 1020],
        ],
      ),
  ],
  [
    "Twin Ceiling Bays",
    "Two rising colors need separate ceiling slopes. Join the slopes along the top, clear of both launch positions.",
    () =>
      delivery(
        [
          core(280, 850),
          core(470, 850, "amber"),
          gravity({ x: 420, w: 500 }),
          dock(330, 400),
          dock(580, 400, "amber"),
        ],
        [
          [220, 500],
          [330, 350],
          [400, 350],
          [400, 700],
          [430, 700],
          [430, 500],
          [580, 350],
          [640, 350],
          [640, 700],
        ],
        2,
      ),
  ],
  [
    "Upside Inspection",
    "The core must rise through its ring before sliding along your ceiling to the dock.",
    () => {
      const p = rise();
      p.objects[0].route = ["up"];
      p.objects.push(ring(300, 690, "up"));
      p.objects[2].requires_checkpoints = ["up"];
      return p;
    },
  ],
  [
    "Ceiling Wormhole",
    "Catch the rising core in an upper portal. Its exit launches a falling parcel toward a lower dock.",
    () =>
      delivery(
        [
          core(270, 850),
          gravity({ x: 270, w: 140 }),
          portal(270, 450, 400, 350, { vx: 5 }),
          dock(600, 980),
        ],
        rightWall,
      ),
  ],
  [
    "Lateral Gravity Relay",
    "The first field sends cargo sideways into a portal. The exit field reverses its fall toward your ceiling.",
    () =>
      delivery(
        [
          core(200, 950),
          gravity({ x: 300, y: 950, w: 260, h: 100, gx: 0.0015, gy: 0 }),
          portal(390, 950, 450, 850),
          gravity({ x: 550, y: 600, w: 220, h: 600 }),
          dock(600, 400),
        ],
        roof,
      ),
  ],
  [
    "Low Orbit",
    "A sideways pull inside a weightless corridor builds momentum; its right boundary restores gravity. Catch the falling core.",
    () =>
      delivery(
        [
          core(250, 500),
          gravity({ x: 390, y: 600, w: 360, h: 500, gx: 0.0004, gy: 0 }),
          dock(600, 980),
        ],
        rightWall,
      ),
  ],
  [
    "Overhead Airlock",
    "Your ceiling docks a rising core to open a floor-level door. Pip must still reach the charger.",
    () => escort(rise()),
  ],
  [
    "Pole at the Ceiling",
    "Gravity pulls up and left, while the magnet counters sideways drift. Guide the rising core into the upper-right dock.",
    () => {
      const p = rise();
      p.objects.find((o) => o.type === "gravity").gx = -0.0004;
      p.objects.push(magnet({ x: 650, y: 300, radius: 700, strength: 0.0007 }));
      return p;
    },
  ],
  [
    "Gravity Blackout",
    "The rising delivery and Pip's beam canopy share one continuous line. Keep the canopy below the cargo route.",
    () => shield(rise()),
  ],

  [
    "Tractor Bay",
    "The pole pulls cargo down and right. Draw a wall before it overshoots the receiving bay.",
    pull,
  ],
  [
    "Push, Don't Pull",
    "A repelling pole behind the core drives it away. Catch the core on the opposite side.",
    () => {
      const p = pull();
      replace(
        p,
        "magnet",
        magnet({ x: 80, y: 300, repel: true, strength: 0.002 }),
      );
      return p;
    },
  ],
  [
    "Selective Attraction",
    "Each pole attracts only its marked cargo. Keep the amber parcel left and the cyan parcel right with two linked walls.",
    () =>
      delivery(
        [
          core(420, 350),
          core(300, 350, "amber"),
          magnet({ channel: "cyan" }),
          magnet({ x: 40, channel: "amber" }),
          dock(600, 870),
          dock(120, 870, "amber"),
        ],
        [
          [80, 500],
          [80, 920],
          [360, 920],
          [640, 920],
          [640, 500],
        ],
        2,
      ),
  ],
  [
    "Magnetic Slingshot",
    "An early repeller hands cargo to a lower attractor. The wall catches the accelerated approach.",
    () => {
      const p = pull();
      p.objects.push(
        magnet({ x: 90, y: 300, radius: 330, repel: true, strength: 0.0005 }),
      );
      return p;
    },
  ],
  [
    "Field Audit",
    "The curved magnetic approach must pass the inspection ring beside the dock. A wall keeps it in the audited lane.",
    () => {
      const p = pull();
      p.objects[0].route = ["field"];
      p.objects.push(ring(610, 830, "field", { w: 150, h: 150 }));
      p.objects[2].requires_checkpoints = ["field"];
      return p;
    },
  ],
  [
    "Pole to Portal",
    "A magnet pulls cargo into a side portal. Catch the remote exit; the source pole cannot reach that lane.",
    () =>
      delivery(
        [
          core(200, 350),
          magnet({ x: 600, y: 650, radius: 450, strength: 0.002 }),
          portal(465, 850, 160, 500, { vx: -6, w: 110, h: 110 }),
          dock(120, 980),
        ],
        [
          [80, 400],
          [80, 970],
        ],
      ),
  ],
  [
    "Magnetic Launch Feed",
    "A short magnetic pulse feeds the launch pad, then shuts off after 0.9 seconds. Catch the shot before it overshoots.",
    () =>
      delivery(
        [
          core(200, 350),
          magnet({ x: 300, y: 550, radius: 180, strength: 0.001, until: 0.9 }),
          launch(300, 550, { vx: 10, vy: -7, w: 120, h: 130 }),
          dock(600, 800, "cyan", { w: 36, h: 24 }),
        ],
        rightWall,
      ),
  ],
  [
    "Repulsor Airlock",
    "The repeller drives a core toward the far dock. Delivery unlocks the door for a walking robot.",
    () => {
      const p = pull();
      replace(
        p,
        "magnet",
        magnet({ x: 80, y: 300, repel: true, strength: 0.002 }),
      );
      return escort(p);
    },
  ],
  [
    "Two-Parcel Tow",
    "One field must deliver both parcels into separate stacked bays. Your backstop serves both arrivals.",
    () =>
      delivery(
        [
          core(200, 350),
          core(400, 350),
          magnet(),
          dock(590, 1010, "cyan", { w: 36, h: 24 }),
          dock(590, 860, "cyan", { w: 36, h: 24 }),
        ],
        [
          [640, 500],
          [640, 1020],
        ],
        2,
      ),
  ],
  [
    "Electromagnetic Shelter",
    "Route a parcel around the magnetic pole while your line also blocks the beam over Pip.",
    () => shield(pull()),
  ],

  [
    "Ballistic Delivery",
    "A launch pad gives the core a fixed impulse. Catch the arc rather than trying to draw under the pad.",
    jump,
  ],
  [
    "Double Bounce",
    "The first launch feeds a second elevated pad. The second impulse sends the parcel into your receiving wall.",
    () =>
      delivery(
        [
          core(200, 350),
          launch(200, 600, { vx: 4, vy: -6 }),
          launch(350, 550, { vx: 7, vy: -7, w: 100, h: 100 }),
          dock(600, 980),
        ],
        rightWall,
      ),
  ],
  [
    "Opposing Cannons",
    "Two launch pads fire in opposite directions. Catch both colors with a continuous pair of outer walls.",
    () =>
      delivery(
        [
          core(200, 350),
          core(520, 550, "amber"),
          launch(200, 600, { channel: "cyan" }),
          launch(520, 600, { vx: -8, vy: -4, channel: "amber" }),
          dock(600, 870),
          dock(120, 870, "amber"),
        ],
        [
          [80, 500],
          [80, 920],
          [360, 920],
          [640, 920],
          [640, 500],
        ],
        2,
      ),
  ],
  [
    "Ballistic Passport",
    "The launch arc must touch the high inspection ring before descending beside your backstop.",
    () => {
      const p = jump();
      p.objects[0].route = ["arc"];
      p.objects.push(ring(430, 480, "arc", { w: 160, h: 160 }));
      p.objects[2].requires_checkpoints = ["arc"];
      return p;
    },
  ],
  [
    "Launch Into Orbit",
    "The pad launches into a weightless corridor. At its edge, normal gravity drops cargo into the wall-side dock.",
    () =>
      delivery(
        [
          core(200, 350),
          launch(200, 600, { vx: 4, vy: 0 }),
          gravity({ x: 370, y: 600, w: 300, h: 300, gy: 0 }),
          dock(590, 1010, "cyan", { w: 36, h: 24 }),
        ],
        rightWall,
      ),
  ],
  [
    "Cannon Wormhole",
    "Intercept the arc with a portal, then stop its remote exit on the other side of the workshop.",
    () =>
      delivery(
        [
          core(200, 350),
          launch(),
          portal(420, 480, 160, 500, { vx: -6, w: 120, h: 130 }),
          dock(120, 980),
        ],
        [
          [80, 400],
          [80, 970],
        ],
      ),
  ],
  [
    "Tractor-Assisted Shot",
    "A modest launch brings the core into tractor range. Catch it over the pressure pad and hold the door until Pip reaches the charger.",
    () =>
      pressure({
        objects: [
          core(200, 350),
          launch(200, 600, { vx: 3, vy: -8 }),
          magnet({ radius: 550, strength: 0.002 }),
          plate(600, 930),
        ],
        solution: [
          [550, 930],
          [550, 970],
          [650, 970],
          [650, 750],
        ],
        objective: { type: "exit" },
      }),
  ],
  [
    "Launchgate",
    "Catch the launched parcel to open the escort gate. Pip needs the charger after the cargo arrives.",
    () => escort(jump()),
  ],
  [
    "Arc, Then Audit",
    "Inspect once on the rising arc and again on the descent. Both stamps must stay in order.",
    () => {
      const p = jump();
      p.objects[0].route = ["arc", "land"];
      p.objects.push(
        ring(430, 480, "arc", { w: 160, h: 160 }),
        ring(610, 830, "land"),
      );
      p.objects[2].requires_checkpoints = ["arc", "land"];
      return p;
    },
  ],
  [
    "Cannon Under Fire",
    "Your wall catches the cannon shot; the connected canopy must also protect Pip for the full shift.",
    () => shield(jump()),
  ],

  [
    "Hold the Door",
    "Catch a core in a U-shaped ink basket over the pressure pad. Its weight must hold the door open until Pip arrives.",
    () => pressure(),
  ],
  [
    "Double-Weight Lock",
    "This pad needs two cores at once. Make a basket wide enough for both; one parcel cannot hold the door.",
    () => {
      const p = load();
      replace(p, "cell", core(275, 350), core(325, 440));
      p.objects.find((o) => o.type === "plate").required = 2;
      return pressure(p);
    },
  ],
  [
    "Two Live Locks",
    "Two independent pads hold two doors. Build both cargo baskets in a single continuous stroke.",
    () => {
      const p = {
        objects: [
          core(280, 350),
          core(450, 350),
          plate(280, 720),
          plate(450, 720, { channel: "second" }),
          { type: "gate", x: 420, y: 970, w: 20, h: 140, channel: "second" },
        ],
        solution: [
          [220, 650],
          [220, 750],
          [340, 750],
          [340, 650],
          [390, 650],
          [390, 750],
          [510, 750],
          [510, 650],
        ],
        objective: { type: "exit" },
      };
      return pressure(p);
    },
  ],
  [
    "Load and Dispatch",
    "Hold one parcel over a pressure pad while the other reaches a dock. Both the door and delivery are required.",
    () => {
      const p = load();
      p.objects.push(
        core(450, 350, "amber", { vx: 4 }),
        dock(600, 980, "amber"),
      );
      p.solution = [...basket, [370, 320], [640, 320], [640, 1020]];
      p.objective = { type: "delivery", required_cells: 1, require_goal: true };
      pressure(p);
      const d = p.objects.find((o) => o.type === "socket");
      delete d.trigger_action;
      delete d.gate_channel;
      return p;
    },
  ],
  [
    "Remote Counterweight",
    "The falling core enters a portal above the pressure basket. Its remote weight holds Pip's door.",
    () => {
      const p = load();
      replace(p, "cell", core(180, 350));
      p.objects.push(portal(180, 550, 300, 450));
      return pressure(p);
    },
  ],
  [
    "Ceiling Counterweight",
    "Reversed gravity presses a core into a ceiling basket. Keep it inside the upper pad while Pip crosses below.",
    () => {
      const p = {
        objects: [core(300, 850), gravity({ x: 300, w: 220 }), plate(300, 430)],
        solution: [
          [230, 500],
          [230, 400],
          [370, 400],
          [370, 500],
        ],
        objective: { type: "exit" },
      };
      return pressure(p);
    },
  ],
  [
    "Magnetic Counterweight",
    "The magnet pulls the parcel onto a far pressure pad. A wall and shelf must hold it there, not merely touch it.",
    () => {
      const p = {
        objects: [core(200, 350), magnet(), plate(600, 930)],
        solution: [
          [550, 930],
          [550, 970],
          [650, 970],
          [650, 750],
        ],
        objective: { type: "exit" },
      };
      return pressure(p);
    },
  ],
  [
    "Ballistic Counterweight",
    "Catch the launched core inside a pressure basket high above Pip. The door closes if it bounces out.",
    () => {
      const p = {
        objects: [core(200, 350), launch(), plate(600, 850)],
        solution: [
          [530, 770],
          [530, 890],
          [650, 890],
          [650, 500],
        ],
        objective: { type: "exit" },
      };
      return pressure(p);
    },
  ],
  [
    "Twin Engine Interlock",
    "A portal feeds one pressure basket and a launch pad feeds the other. Hold both mechanisms through the crossing.",
    () => {
      const p = {
        objects: [
          core(180, 350),
          portal(180, 550, 280, 450),
          core(430, 350),
          launch(430, 600, { vx: 3, vy: -5 }),
          plate(280, 720),
          plate(600, 850, { channel: "second" }),
          { type: "gate", x: 420, y: 970, w: 20, h: 140, channel: "second" },
        ],
        solution: [
          [220, 650],
          [220, 750],
          [340, 750],
          [340, 650],
          [500, 650],
          [500, 890],
          [650, 890],
          [650, 500],
        ],
        objective: { type: "exit" },
      };
      return pressure(p);
    },
  ],
  [
    "The Hundredth Rescue",
    "Link the portal, gravity lift and cannon. Use the tractor to hold the pressure basket until both friends reach the charger.",
    () => {
      const p = {
        objects: [
          core(180, 350),
          portal(180, 550, 300, 850),
          gravity({ x: 300, y: 730, w: 180, h: 420 }),
          launch(300, 550, { vx: 6, vy: -5 }),
          magnet({ x: 660, y: 925, radius: 180, strength: 0.0015 }),
          plate(585, 900, { w: 24 }),
        ],
        solution: [
          [510, 850],
          [510, 950],
          [610, 950],
          [610, 450],
        ],
        objective: { type: "exit" },
        friends: true,
      };
      return pressure(p);
    },
  ],
];

export function createExpedition(base) {
  return recipes.map(([title, hint, make], index) => {
    const p = make(),
      id = index + 51;
    if (id === 100) p.objects.find((o) => o.type === "gate").x = 430;
    if (id === 59) {
      p.solution = [
        [500, 400],
        [500, 1020],
      ];
      p.objects.find((o) => o.type === "socket").x = 450;
    }
    if (id === 73) {
      p.solution = [
        [80, 1020],
        [80, 320],
        [640, 320],
        [640, 1020],
      ];
      for (const d of p.objects.filter((o) => o.type === "socket"))
        Object.assign(d, {
          x: d.accepts === "cyan" ? 590 : 130,
          y: 1010,
          w: 36,
          h: 24,
        });
    }
    if ([59, 71, 72, 74, 75, 78, 79, 80].includes(id)) {
      for (const d of p.objects.filter((o) => o.type === "socket")) {
        if (d.y === 980)
          Object.assign(d, {
            x: id === 59 ? d.x : 590,
            y: 1010,
            w: 36,
            h: 24,
          });
      }
    }
    return base(
      id,
      title,
      [
        "Fold space, keep your cargo.",
        "Gravity has a new direction.",
        "Follow the poles, mind the pull.",
        "Catch a little rocket.",
        "A rescue held in balance.",
      ][Math.floor(index / 10)],
      hint,
      [
        {
          ...floor,
          ...(p.escort || [54, 73, 83].includes(id) ? { x: 360, w: 660 } : {}),
        },
        {
          type: "robot",
          x: p.robotX ?? ([54, 73, 83].includes(id) ? 360 : 100),
          y: 1018,
          walk: !!p.escort,
        },
        ...(p.friends ? [{ type: "robot", x: 160, y: 1018, walk: true }] : []),
        ...p.objects,
      ],
      p.solution,
      {
        objective: p.objective,
        simulation_duration: 12,
        max_stroke_length:
          Math.ceil((length(p.solution) * 1.15 + 30) / 10) * 10,
        mechanic_id: "expedition_" + id,
        difficulty_tag:
          index % 10 === 9 ? "Chapter challenge" : "New machinery",
        expected_solution_tags: [
          title,
          ...new Set(p.objects.map((o) => o.type)),
        ],
      },
    );
  });
}
