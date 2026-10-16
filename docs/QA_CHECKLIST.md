> Historical prototype document. Current production behavior is documented in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), [WIFI_PROTOCOL.md](WIFI_PROTOCOL.md), and [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md). BLE, sample-data, and cup-calibration sections below are superseded.

# Quality Assurance & Performance Profiling Checklist: SipSync

This checklist serves as the acceptance gate for **SipSync (Phase 5 Quality Pass)**. All checks must pass on a physical Android or iOS device before certification.

---

## 1. On-Device Performance & Profiling (60 FPS Gate)

SipSync relies on fluid procedural canvases, glassmorphism, and particle systems. All features must sustain a locked **60 FPS** (frame raster time $\le 16.6\text{ms}$) on mid-tier physical hardware.

### Profile Mode Profiling Commands

#### 1. Launch in Profile Mode (Disable JIT compilation overhead)
```bash
# Physical iOS Device
flutter run --profile -d <DEVICE_ID>

# Physical Android Device
flutter run --profile -d <DEVICE_ID>
```

#### 2. Open Flutter DevTools Performance Overlay
```bash
flutter run --profile --trace-skia
```
Press `P` in the terminal to toggle the Performance Overlay on screen, or open the DevTools URL printed in the terminal.

#### 3. Inspect Frame Raster Budget
- Ensure the upper bar (GPU/Rasterizer) and lower bar (UI Thread) stay well below the green horizontal line ($16.6\text{ms}$).
- Verify no red spikes occur during:
  - Home Screen water wave continuous slosh
  - Sip Feedback droplet burst animation
  - History GlassColumnChart initial cascade fill
  - Settings DropletSlider continuous drag
  - TareRitualButton ripple pulse

#### 4. Memory Leak Audit
- In DevTools Memory Profiler, record an initial snapshot.
- Rapidly switch between Home, History, and Settings tabs $30\times$.
- Force Garbage Collection (GC) in DevTools.
- Verify that `AnimationController`, `StreamSubscription`, and `SensorsPlus` listeners do not multiply or leak across tab transitions.

---

## 2. Pillar 1: Home & Liquid Vessel

| Verification Item | Expected Behavior | Pass/Fail |
| :--- | :--- | :--- |
| **Dual Sine-Wave Rendering** | Surface animates with two distinct phase velocities and translucent depth gradient; denser at bottom. | [ ] |
| **Painted Caustics** | Surface features curved specular caustics without requiring runtime fragment shaders. | [ ] |
| **Over-Goal Geometry Clamping** | When daily intake exceeds goal (e.g. 2500ml / 2000ml), fill level clamps stably below top rim; water never overflows container bounds. | [ ] |
| **Tilt Slosh & Touch Ripples** | Device tilt deflects water angle with spring damping; tapping canvas spawns localized ripple ring. | [ ] |
| **Central Numeric Contrast** | High-contrast readout (`1450 / 2000 ml`) remains clearly legible over translucent water via backing scrim. | [ ] |
| **Hydration Progression Labels** | Label matches volume threshold: *Just Getting Started* (<25%), *Steady Stream* (25-49%), *Optimal Flow* (50-79%), *Nearly Full* (80-99%), *Full Reservoir* (100%+). | [ ] |
| **Reduced-Motion Fallback** | When "Reduce Motion" is enabled, surface renders static level without continuous sine waves or tilt slosh. | [ ] |

---

## 3. Pillar 2: Micro-Feedback & Real-Time Tracking

| Verification Item | Expected Behavior | Pass/Fail |
| :--- | :--- | :--- |
| **Floating Sip Badge** | When sip is detected, floating `+X ml` badge ascends and fades smoothly over vessel center. | [ ] |
| **Droplet Particle Burst** | 8 particle droplets spray upward and arc naturally with simulated gravity; capped to avoid GPU thrash. | [ ] |
| **Transient "Thirst Quenched"** | Vessel subhead displays "Thirst Quenched" for 3 seconds post-sip, then reverts to progression label. Rapid sips reset the 3s timer. | [ ] |
| **Freshness Meter Phases** | Transitions accurately: *Fresh* ($\le$ inactivity threshold), *Fading* (threshold to $2\times$), *Dry* ($> 2\times$). Always pairs icon + copy (never color alone). | [ ] |
| **Live Scale Weight Chip** | Displays real-time coaster load (`Cup Weight: 350g`) with subtle pulse; focusable label present without screen-reader chatter. | [ ] |
| **Timeline Management** | Inline adjust volume dialog (`10ml - 1500ml`) and delete confirmation accurately mutate `todaySipsViewModelProvider` and daily total. | [ ] |
| **Empty State** | Friendly non-shaming illustration and copy displayed when no sips have been recorded yet today. | [ ] |

---

## 4. Pillar 3: History & Gamified Retention

