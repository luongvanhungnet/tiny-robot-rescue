import Matter from "matter-js";
import { validateStroke, distance } from "./stroke.js";
const { Engine, Bodies, Body, Composite, Events } = Matter;
export class Simulation {
  constructor(level, onFinish = () => {}) {
    this.level = level;
    this.onFinish = onFinish;
    this.state = "READY";
    this.elapsed = 0;
    this.accumulator = 0;
    this.activated = new Set();
    this.goals = new Set();
    this.reason = "";
    this.stroke = [];
    this.entities = [];
    this.engine = Engine.create({
      gravity: { x: 0, y: 1, scale: 0.001 },
      positionIterations: 10,
      velocityIterations: 10,
    });
    this.build();
  }
  build() {
    this.level.objects.forEach((o, i) => {
      const fixed = ["platform", "goal", "switch", "gate"].includes(o.type),
        sensor = ["goal", "switch"].includes(o.type);
      const opts = {
        isStatic: fixed,
        isSensor: sensor,
        label: o.type,
        friction: 0.7,
        restitution: o.bounce ?? (o.type === "ball" ? 0.35 : 0.05),
        frictionAir: 0.001,
        collisionFilter: {
          category:
            { robot: 2, platform: 1, gate: 1, goal: 16, switch: 32 }[o.type] ??
            8,
          mask: 0xffff,
        },
      };
      let body = ["gear", "ball", "spring", "conveyor"].includes(o.type)
        ? Bodies.circle(o.x, o.y, o.type === "gear" ? 29 : 25, opts)
        : Bodies.rectangle(o.x, o.y, o.w ?? 44, o.h ?? 50, {
            ...opts,
            chamfer: o.type === "robot" ? { radius: 10 } : undefined,
          });
      if (o.type === "block") body = Bodies.rectangle(o.x, o.y, 64, 64, opts);
      body.plugin = { ...o, id: i, alive: true };
      Body.setAngle(body, o.rotation ?? 0);
      Composite.add(this.engine.world, body);
      this.entities.push(body);
    });
    Events.on(this.engine, "collisionStart", ({ pairs }) =>
      pairs.forEach(({ bodyA: a, bodyB: b }) => this.collide(a, b)),
    );
  }
  collide(a, b) {
    for (const [first, other] of [
      [a, b],
      [b, a],
    ]) {
      if (first.label === "robot" && other.collisionFilter.category === 8)
        this.finish(
          false,
          `Hit by ${other.label === "gear" ? "a falling gear" : other.label === "block" ? "a heavy block" : "a moving hazard"}.`,
        );
      if (
        first.label === "switch" &&
        ["ball", "gear", "spring", "block", "conveyor", "robot"].includes(
          other.label,
        )
      ) {
        this.activated.add(first.id);
        first.plugin.active = true;
        if (
          first.plugin.trigger_action === "capture_hazard" &&
          other.label !== "robot"
        ) {
          Body.setStatic(other, true);
          other.label = "captured";
          other.isSensor = true;
          other.collisionFilter.category = 0;
        }
        this.entities
          .filter((e) => e.label === "gate")
          .forEach((e) => {
            e.isSensor = true;
            e.plugin.open = true;
            Composite.remove(this.engine.world, e);
          });
      }
      if (first.label === "goal" && other.label === "robot")
        this.goals.add(other.id);
    }
  }
  start(points) {
    const error = validateStroke(points, this.level);
    if (error) return error;
    if (!["READY", "DRAWING"].includes(this.state))
      return "Retry to draw again.";
    this.stroke = points;
    points.slice(1).forEach((p, i) => {
      const a = points[i],
        len = distance(a, p);
      Composite.add(
        this.engine.world,
        Bodies.rectangle((a[0] + p[0]) / 2, (a[1] + p[1]) / 2, len + 8, 14, {
          isStatic: true,
          angle: Math.atan2(p[1] - a[1], p[0] - a[0]),
          label: "line",
          friction: 0.65,
          collisionFilter: { category: 4, mask: 0xffff },
        }),
      );
    });
    this.entities.forEach((b) => {
      if (!b.isStatic) {
        Body.setVelocity(b, { x: b.plugin.vx ?? 0, y: b.plugin.vy ?? 0 });
        Body.setAngularVelocity(b, b.label === "gear" ? 0.025 : 0);
      }
    });
    this.state = "SIMULATING";
    return null;
  }
  step(ms) {
    if (this.state !== "SIMULATING") return;
    this.accumulator += Math.min(ms, 100);
    while (this.accumulator >= 1000 / 60 && this.state === "SIMULATING") {
      this.tick();
      this.accumulator -= 1000 / 60;
    }
  }
  tick() {
    const robots = this.entities.filter((e) => e.label === "robot");
    this.entities.forEach((b) => {
      if (b.isStatic) return;
      Body.setVelocity(b, {
        x: Math.max(-10, Math.min(10, b.velocity.x)),
        y: Math.max(-12, Math.min(12, b.velocity.y)),
      });
      if (b.label === "robot") {
        Body.setAngularVelocity(b, 0);
        Body.setAngle(b, 0);
        if (b.plugin.walk) Body.setVelocity(b, { x: 2.1, y: b.velocity.y });
      }
      if (b.label === "conveyor")
        Body.setVelocity(b, { x: b.plugin.vx, y: b.velocity.y });
    });
    Engine.update(this.engine, 1000 / 60);
    this.elapsed += 1 / 60;
    if (
      robots.some(
        (b) => b.position.y > 1120 || b.position.x < -30 || b.position.x > 750,
      )
    )
      return this.finish(false, "Pip fell out of the workshop.");
    const obj = this.level.objective;
    // A charger must remain occupied until a switch gate has opened.
    this.entities
      .filter((b) => b.label === "goal")
      .forEach((goal) =>
        robots.forEach((r) => {
          if (
            Math.abs(r.position.x - goal.position.x) <
              (goal.plugin.w ?? 64) / 2 &&
            Math.abs(r.position.y - goal.position.y) < 70
          )
            this.goals.add(r.id);
        }),
      );
    if (obj.type === "exit" && this.goals.size === robots.length)
      return this.finish(true);
    if (
      obj.type === "switch" &&
      this.activated.size >= obj.required_switches &&
      (obj.require_goal
        ? this.goals.size === robots.length
        : this.elapsed >= this.level.simulation_duration)
    )
      return this.finish(true);
    if (this.elapsed >= this.level.simulation_duration)
      this.finish(
        obj.type === "survival",
        obj.type === "survival"
          ? ""
          : obj.type === "exit"
            ? "The charger is still waiting."
            : "The switch needs a little help.",
      );
  }
  finish(won, reason = "") {
    if (this.state !== "SIMULATING") return;
    this.state = won ? "WON" : "LOST";
    this.reason = reason;
    this.onFinish(won, reason);
  }
  destroy() {
    Events.off(this.engine);
    Composite.clear(this.engine.world, false);
    Engine.clear(this.engine);
  }
}
