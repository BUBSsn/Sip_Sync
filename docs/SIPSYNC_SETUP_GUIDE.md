# SipSync — ESP32 and Android setup

## 1. Install the phone app
Send SipSync.apk to your Android phone. Open it and allow installation from the
source you used to open the file. Install over the existing SipSync installation
to preserve history; do not uninstall or clear app data first.

## 2. Prepare Arduino IDE
Extract SipSync-ESP32-Firmware.zip. Open smart_coaster/smart_coaster.ino.
Keep coaster_firmware.cpp, CupTracker.h, and DailyProgress.h in that same folder.
Install ESP32 board support using Arduino IDE's Boards Manager and select your
actual classic ESP32 board and USB port. This source was previously compiled
with ESP32 Dev Module and ESP32 core 3.3.12. GPIO4 capacitive touch requires a
classic ESP32; do not assume the same firmware works on ESP32-C3/S3 boards.

Previously tested libraries:
- HX711 0.6.5
- WebSockets 2.7.2 by Links2004
- ArduinoJson 7.4.3

## 3. Check the wiring before uploading
| Component | ESP32 GPIO |
| --- | --- |
| HX711 DT | 16 |
| HX711 SCK | 17 |
| Relay control | 26 |
| Touch/spill input | 4 |
| Red LED | 25 |
| Yellow LED | 33 |
| Green LED | 32 |
| Buzzer | 14 |
| Physical button | 27 |

Confirm that your relay turns OFF when its control GPIO is switched to INPUT:
that is the behavior this firmware expects. Check the circuit's power and ground
connections against your hardware. The pin list is not a complete electrical
wiring diagram. Upload the sketch using the ESP32's USB connection.

## 4. Zero the empty coaster
Remove the cup. On first setup, press the physical button to save the empty-scale
zero. The firmware retains this offset. The supported empty cup should then read
about 258 g. The calibration factor is 382.09; verify it against known weights.
Zeroing the coaster does not change the fixed 258 g cup weight.

## 5. Connect the phone
1. Power the ESP32.
2. In the phone's Wi-Fi settings, join LiquidCoaster.
3. Password: Water258Cup.
4. Stay connected even if the phone reports “No internet.”
5. Open SipSync and grant local-network access if requested.
6. Open Sip Settings. The coaster should show Connected; tap Reconnect if needed.

The app connects automatically to ws://192.168.4.1:81. Use one phone as the
history owner. The phone does not need a USB cable for normal use.

## 6. Test the first sip and refill
Supervise initial pump tests. Use only the supported cup with water.
Place the cup and allow it to settle, then lift it, drink, and put it back.
After settling, the weight difference is recorded as a sip: about 1 g = 1 ml.
The minimum recorded sip is 5 g. Refilling must not count as drinking.

Configured limits:
- Empty cup: 258 g.
- Safe filled total: 655 g, including the cup.
- Refill starts at or below 350 g total.
- Initial pump cutoff: 645 g, leaving 10 g for residual flow.
- Pump timeout: 15 seconds.

Check actual final weight after water stops flowing. The 655 g limit still needs
physical confirmation against your cup's intended 80–85% fill. Tune the residual
flow allowance only after measuring your pump's overshoot. Clear spill or other
faults at the hardware and use the physical button; the app cannot force pumping
or clear faults remotely.

## 7. Verify saved data
Confirm a sip appears once in Home and Sip History. Restart the app and check
that it remains. Disconnect and reconnect Wi-Fi to check queued sips sync once.
The ESP32 retains up to 64 unacknowledged sips in flash. The app saves received
records in local SQLite before acknowledging them. There is no cloud backup.

## Verification status
The firmware source was previously compiled successfully for a classic ESP32.
This package contains the current source; recent UI changes did not require
firmware changes. Actual scale accuracy, relay behavior, spill cutoff, safe fill,
and phone-to-hardware operation still require the physical acceptance checks.
See HARDWARE_ACCEPTANCE.md included in this package.
