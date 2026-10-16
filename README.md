# SipSync

Flutter mobile hydration tracker for a Wi-Fi ESP32 coaster and one fixed **258 g cup**. Real sips are saved in SQLite; production starts with zero intake and no sample records.

## Set up the ESP32

1. Open `firmware/smart_coaster/smart_coaster.ino` in Arduino IDE, keeping `coaster_firmware.cpp`, `CupTracker.h`, and `DailyProgress.h` beside it.
2. Select your actual classic ESP32 board. GPIO4 touch requires classic ESP32 support. Compilation was checked with **ESP32 Dev Module**, core **3.3.12**.
3. Install **HX711 0.6.5**, **WebSockets 2.7.2** (Links2004), and **ArduinoJson 7.4.3**.
4. Confirm the original pin assignments and relay OFF behavior match your circuit, then upload.
5. First setup: remove the cup and press the physical button to save the empty-coaster zero. Subsequent starts reuse it. Pressing the button with the coaster empty can refresh it. This zeros the scale; the cup weight remains fixed.
6. Verify the supported empty cup reads about 258 g. Scale factor **382.09** needs physical verification. Before an initial offset exists, first-time zeroing requires the user's empty-coaster confirmation.

Fixed values: **258 g empty**, **655 g safe filled total**, **350 g refill threshold**, **5 g minimum sip**, **15-second pump timeout**. The initial pump cutoff is **10 g below the safe limit** to allow residual flow. Measure overshoot and tune this internal allowance on the hardware before acceptance.

## Connect a phone

1. Run/install the app on Android or iOS.
2. Join **LiquidCoaster** in phone Wi-Fi settings; password **Water258Cup**.
3. Keep the network even if the OS reports no internet. Grant local-network access if requested, then return to the app.
4. The app connects to `ws://192.168.4.1:81` automatically. Use **Reconnect** if needed.
5. Place the cup and let it settle. Lift, drink, and return it; the ESP32 measures the sip and handles refilling independently.

Use one phone as the history owner. The firmware permits one active protocol client. The app cannot force pumping or clear spill faults remotely; address the fault and use the physical button.

## Saved data and limits

Daily goals and their historical values now commit together in SQLite. Existing
installations migrate automatically; the previous preference is imported once.
Historical days without a stored goal use the last known goal active before that
calendar date (or the earliest known goal if the record predates installation).
Timezone regrouping always preserves all intake in history totals.

Boss progress carries across days using total saved intake. There are ten bosses,
with HP increasing from 2,000 to 6,500 in 500 ml steps (42,500 ml across the full
journey). Each boss awards a distinct badge shown in Settings, plus 250 XP for
Act I, 300 XP for Act II, and 50 XP more for each later act. The tenth encounter
stays completed; there is no eleventh boss. Replays and restarts cannot award
twice; editing/deleting intake also adjusts derived badges and rewards.
Levels cap at 50 (122,500 lifetime XP); intake continues to be recorded afterward.

The coaster connection controls appear only in Settings. Gauge markings follow
the selected goal, with a smooth rising fill and pour on recorded sips, including
the first sip from empty. Reduced-motion settings display the saved fill directly.
Sips are measured when the cup is returned to the coaster, so the animation begins
when that measurement reaches the phone.

History uses the shared blue theme and glass cards with the trailing seven-day total and
average, real streak tiers, tappable water tubes, and the existing archive.
Tube heights show progress against each day's saved goal; the day detail preserves
uncapped amounts and percentages. The top status shows the actual level out of 50.
New installations show seven empty tubes. Sips continue to sync automatically.

The app sends its daily total and saved-event watermark to the coaster before
acknowledging sips, and after edits, rollover, or reconnect. LEDs retain a saved
counter and include unsaved queued drinks without double-counting. On power-up,
progress LEDs wait for phone clock synchronization rather than display a potentially
wrong day's saved count. While connected, the phone refreshes its local offset at
least every 30 seconds; offline rollover uses the most recently synchronized offset.


- Acknowledgements follow successful saves. Replay cannot duplicate records or restore deliberately deleted sips. Records, edits, goals, and lifetime XP survive restarts. Today resets at local midnight; previous days remain.
- ESP32 retains **64 unacknowledged events** in flash. When full, it pauses refilling and reports `QUEUE_FULL`. Connect the phone before continuing; events beyond this bounded capacity cannot be tracked.
- Phone supplies clock sync. Untimed events within the same boot recover their time using monotonic uptime. Already timed events retain it across device restarts.
- Untimed events spanning an ESP32 power restart have no recoverable original wall-clock time without an RTC. They use the next sync time and display **time estimated**; the original calendar day cannot be guaranteed. Add an RTC if that guarantee is required.
- Records belong to this app installation; clearing app data/uninstalling removes them. Cloud backup and multi-phone synchronization are outside scope.

## Development

To preview the screens in Google Chrome without hardware:

```sh
flutter run -d chrome -t lib/ui_preview.dart
```

This separate preview starts with empty temporary history and a disconnected
coaster. It does not connect to the ESP32 or use the phone's saved records.
Use Chrome's device toolbar to view the layout at a phone-sized width.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
clang++ -std=c++11 -Wall -Wextra -pedantic firmware/tests/CupTracker_test.cpp -o /tmp/coaster-test
/tmp/coaster-test
clang++ -std=c++11 -Wall -Wextra -pedantic firmware/tests/DailyProgress_test.cpp -o /tmp/coaster-daily-test
/tmp/coaster-daily-test
TZ=America/New_York flutter test test/domain/calendar_regression_test.dart
```

Production SQLite supports Android, iOS, and macOS. Web, Linux, and Windows are not production targets for this implementation. Test fakes are explicitly injected through `test/support/test_providers.dart`.

See [Wi-Fi protocol](docs/WIFI_PROTOCOL.md), [implementation status](docs/IMPLEMENTATION_PLAN.md), and [physical acceptance](docs/HARDWARE_ACCEPTANCE.md).

Dependency references: [SQLite](https://docs.flutter.dev/cookbook/persistence/sqlite), [WebSocketChannel](https://pub.dev/packages/web_socket_channel), [ESP32 Wi-Fi](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html), and [Preferences](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/preferences.html).
