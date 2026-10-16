> Historical prototype document. Current production behavior is documented in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), [WIFI_PROTOCOL.md](WIFI_PROTOCOL.md), and [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md). BLE, sample-data, and cup-calibration sections below are superseded.

# LIQUID STORE: MASTER SPEC (GREENFIELD BUILD)

# ROLE
You are a senior Flutter engineer and UI/motion designer specializing in
health-tech and IoT companion apps. You have deep experience with
CustomPainter, physics-based animation, clean architecture, and
hardware-synced real-time UIs. You design with restraint: every animation
must communicate hardware state or progress, never decorate.

# CONTEXT
- Product: "SipSync", a Flutter mobile app that tracks WATER intake
  only. There is a single beverage type, so the data model, UI, and copy
  must never include beverage categories, type selectors, or type-based
  icons/colors. It will sync with a smart coaster/scale hardware device.
- Current state: NOTHING IS IMPLEMENTED. There is only a visual reference
  of three screens in docs/reference/ (home.png, history.png,
  settings.png). The app, the data layer, and the hardware integration all
  need to be built. The reference is functional but flat; this build
  upgrades it into a gamified, visually rich experience.
- Hardware is not integrated yet. The real BLE/coaster layer will be added
  later by the developer. Therefore the app is built against a hardware
  abstraction (repository interfaces) with a fake implementation now. The
  real implementation must be swappable later with ZERO UI changes.
- Reference screen content (use as seed data and layout reference):
  - Home: header "SipSync", "Last sip: 12m ago", circular ring showing
    1450 / 2000 ml, "Cup Weight: 350g", and an "Automated Sip Log" list
    (45ml sip 10:30 AM, 120ml sip 11:15 AM, 250ml sip 08:00 AM), each with
    a three-dot overflow menu. The reference log is out of order; the
    build sorts it newest-first.
  - History: Weekly Intake chart (Tue-Mon, blank in the reference), Average
    Intake 1850ml, Weekly Total 12.9L, Best Streak 5 Days, Archive rows
    (Monday 2100ml "Goal Met!", Sunday 1950ml "Almost there!",
    Saturday 1600ml).
  - Settings: Daily Goal slider (2000 ml, range 1L-4L), Adaptive Reminders
    toggle with Inactivity Threshold slider (45 mins), and a
    "Calibrate Empty Cup Weight" button with helper text about calibrating
    with an empty cup.
  - Bottom nav: Home / History / Settings.
- Audience: everyday users who want a calm, rewarding, glanceable
  experience, not a "game". Tone is encouraging and never shaming.

# DATA CONTRACT (the hardware-facing source of truth)
Define these in the domain layer and treat them as stable. Names may be
refined in Phase 0 but must then be frozen.
- SipEvent { id, volumeMl, timestamp }
- CupWeightReading { grams, timestamp }
- CalibrationResult { status: success | failure | timeout, measuredGrams }
- CoasterConnection { connected | disconnected | connecting, lastSeen }
- UserSettings { dailyGoalMl, inactivityThresholdMinutes,
  adaptiveRemindersEnabled }
- DailySummary { date, totalMl, goalMl }  (history is derived from sips
  plus the goal that applied that day)
- Repository interfaces: CoasterRepository (streams: sips, weight,
  connection; method: calibrate()), SettingsRepository (read/write
  settings), HistoryRepository (daily summaries, sip log for a day).
- Derived values (streak, averages, weekly total, hydration state,
  freshness phase, seal tier) are computed in the presentation/domain
  layer from the contract, never stored as new hardware fields.
- Fake implementations (FakeCoasterRepository etc.) ship in lib/data/fake/,
  are seeded from the reference content, can emit simulated sips, weight
  changes, calibration outcomes (including failure), and disconnects, and
  are clearly named as fakes. A debug panel to trigger these is allowed
  behind kDebugMode.

# GOAL
Build three screens as a gamified, visually rich hydration experience.
"Gamified" means exactly these four water-themed pillars. Do NOT add RPG
quests, missions, XP, levels, avatars, coins, loot, leaderboards, or badge
collections beyond what is specified here.

PILLAR 1: Living water physics and vessel progression (Home)
- A fluid vessel (glass container silhouette) replaces the circular ring.
  Water rises toward the daily goal with two layered sine-wave surfaces at
  different phases and speeds, translucency, and depth shading (denser blue
  at the bottom, light caustics near the surface).
- Slosh responds to device tilt (damped spring settling); tap makes a
  ripple.
- Numeric readout (current ml / goal ml) stays legible over the water.
- Dynamic hydration state label (defaults, refinable in Phase 1):
  0-24% "Just Getting Started", 25-49% "Steady Stream",
  50-79% "Optimal Flow", 80-99% "Nearly Full", 100%+ "Full Reservoir".
  "Thirst Quenched" is a transient celebratory label shown briefly after a
  sip.

PILLAR 2: Automated coaster event feedback (Home)
- On every sip: droplet/ripple burst from the water surface, a floating
  "+X ml" that rises and fades, and a level-rise tween (never a snap).
- "Last sip" becomes a freshness meter: crisp cool blue right after a sip,
  gradually desaturating and dimming as elapsed time approaches the
  inactivity threshold, then a gentle "dry" state, never alarming.
  Defaults: 0-50% of threshold = fresh, 50-100% = fading, over 100% = dry.
  Never color alone: pair with an icon and text.
