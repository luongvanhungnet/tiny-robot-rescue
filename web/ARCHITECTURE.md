# Web edition architecture

`src/main.js` runs Phaser's scene lifecycle and vector rendering, maps mouse/touch into the fixed 720×1280 workshop, and presents DOM controls. The stage fits both desktop and mobile screens. Canvas rendering avoids a WebGL requirement for this vector-only game. A ResizeObserver refreshes Phaser's input bounds when the containing viewport changes.

`src/simulation.js` owns a standalone Matter.js engine. Rendering and input never create a second physics world: the browser and Node solution tests execute the same module. The engine advances in fixed 1/60-second steps only during SIMULATING. No random numbers affect level trajectories. A compound line is represented by a bounded set of overlapping static segment rectangles. Dynamic object speeds are capped; engine collision events handle hazards, switches, gates, and goals.

`src/stroke.js` validates raw/simplified geometry, samples segments against exclusion zones to catch fast pointer movement, and simplifies redundant vertices. `src/levels.js` defines all ten original levels, authored hints, objectives, and reference solution coordinates. Those coordinates are test metadata, never automatically played for users.

`src/save.js` owns schema validation, legacy-field migration, previous-valid backups, atomic localStorage key updates, and graceful storage-denied behavior. `src/services.js` deliberately disables advertising and billing for the slice. No remote service or secret is needed.

`vite.config.js` emits a service worker with the exact build asset list. Host the build at the origin root. `capacitor.config.json` points the Android wrapper to the same `dist/` output. The native wrapper is under `web/android/`; the previous Godot project is separately preserved at repository-root `android/`.

Tests: Node tests run actual Matter.js solutions, failure paths, geometry rules, save recovery, and disabled monetization. Playwright tests use real mouse and CDP touch events, resize the stage, exercise UI/progression/settings, and draw all ten authored solutions through the canvas. A separate production check disables networking, reloads from the service worker, and completes a puzzle.
