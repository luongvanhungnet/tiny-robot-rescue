import Matter from "matter-js";
import { traceBeam } from "./optics.js";
import { applyMachines, updateMachines, machineTypes } from "./machines.js";
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
    this.delivered = new Set();
    this.stamps = new Map();
    this.usedMachines = new Set();
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
      const fixed =
          [
            "platform",
            "goal",
            "switch",
            "gate",
            "fan",
            "laser",
            "socket",
            "checkpoint",
          ].includes(o.type) || machineTypes.includes(o.type),
        sensor =
          ["goal", "switch", "fan", "laser", "socket", "checkpoint"].includes(
            o.type,
          ) || machineTypes.includes(o.type);
      const opts = {
        isStatic: fixed,
        isSensor: sensor,
        label: o.type,
        friction: o.type === "cell" ? 0.12 : 0.7,
        restitution: o.bounce ?? (o.type === "ball" ? 0.35 : 0.05),
        frictionAir: 0.001,
        collisionFilter: {
          category:
            {
              robot: 2,
              platform: 1,
              gate: 1,
              goal: 16,
              switch: 32,
              cell: 64,
              socket: 128,
              fan: 256,
              laser: 256,
              checkpoint: 128,
              portal: 256,
              gravity: 256,
              magnet: 256,
              launcher: 256,
              plate: 256,
            }[o.type] ?? 8,
          mask: 0xffff,
        },
      };
      let body = [
        "gear",
        "ball",
        "spring",
        "conveyor",
        "cell",
        "checkpoint",
      ].includes(o.type)
        ? Bodies.circle(
            o.x,
            o.y,
            o.type === "gear"
              ? 29
              : o.type === "cell"
                ? 18
                : o.type === "checkpoint"
                  ? Math.min(o.w, o.h) / 2
                  : 25,
            opts,
          )
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
        this.openGates(first.plugin.channel ?? null);
      }
      if (first.label === "checkpoint" && other.label === "cell") {
        const stamps = this.stamps.get(other.id) ?? new Set();
        if (
          other.plugin.route &&
          !stamps.has(first.plugin.key) &&
          other.plugin.route[stamps.size] !== first.plugin.key
        ) {
          this.finish(
            false,
            "The core visited inspection rings in the wrong order.",
          );
          continue;
        }
        stamps.add(first.plugin.key);
        this.stamps.set(other.id, stamps);
        first.plugin.active = true;
      }
      if (first.label === "socket" && other.label === "cell") {
        if (
          first.plugin.accepts &&
          first.plugin.accepts !== other.plugin.channel
        ) {
          this.finish(false, "That core belongs in the other dock.");
          continue;
        }
        const visits = this.stamps.get(other.id) ?? new Set();
        const required = first.plugin.requires_checkpoint;
        const route = first.plugin.requires_checkpoints ?? [];
        if (
          (required && !visits.has(required)) ||
          route.some((key, index) => [...visits][index] !== key)
        ) {
          this.finish(false, "The core missed its inspection ring.");
          continue;
        }
        if (first.plugin.filled) continue;
        first.plugin.filled = true;
        if (first.plugin.trigger_action === "open_gate")
          this.openGates(first.plugin.gate_channel ?? null);
        this.delivered.add(other.id);
        Body.setStatic(other, true);
        Body.setPosition(other, { x: first.position.x, y: first.position.y });
        other.label = "delivered";
        other.isSensor = true;
        other.collisionFilter.category = 0;
      }
      if (first.label === "goal" && other.label === "robot")
        this.goals.add(other.id);
    }
  }
  openGates(channel = null) {
    this.entities
      .filter(
        (e) => e.label === "gate" && (!channel || e.plugin.channel === channel),
      )
      .forEach((e) => {
        e.isSensor = true;
        e.plugin.open = true;
        Composite.remove(this.engine.world, e);
      });
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
    for (const fan of this.entities.filter((b) => b.label === "fan")) {
      for (const body of this.entities.filter(
        (b) =>
          !b.isStatic && ["cell", "robot", "ball", "gear"].includes(b.label),
      )) {
        if (
          (!fan.plugin.affects || fan.plugin.affects.includes(body.label)) &&
          Math.abs(body.position.x - fan.position.x) <= fan.plugin.w / 2 &&
          Math.abs(body.position.y - fan.position.y) <= fan.plugin.h / 2
        ) {
          Body.applyForce(body, body.position, {
            x: body.mass * (fan.plugin.force_x ?? 0),
            y: body.mass * (fan.plugin.force_y ?? 0),
          });
        }
      }
    }
    applyMachines(this);
    Engine.update(this.engine, 1000 / 60);
    this.elapsed += 1 / 60;
    updateMachines(this);
    if (
      robots.some(
        (b) => b.position.y > 1120 || b.position.x < -30 || b.position.x > 750,
      )
    )
      return this.finish(false, "Pip fell out of the workshop.");
    for (const laser of this.entities.filter((b) => b.label === "laser")) {
      const elapsed = this.elapsed - (laser.plugin.delay ?? 0);
      laser.plugin.active =
        elapsed >= 0 &&
        (!laser.plugin.period ||
          elapsed % laser.plugin.period <
            (laser.plugin.on_duration ?? laser.plugin.period));
      const hit = traceBeam(
        laser.position,
        { x: laser.plugin.to_x, y: laser.plugin.to_y },
        Matter.Composite.allBodies(this.engine.world).filter(
          (b) =>
            !b.isSensor &&
            ["robot", "line", "platform", "gate"].includes(b.label),
        ),
      );
      laser.plugin.beamEnd = { x: hit.x, y: hit.y };
      if (laser.plugin.active && hit.body?.label === "robot")
        return this.finish(false, "Pip crossed an unshielded laser beam.");
    }
    const obj = this.level.objective;
    if (
      obj.type === "delivery" &&
      this.delivered.size >= (obj.required_cells ?? 1) &&
      (!obj.require_goal || this.goals.size === robots.length) &&
      (!obj.survive_until_end || this.elapsed >= this.level.simulation_duration)
    )
      return this.finish(true);

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
    if (obj.type === "delivery") {
      const recoverable = this.entities.filter(
        (b) =>
          b.label === "cell" &&
          b.position.x >= -40 &&
          b.position.x <= 760 &&
          b.position.y <= 1160,
      ).length;
      if (this.delivered.size + recoverable < obj.required_cells)
        return this.finish(false, "An energy core left the delivery area.");
    }
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
          : obj.type === "delivery"
            ? obj.require_goal && this.delivered.size >= obj.required_cells
              ? "The core arrived, but Pip still needs the charger."
              : "The energy cores are still waiting for delivery."
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