- "Automated Sip Log" becomes a droplet timeline, newest first. Each entry
  shows ml, time, and a droplet icon sized proportionally to volume, one
  consistent style. Keep the three-dot overflow menu (default actions:
  delete entry, adjust volume; state this choice in the phase summary).
  New sips animate in.
- "Cup Weight" becomes a live scale chip that subtly pulses when weight
  changes.

PILLAR 3: Streak and daily goal milestones (History)
- "Best Streak" becomes an evolving water-drop badge that fills, charges,
  and glows with streak length. Tiers: 1-2, 3-6, 7-13, 14-29, 30+ days.
  Animate fill changes; show progress to the next tier.
- Weekly Intake becomes fillable glass columns (Tue-Mon, current day
  highlighted) filling from the bottom, with a goal line. Design loading,
  empty, and data states.
- Archive rows become milestone seals: glowing "Goal Met!" water seal with
  ripple at 100%+, partial completion ring for "Almost there!" at 80-99%,
  muted state below 80%. Preserve day name, ml total, and status text.
- "Average Intake" and "Weekly Total" stay as stat cards with count-up
  animation.

PILLAR 4: Fluid, tactile hardware controls (Settings)
- Daily Goal and Inactivity Threshold sliders: droplet-shaped thumb,
  elastic drag with overshoot and settle, liquid-filled track, haptic ticks
  at snap points, live value updating smoothly while dragging.
- Adaptive Reminders toggle becomes a liquid switch (water fills the track,
  thumb morphs like a droplet).
- Glassmorphic card surfaces (blurred backdrop, subtle border, inner
  highlight) with a solid-color fallback for low-end devices.
- "Calibrate Empty Cup Weight" becomes a tare ritual state machine: idle,
  prompt ("Place your empty cup on the coaster"), measuring
  (liquid-fill/zeroing animation, live weight converging), success
  (ripple + "Zeroed ✓ 350 g"), failure/timeout (clear retry). Keep the
  helper text.

# CONSTRAINTS

Architecture
- State management: Riverpod (flutter_riverpod). Layers: domain (models,
  repository interfaces, pure logic), data (fake now, real later),
  presentation (theme, widgets, screens, view models).
- Widgets depend only on view models/providers, never on concrete
  repositories. Swapping Fake* for real hardware implementations is a
  one-line provider override.
- Pure logic (hydration state, freshness phase, streak, seal tier, sip
  merging, day rollover) lives in domain functions with unit tests.
- Animations are driven by contract events and data, never by hardcoded
  values in widgets. Mock data only in lib/data/fake, previews, and tests.

Edge cases to handle
- Coaster disconnected (frozen "last known" state + reconnect hint), intake
  over goal (vessel never visually overflows, "Full Reservoir"), goal
  changed mid-day (level re-tweens), rapid consecutive sips (merge window
  so animations don't stack), midnight rollover, empty data, calibration
  failure/timeout.

Flutter / technical
- Approved dependencies ONLY: flutter_riverpod, flutter_animate,
  sensors_plus, shared_preferences (settings persistence). Anything else
  needs a one-line justification and my approval.
- Core techniques: CustomPainter + AnimationController for waves,
  flutter_animate for micro-sequences, SpringSimulation for elastic
  controls, BackdropFilter for glass, HapticFeedback for ticks. Fragment
  shaders and Rive are OPTIONAL upgrades in Phase 6; everything must work
  without them.
- Performance: 60 fps on mid-range Android. RepaintBoundary, no setState
  in animation loops, capped particle counts, dispose all controllers and
  subscriptions, "reduced effects" mode.
- Accessibility: respect MediaQuery.disableAnimations; Semantics labels
  with current ml, goal, hydration state, streak; WCAG AA contrast over
  water; no color-only signalling; 48dp tap targets; text scaling to 200%.
- Visual language: water only (blues, teals, aqua highlights, glass,
  droplets, ripples). Light mode plus a coherent dark mode (deep-water
  palette). Keep the 3-tab navigation and information hierarchy of the
  reference.
- All colors, radii, durations, and curves come from one tokens file. No
  magic numbers in widgets.

# WORKING RULES (every phase)
1. Read this spec fully before starting.
2. Do only the current phase. Do not start later phases.
3. No placeholders like "// implement here" or "TODO". If something can't
   be completed, say so explicitly.
4. Every component takes data via constructor parameters or providers (no
   hardcoded values) and includes a short usage example in a doc comment
   or preview.
5. Code must pass `flutter analyze` with no warnings.
6. Prefer small, focused files.
7. When a decision is ambiguous, pick a default, state it in one line, and
   proceed.
8. End every phase with: (a) files created/modified, (b) what to test
   manually, (c) deviations or blockers, (d) the exact words
   "PHASE COMPLETE: waiting for approval". Then stop.

# FINAL DEFINITION OF DONE
- All four pillars implemented across the three screens.
- The app runs fully on the fake repositories, and a documented one-line
  swap points to where real hardware plugs in.
- 60 fps on a mid-range Android device, reduced-motion respected, light
  and dark modes polished.