| Verification Item | Expected Behavior | Pass/Fail |
| :--- | :--- | :--- |
| **Dynamic Rolling 7-Day Window** | Columns render trailing 7 days relative to anchor date; day labels reflect correct calendar weekdays (not hardcoded). | [ ] |
| **Current Day Highlight** | Today's column is highlighted in aqua with bold day label; historical columns display glass sheen. | [ ] |
| **Top Rim Goal Pip** | Columns at or above 100% display glowing aqua pip at the top glass rim. | [ ] |
| **Interactive Column Tooltip** | Tapping any glass column presents floating badge showing exact milliliters logged on that date. | [ ] |
| **StreakDropBadge Tiers** | Fills across 5 distinct tiers (1-2, 3-6, 7-13, 14-29, 30+ days) with ambient breathing glow and progression copy (e.g., "2 days to next tier"). Zero-streak state renders gracefully. | [ ] |
| **Stat Cards Count-Up** | Average Intake and Weekly Total cards count up smoothly on entrance; immediate display on reduced motion. | [ ] |
| **Milestone Seal Tiers** | Archive rows render 3 tiers: *Goal Met* (green check + breathing ripple), *Almost There* (proportional circular arc), *Under Goal* (muted drop, non-shaming neutral phrasing). | [ ] |

---

## 5. Pillar 4: Smart Settings & Hardware Calibration

| Verification Item | Expected Behavior | Pass/Fail |
| :--- | :--- | :--- |
| **DropletSlider Range & Step** | Daily Goal slides from 1000ml to 4000ml (100ml step); Inactivity Threshold slides from 15m to 120m (5m step). | [ ] |
| **I/O Debounce Defense** | Live drag updates UI smoothly; disk persistence to `SharedPreferences` only triggers on drag release (`onChangeEnd`). | [ ] |
| **LiquidSwitch Haptic & Morph** | Adaptive Reminders toggle fills with water and morphs thumb; inactivity threshold disables gracefully when reminders off. | [ ] |
| **Tare Ritual 7-State Workflow** | Cycles cleanly through `TareIdle` $\rightarrow$ `TarePrompt` $\rightarrow$ `TareMeasuring` $\rightarrow$ `TareSuccess` (with auto-revert after 3s). | [ ] |
| **Tare Disconnect & Failure** | Dropping connection mid-calibration displays `TareDisconnected`; unstable load displays retry prompt. | [ ] |
| **Settings Persistence** | Restarting app reloads committed goal, threshold, reminder toggle, and tared cup weight from disk. | [ ] |

---

## 6. Edge Cases & Hardware Failures

| Verification Item | Expected Behavior | Pass/Fail |
| :--- | :--- | :--- |
| **Midnight Rollover (Foreground)** | Leaving app open past 12:00 AM triggers passive wall-clock timer: today resets to 0ml, yesterday archives cleanly. | [ ] |
| **Midnight Rollover (Background)** | Backgrounding app on Monday and resuming on Tuesday detects date change via `WidgetsBindingObserver` and syncs day. | [ ] |
| **Mid-Sip Bluetooth Disconnect** | Disconnecting coaster while drinking halts live streaming; reconnecting restores scale state without app crash. | [ ] |
| **Extreme Intake Clamping** | Logging 5000ml intake updates readout (`5000 / 2000 ml`), maintains vessel water level clamp, and displays *Full Reservoir*. | [ ] |
| **Mid-Day Goal Mutation** | Changing goal from 2000ml to 3000ml in Settings instantly updates progress ratio on Home and History columns. | [ ] |
| **DebugPanel Release Exclusion** | In Release builds (`kReleaseMode`), the floating debug flask FAB is completely stripped from the widget tree. | [ ] |

---

## 7. Accessibility (A11y) Verification

| Verification Item | Expected Behavior | Pass/Fail |
| :--- | :--- | :--- |
| **200% Text Scaling** | In device Accessibility Settings, set font size to largest (200%). Verify **zero** yellow-black striped RenderFlex overflow exceptions occur on Home, History, or Settings. | [ ] |
| **Screen Reader Navigation (VoiceOver / TalkBack)** | All interactive controls, sliders, switches, columns, and tiles announce descriptive semantic labels. | [ ] |
| **Discrete Sip Announcement** | Logged sips trigger a polite single announcement (`Logged X ml water sip`) via `SemanticsService.sendAnnouncement`. | [ ] |
| **Minimum 48dp Tap Targets** | All buttons, tabs, slider thumbs, overflow menus, and column hit areas meet or exceed $48\times 48\text{dp}$. | [ ] |
| **Dark Mode Contrast** | In Dark Theme, primary text luminance $\ge 0.8$, surface contrast $\ge 4.5:1$ (WCAG AA), glass borders clearly demarcate surfaces. | [ ] |
