# Web edition architecture

`src/main.js` runs Phaser's scene lifecycle and vector rendering, maps mouse/touch into the fixed 720×1280 workshop, and presents DOM controls. The stage fits both desktop and mobile screens. Canvas rendering avoids a WebGL requirement for this vector-only game. A ResizeObserver refreshes Phaser's input bounds when the containing viewport changes.

`src/simulation.js` owns a standalone Matter.js engine. Rendering and input never create a second physics world: the browser and Node solution tests execute the same module. The engine advances in fixed 1/60-second steps only during SIMULATING. No random numbers affect level trajectories. A compound line is represented by a bounded set of overlapping static segment rectangles. Dynamic object speeds are capped; engine collision events handle hazards, switches, gates, and goals.

`src/stroke.js` validates raw/simplified geometry, samples segments against exclusion zones to catch fast pointer movement, and simplifies redundant vertices. `src/levels.js` defines all 100 levels, authored hints, objectives, and reference solution coordinates. Those coordinates supply tested visual hint examples; players still draw their own physical strokes.

`src/save.js` owns schema validation, legacy-field migration, previous-valid backups, atomic localStorage key updates, and graceful storage-denied behavior. `src/services.js` deliberately disables advertising and billing for the slice. No remote service or secret is needed.

`vite.config.js` emits a service worker with the exact build asset list. Host the build at the origin root. `capacitor.config.json` points the Android wrapper to the same `dist/` output. The native wrapper is under `web/android/`; the previous Godot project is separately preserved at repository-root `android/`.

Tests: Node tests run actual Matter.js solutions, failure paths, geometry rules, save recovery, and disabled monetization. Playwright tests use real mouse and CDP touch events, resize the stage, exercise UI/progression/settings, and draw all 100 authored solutions through the canvas. A separate production check disables networking, reloads from the service worker, and completes a puzzle.

`src/content.js` defines the eleven chapter ranges, milestone badges, and earned paint palettes. Progress validates paint IDs and unlock requirements on load and selection, including saves created before paints existed. Robot rendering reads the selected palette; cosmetic choices do not change physics.

Power Lab introduces a `delivery` objective: nonlethal dynamic `cell` bodies must reach matching `socket` sensors. Docks can require an inspection key stored per core; delivered IDs are recorded once and cargo becomes stationary. Lost required cargo fails the attempt. `fan` sensors apply mass-scaled forces during fixed simulation steps. `laser` emitters use `src/optics.js` to find the closest polygon surface, so rotated ink segments and solid terrain occlude beams; planning and pause do not advance laser warmup. Delivery puzzles may additionally require survival through the full timer.

Relay Hub adds ordered inspection routes (`cell.route` and `socket.requires_checkpoints`), while preserving legacy single-ring requirements. Repeated contact with a visited ring is idempotent; a new ring out of order fails the attempt. Docks with `trigger_action: open_gate` use `gate_channel` to open only matching gates. Delivery objectives can require robot arrival as well as cargo completion. Optional fan `affects` lists let cargo lifts leave robots unaffected. Pulsed lasers use simulation time, so their phase does not advance while planning or paused.

Grand Circuit uses the existing fixed-step mechanics for robot-only lift fields, multiple filled-once receiving docks, and the two-robot/two-parcel final objective. Draw-zone validation allows only a tiny floating-point epsilon; level 50's authored path also stays clear of the zone boundary to accommodate real browser pointer quantization.

`src/hint.js` contains independent visual guide state and geometry. It copies the level example, interpolates animation by cumulative arc length, and produces dashed segments that preserve corners. The scene renders a cyan start circle, tracer, dashed route, and end marker without adding physics bodies. Reduced-motion mode shows the full path immediately. Hint UI resets running/lost attempts through normal level startup when explicitly requested, and clears the guide on valid submission or navigation.


## Expedition machinery (51–100)

`src/expedition.js` appends 50 authored recipes to the unchanged first 50 levels. Shared dimensions and fixtures do not clone old layouts. Each recipe adds a distinct dependency or cargo topology; solution length determines the ink budget. New levels always require one or more systems absent from levels 1–50.

`src/machines.js` applies cargo-only gravity replacement and radial magnetic forces before the same fixed-step Matter.js update. After physics, portals reset exit position/velocity, launchers apply directed impulses, and live pressure plates measure continuous occupancy. A per-core 0.3-second machine cooldown prevents retrigger loops. Portals and launchers can filter cargo channels. Magnetic fields have bounded range, optional channel filtering, repulsion and simulation-time pulse expiry.

Pressure plates count core centers inside their rectangle, accumulate 1.5 seconds of uninterrupted load and reset immediately on unload. Each plate opens only its linked gate channel; unloaded pressure gates return to the physics world exactly once. They differ from existing one-shot cargo and switch gates, which remain unchanged. Goal completion still requires every robot. The finale's dependency test removes each machine system independently and must fail each time.

`src/machine-art.js` renders paired portal pips, entry/exit arrows, gravity vectors/weightless rings, +/- poles and range circles, launch vectors, pressure counts, hold-progress bars and gate links. Symbols accompany colors. The Machines dialog pauses simulation and explains the current level's systems. No remote services or credentials are required.

`tests/expedition.test.js` checks all 50 additions with drawing perturbations, machine removal, ineffective ink, actual usage of every advertised machine, stateful machine rules, invalid definitions and old/final save continuity. Browser campaign tests read the full levels array, so their default target is 100. `tests/browser/expedition.spec.js` adds real mouse/touch checks for every new chapter, the finale, guide/help behavior, and old level-50 continuation.
