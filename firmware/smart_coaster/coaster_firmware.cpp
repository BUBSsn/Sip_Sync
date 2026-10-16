#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <HX711.h>
#include <esp_timer.h>
#include <driver/gpio.h>
#include <inttypes.h>
#include "CupTracker.h"
#include "DailyProgress.h"

// Fixed cup and wiring supplied for this project. GPIO4 touch requires a
// classic ESP32 with capacitive touch support (not an ESP32-C3).
const int HX711_DT_PIN = 16, HX711_SCK_PIN = 17, RELAY_PIN = 26;
const int TOUCH_PIN = 4, RED_LED_PIN = 25, YELLOW_LED_PIN = 33;
const int GREEN_LED_PIN = 32, BUZZER_PIN = 14, BUTTON_PIN = 27;
const float CALIBRATION_FACTOR = 382.09;
const float EMPTY_CUP_WEIGHT = 258, FULL_CUP_WEIGHT = 655;
const float REFILL_THRESHOLD = 350, CUP_PRESENT_MIN = 100;
// Start conservatively below the safe target to allow residual flow. Measure
// actual overshoot on the hardware and adjust this internal margin as needed.
const float PUMP_COAST_MARGIN_G = 10;
const uint32_t MAX_PUMP_RUN_MS = 15000, SENSOR_TIMEOUT_MS = 1000;
const uint32_t REMINDER_FIRST_MS = 90UL * 60UL * 1000UL;
const uint32_t REMINDER_REPEAT_MS = 5UL * 60UL * 1000UL;
const uint32_t REMINDER_PLAY_MS = 10000;
const char* WIFI_SSID = "LiquidCoaster";
const char* WIFI_PASSWORD = "Water258Cup";

enum Fault { NO_FAULT, FAULT_TIMEOUT, FAULT_SPILL, FAULT_SENSOR,
  FAULT_QUEUE, FAULT_STORAGE, FAULT_ZERO };
volatile Fault fault = NO_FAULT;
volatile bool pumpRunning = false;
volatile uint32_t pumpStartTime = 0, lastSensorTime = 0;
portMUX_TYPE pumpMux = portMUX_INITIALIZER_UNLOCKED;
HX711 scale;
CupTracker tracker;
Preferences preferences;
WebSocketsServer socketServer(81);
String deviceId;
uint8_t activeClient = 255;
bool storageReady = false, zeroReady = false, guardReady = false;
float weight = 0;
int touchBaseline = 0, spillStrikes = 0;
uint32_t lastSpillCheckMs = 0;
bool previousPumpRunning = false;
uint32_t lastSampleMs = 0, lastStatusMs = 0, lastReplayMs = 0;
uint32_t bootId;
int64_t clockOffsetMs = 0;
bool clockReady = false;
DailyProgress dailyProgress;
uint32_t lastProgressCheckMs = 0;

// Single atomic NVS blob holds both the sequence and unacknowledged events.
// A bounded queue avoids exhausting flash. Never discard an old record to
// make room; pause refilling and show QUEUE_FULL instead.
constexpr uint32_t QUEUE_MAGIC = 0x4C435031;
constexpr size_t QUEUE_CAPACITY = 64;
struct PendingSip {
  uint64_t sequence;
  uint64_t uptimeMs;
  uint64_t unixMs;
  uint32_t boot;
  uint16_t volumeMl;
  bool estimated;
};
struct QueueStore {
  uint32_t magic;
  uint32_t count;
  uint64_t nextSequence;
  PendingSip records[QUEUE_CAPACITY];
  uint32_t checksum;
};
QueueStore queueStore = {};
uint64_t uptimeMs() { return esp_timer_get_time() / 1000ULL; }
uint32_t checksum(const QueueStore& q) {
  const uint8_t* bytes = reinterpret_cast<const uint8_t*>(&q);
  uint32_t hash = 2166136261UL;
  for (size_t i = 0; i < offsetof(QueueStore, checksum); ++i) hash = (hash ^ bytes[i]) * 16777619UL;
  return hash;
}
bool persistQueue() {
  if (!storageReady) return false;
  queueStore.checksum = checksum(queueStore);
  return preferences.putBytes("events", &queueStore, sizeof(queueStore)) == sizeof(queueStore);
}

uint64_t currentUnixMs() { return clockReady ? uptimeMs() + clockOffsetMs : 0; }

bool persistDailyProgress() {
  if (!storageReady) return false;
  JsonDocument doc;
  doc["day"] = dailyProgress.day; doc["total_ml"] = dailyProgress.totalMl;
  doc["sequence"] = dailyProgress.lastSequence;
  doc["offset_minutes"] = dailyProgress.offsetMinutes;
  String text; serializeJson(doc, text);
  return preferences.putString("daily_v1", text) == text.length();
}

// Independently scheduled guard stops the relay even if a sensor read,
// network operation, or flash write delays the application loop.
void stopPump(Fault reason = NO_FAULT) {
  portENTER_CRITICAL(&pumpMux);
  gpio_set_direction((gpio_num_t)RELAY_PIN, GPIO_MODE_INPUT); // supplied relay's OFF behavior
  pumpRunning = false;
  if (reason != NO_FAULT) fault = reason;
  portEXIT_CRITICAL(&pumpMux);
}
void pumpGuard(void*) {
  for (;;) {
    uint32_t now = millis();
    if (pumpRunning) {
      if (now - pumpStartTime >= MAX_PUMP_RUN_MS) stopPump(FAULT_TIMEOUT);
      else if (now - lastSensorTime >= SENSOR_TIMEOUT_MS) stopPump(FAULT_SENSOR);
    }
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}
int readTouchAvg() {
  long total = 0;
  for (int i = 0; i < 5; ++i) { total += touchRead(TOUCH_PIN); delay(5); }
  return total / 5;
}
void startPump() {
  portENTER_CRITICAL(&pumpMux);
  if (fault == NO_FAULT && zeroReady && guardReady && !pumpRunning) {
    gpio_set_level((gpio_num_t)RELAY_PIN, 0);
    gpio_set_direction((gpio_num_t)RELAY_PIN, GPIO_MODE_OUTPUT);
    pumpStartTime = millis();
    pumpRunning = true;
  }
  portEXIT_CRITICAL(&pumpMux);
  spillStrikes = 0;
}
const char* faultName() {
  switch (fault) {
    case FAULT_TIMEOUT: return "PUMP_TIMEOUT";
    case FAULT_SPILL: return "SPILL";
    case FAULT_SENSOR: return "SENSOR";
    case FAULT_QUEUE: return "QUEUE_FULL";
    case FAULT_STORAGE: return "STORAGE";
    case FAULT_ZERO: return "ZERO_REQUIRED";
    default: return nullptr;
  }
}
const char* stateName() {
  if (fault != NO_FAULT) return "fault";
  if (pumpRunning) return "filling";
  switch (tracker.state) {
    case CupTracker::RESTING: return "resting";
    case CupTracker::LIFTED: return "lifted";
    case CupTracker::SETTLING: return "settling";
    default: return "no_cup";
  }
}
void envelope(JsonDocument& doc, const char* type) {
  doc["type"] = type; doc["protocol"] = 1; doc["device_id"] = deviceId;
}
void sendDocument(uint8_t client, JsonDocument& doc) {
  String text; serializeJson(doc, text); socketServer.sendTXT(client, text);
}
void broadcastStatus() {
  JsonDocument doc; envelope(doc, "status");
  doc["state"] = stateName(); doc["weight_g"] = isfinite(weight) ? fmaxf(0, fminf(2000, weight)) : 0;
  doc["cup_present"] = zeroReady && weight >= CUP_PRESENT_MIN;
  doc["pump_running"] = (bool)pumpRunning;
  if (faultName()) doc["fault"] = faultName(); else doc["fault"] = nullptr;
  String text; serializeJson(doc, text); socketServer.broadcastTXT(text);
}
String eventId(const PendingSip& sip) {
  char text[32]; snprintf(text, sizeof(text), "%" PRIu64, sip.sequence); return String(text);
}
void replayOne() {
  // Oldest first, one event per pass. Only the intended phone should save and
  // acknowledge this queue. A second phone is not a cloud synchronization peer.
  if (!clockReady || queueStore.count == 0) return;
  const PendingSip& sip = queueStore.records[0];
  if (sip.unixMs == 0) return;
  JsonDocument doc; envelope(doc, "sip");
  doc["event_id"] = eventId(sip); doc["volume_ml"] = sip.volumeMl;
  doc["unix_ms"] = sip.unixMs; doc["time_estimated"] = sip.estimated;
  if (activeClient != 255) sendDocument(activeClient, doc);
}
bool appendSip(int volume) {
  if (queueStore.count >= QUEUE_CAPACITY) { stopPump(FAULT_QUEUE); return false; }
  PendingSip sip = {};
  sip.sequence = queueStore.nextSequence++;
  sip.boot = bootId; sip.uptimeMs = uptimeMs(); sip.volumeMl = volume;
  if (clockReady) sip.unixMs = sip.uptimeMs + clockOffsetMs;
  queueStore.records[queueStore.count++] = sip;
  if (!persistQueue()) { stopPump(FAULT_STORAGE); return false; }
  dailyProgress.record(sip.sequence, volume, sip.unixMs, currentUnixMs());
  if (!persistDailyProgress()) { stopPump(FAULT_STORAGE); return false; }
  if (queueStore.count >= QUEUE_CAPACITY) stopPump(FAULT_QUEUE);
  return true;
}
void syncTime(uint64_t unixMs) {
  if (unixMs < 1577836800000ULL || unixMs > 4102444800000ULL) return;
  const uint64_t currentUptime = uptimeMs();
  clockOffsetMs = (int64_t)unixMs - (int64_t)currentUptime;
  clockReady = true;
  bool changed = false;
  for (size_t i = 0; i < queueStore.count; ++i) {
    PendingSip& sip = queueStore.records[i];
    if (sip.unixMs != 0) continue;
    if (sip.boot == bootId && sip.uptimeMs <= currentUptime) {
      sip.unixMs = unixMs - (currentUptime - sip.uptimeMs);
    } else {
      // No RTC: an unsynchronized record that crossed a power restart has no
      // recoverable original wall-clock time. The phone labels this estimate.
      sip.unixMs = unixMs; sip.estimated = true;
    }
    changed = true;
  }
  if (changed && !persistQueue()) stopPump(FAULT_STORAGE);
}
void synchronizeProgress(uint64_t unixMs, int offset, uint32_t totalMl, uint64_t throughSequence) {
  if (offset < -840 || offset > 840 || totalMl > 1000000000UL ||
      unixMs < 1577836800000ULL || unixMs > 4102444800000ULL) return;
  syncTime(unixMs);
  uint32_t pendingMl = 0;
  const int64_t day = ((int64_t)unixMs + (int64_t)offset * 60000) / 86400000;
  for (size_t i = 0; i < queueStore.count; ++i) {
    const PendingSip& sip = queueStore.records[i];
    const int64_t eventDay = ((int64_t)sip.unixMs + (int64_t)offset * 60000) / 86400000;
    if (sip.sequence > throughSequence && sip.unixMs && eventDay == day) pendingMl += sip.volumeMl;
  }
  if (dailyProgress.synchronize(unixMs, offset, totalMl, pendingMl, queueStore.nextSequence - 1) &&
      !persistDailyProgress()) stopPump(FAULT_STORAGE);
}

void acknowledge(const String& id) {
  if (queueStore.count == 0 || id != eventId(queueStore.records[0])) return;
  QueueStore before = queueStore;
  for (size_t i = 1; i < queueStore.count; ++i) queueStore.records[i - 1] = queueStore.records[i];
  --queueStore.count;
  memset(&queueStore.records[queueStore.count], 0, sizeof(PendingSip));
  if (!persistQueue()) { queueStore = before; stopPump(FAULT_STORAGE); return; }
  if (fault == FAULT_QUEUE) { fault = zeroReady ? NO_FAULT : FAULT_ZERO; tracker.reset(); }
  replayOne();
}
void onSocket(uint8_t client, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_DISCONNECTED && client == activeClient) {
    activeClient = 255; return;
  }
  if (type != WStype_TEXT || length > 512) return;
  JsonDocument incoming;
  if (deserializeJson(incoming, payload, length)) return;
  const String command = incoming["type"] | "";
  if (command == "hello" && incoming["protocol"] == 1) {
    if (activeClient != 255 && activeClient != client) return;
    activeClient = client;
    JsonDocument doc; envelope(doc, "hello");
    doc["empty_g"] = EMPTY_CUP_WEIGHT; doc["safe_g"] = FULL_CUP_WEIGHT;
    sendDocument(client, doc); broadcastStatus();
  } else if (command == "time_sync" && client == activeClient && incoming["unix_ms"].is<uint64_t>()) {
    syncTime(incoming["unix_ms"].as<uint64_t>()); replayOne();
  } else if (command == "daily_progress" && client == activeClient &&
      incoming["unix_ms"].is<uint64_t>() && incoming["total_ml"].is<uint32_t>() &&
      incoming["through_sequence"].is<uint64_t>() && incoming["utc_offset_minutes"].is<int>()) {
    synchronizeProgress(incoming["unix_ms"].as<uint64_t>(), incoming["utc_offset_minutes"].as<int>(),
      incoming["total_ml"].as<uint32_t>(), incoming["through_sequence"].as<uint64_t>());
  } else if (command == "ack" && client == activeClient && incoming["event_id"].is<const char*>()) {
    acknowledge(incoming["event_id"].as<String>());
  } else if (command == "ping") {
    JsonDocument doc; envelope(doc, "pong"); sendDocument(client, doc);
  }
}

// Original LED and buzzer animations are kept below; test-mode serial overrides
// are intentionally omitted from this production sketch.
unsigned long previousMillis = 0, buzzerPreviousMillis = 0;
bool blinkState = false;
int chaseStep = 0, noteStep = 0, lastDisplayedMode = 0;
bool reminderPlaying = false;
uint32_t reminderStartMs = 0, reminderDueMs = 0;

void setLeds(bool r, bool y, bool g) {
  digitalWrite(RED_LED_PIN, r ? HIGH : LOW);
  digitalWrite(YELLOW_LED_PIN, y ? HIGH : LOW);
  digitalWrite(GREEN_LED_PIN, g ? HIGH : LOW);
}

void resetAnimation(unsigned long now) {
  previousMillis = now;
  buzzerPreviousMillis = now;
  blinkState = false;
  chaseStep = 0;
  noteStep = 0;
  noTone(BUZZER_PIN);
}

void runMode(int m, unsigned long now) {
  switch (m) {
    case 0:
      setLeds(false, false, false); noTone(BUZZER_PIN); break;
    case 1:
      setLeds(true, false, false);
      noTone(BUZZER_PIN);
      break;

    case 2:
      setLeds(true, true, false);
      noTone(BUZZER_PIN);
      break;

    case 3:
      setLeds(true, true, true);
      noTone(BUZZER_PIN);
      break;

    case 4:
      if (now - previousMillis >= 500) {
        previousMillis = now;
        blinkState = !blinkState;
        setLeds(blinkState, blinkState, blinkState);
      }
      if (now - buzzerPreviousMillis >= 150) {
        buzzerPreviousMillis = now;
        int notes[] = {523, 659, 784, 1046};
        tone(BUZZER_PIN, notes[noteStep], 120);
        noteStep = (noteStep + 1) % 4;
      }
      break;

    case 5:
      if (now - previousMillis >= 250) {
        previousMillis = now;
        blinkState = !blinkState;
        setLeds(blinkState, false, false);
      }
      if (now - buzzerPreviousMillis >= 200) {
        buzzerPreviousMillis = now;
        if (noteStep == 0) { tone(BUZZER_PIN, 880, 180); noteStep = 1; }
        else               { tone(BUZZER_PIN, 440, 180); noteStep = 0; }
      }
      break;

    case 6:
      if (now - previousMillis >= 150) {
        previousMillis = now;
        chaseStep = (chaseStep + 1) % 6;
        setLeds(false, false, false);
        if (chaseStep == 0)      digitalWrite(RED_LED_PIN, HIGH);
        else if (chaseStep == 1) digitalWrite(YELLOW_LED_PIN, HIGH);
        else if (chaseStep == 2) digitalWrite(GREEN_LED_PIN, HIGH);
        else if (chaseStep == 3) digitalWrite(YELLOW_LED_PIN, HIGH);
        else if (chaseStep == 4) digitalWrite(RED_LED_PIN, HIGH);
      }
      if (now - buzzerPreviousMillis >= 600) {
        buzzerPreviousMillis = now;
        int reminderNotes[] = {330, 392, 659};
        tone(BUZZER_PIN, reminderNotes[noteStep], 200);
        noteStep = (noteStep + 1) % 3;
      }
      break;

    case 7:
      if (now - previousMillis >= 300) {
        previousMillis = now;
        blinkState = !blinkState;
        setLeds(false, false, blinkState);
      }
      if (now - buzzerPreviousMillis >= 400) {
        buzzerPreviousMillis = now;
        tone(BUZZER_PIN, 120, 350);
      }
      break;
  }
}


void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, INPUT);
  pinMode(RED_LED_PIN, OUTPUT); pinMode(YELLOW_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT); pinMode(BUZZER_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  bootId = esp_random();
  storageReady = preferences.begin("coaster", false);
  queueStore.magic = QUEUE_MAGIC; queueStore.nextSequence = 1;
  if (!storageReady) fault = FAULT_STORAGE;
  else if (preferences.isKey("events")) {
    if (preferences.getBytesLength("events") != sizeof(queueStore) ||
        preferences.getBytes("events", &queueStore, sizeof(queueStore)) != sizeof(queueStore) ||
        queueStore.magic != QUEUE_MAGIC || queueStore.count > QUEUE_CAPACITY ||
        queueStore.checksum != checksum(queueStore)) {
      fault = FAULT_STORAGE; storageReady = false;
      memset(&queueStore, 0, sizeof(queueStore)); // do not overwrite corrupt NVS
    }
  } else if (!persistQueue()) fault = FAULT_STORAGE;
  if (queueStore.count >= QUEUE_CAPACITY && fault == NO_FAULT) fault = FAULT_QUEUE;
  if (storageReady && preferences.isKey("daily_v1")) {
    JsonDocument saved;
    const String text = preferences.getString("daily_v1");
    if (deserializeJson(saved, text) || !saved["day"].is<int64_t>() ||
        !saved["total_ml"].is<uint32_t>() || !saved["sequence"].is<uint64_t>() ||
        !saved["offset_minutes"].is<int>() || saved["offset_minutes"].as<int>() < -840 ||
        saved["offset_minutes"].as<int>() > 840) {
      fault = FAULT_STORAGE;
    } else {
      dailyProgress.day = saved["day"].as<int64_t>();
      dailyProgress.totalMl = saved["total_ml"].as<uint32_t>();
      dailyProgress.lastSequence = saved["sequence"].as<uint64_t>();
      dailyProgress.offsetMinutes = saved["offset_minutes"].as<int>();
    }
  }
  scale.begin(HX711_DT_PIN, HX711_SCK_PIN);
  scale.set_scale(CALIBRATION_FACTOR);
  if (storageReady && preferences.isKey("scale_zero")) {
    scale.set_offset(preferences.getLong("scale_zero")); zeroReady = true;
  } else if (fault == NO_FAULT) fault = FAULT_ZERO;
  lastSensorTime = millis();
  guardReady = xTaskCreatePinnedToCore(pumpGuard, "pump_guard", 2048, nullptr, 3, nullptr, 0) == pdPASS;
  if (!guardReady) {
    stopPump(FAULT_SENSOR);
  }
  WiFi.mode(WIFI_AP);
  WiFi.softAP(WIFI_SSID, WIFI_PASSWORD);
  deviceId = WiFi.softAPmacAddress();
  socketServer.begin(); socketServer.onEvent(onSocket);
  reminderDueMs = millis() + REMINDER_FIRST_MS;
  Serial.println("Join LiquidCoaster Wi-Fi. First setup: remove cup and press the button to zero the empty coaster.");
}

bool lastButtonRaw = HIGH;
uint32_t lastButtonChange = 0;
bool zeroRequested = false;
int zeroSamples = 0;
int64_t zeroTotal = 0;
long zeroLow = 0, zeroHigh = 0;

void handleButton(uint32_t now) {
  bool raw = digitalRead(BUTTON_PIN);
  if (raw == lastButtonRaw || now - lastButtonChange < 200) return;
  lastButtonRaw = raw; lastButtonChange = now;
  if (raw != LOW || pumpRunning) return;
  if (fault == FAULT_ZERO || (zeroReady && weight < CUP_PRESENT_MIN && fault == NO_FAULT)) {
    zeroRequested = true; zeroSamples = 0; zeroTotal = 0;
    tracker.reset();
  } else if (fault == FAULT_SPILL || fault == FAULT_TIMEOUT || fault == FAULT_SENSOR) {
    if (guardReady && now - lastSensorTime < 500) {
      fault = NO_FAULT; tracker.reset(); noTone(BUZZER_PIN);
    }
  } else if (fault == FAULT_STORAGE && storageReady && persistQueue() && persistDailyProgress()) {
    fault = zeroReady ? NO_FAULT : FAULT_ZERO; tracker.reset();
  }
}
void processZero(long raw) {
  if (zeroSamples == 0) zeroLow = zeroHigh = raw;
  zeroLow = min(zeroLow, raw); zeroHigh = max(zeroHigh, raw);
  if ((zeroHigh - zeroLow) / fabsf(CALIBRATION_FACTOR) > 2) {
    zeroSamples = 0; zeroTotal = 0; return;
  }
  zeroTotal += raw;
  if (++zeroSamples < 20) return;
  long offset = zeroTotal / zeroSamples;
  if (!storageReady || preferences.putLong("scale_zero", offset) != sizeof(long)) {
    stopPump(FAULT_STORAGE);
  } else {
    scale.set_offset(offset); zeroReady = true; fault = NO_FAULT;
    weight = 0; tracker.reset();
  }
  zeroRequested = false;
}
void loop() {
  uint32_t now = millis();
  handleButton(now);
  if (clockReady && now - lastProgressCheckMs >= 1000) {
    lastProgressCheckMs = now;
    bool changed = dailyProgress.rollTo(currentUnixMs());
    // Repair a queue write that completed just before a power interruption.
    for (size_t i = 0; i < queueStore.count; ++i) {
      const PendingSip& sip = queueStore.records[i];
      changed = dailyProgress.record(sip.sequence, sip.volumeMl, sip.unixMs, currentUnixMs()) || changed;
    }
    if (changed && !persistDailyProgress()) stopPump(FAULT_STORAGE);
  }
  if (previousPumpRunning && !pumpRunning) tracker.filled();
  previousPumpRunning = pumpRunning;
  if (now - lastSensorTime > SENSOR_TIMEOUT_MS && fault == NO_FAULT) stopPump(FAULT_SENSOR);
  if (now - lastSampleMs >= 100 && scale.is_ready()) {
    lastSampleMs = now;
    long raw = scale.read(); // guard task remains independent of HX711 waits
    lastSensorTime = millis();
    if (zeroRequested) processZero(raw);
    else if (zeroReady) {
      weight = (raw - scale.get_offset()) / CALIBRATION_FACTOR;
      if (!isfinite(weight) || weight < -20 || weight > 2000) stopPump(FAULT_SENSOR);
      if (pumpRunning && weight < CUP_PRESENT_MIN) stopPump();
      if (pumpRunning && weight >= FULL_CUP_WEIGHT - PUMP_COAST_MARGIN_G) stopPump();
      // Retain the supplied touch averaging and two-hit, 500 ms spill check.
      if (pumpRunning && now - lastSpillCheckMs >= 500) {
        lastSpillCheckMs = now;
        int touch = readTouchAvg();
        spillStrikes = touchBaseline - touch >= 10 ? spillStrikes + 1 : 0;
        if (spillStrikes >= 2) stopPump(FAULT_SPILL);
      }
      if (fault == NO_FAULT) {
        int sip = tracker.sample(weight, pumpRunning);
        if (sip > 0 && appendSip(sip)) {
          reminderDueMs = now + REMINDER_FIRST_MS;
          reminderPlaying = false; replayOne();
        }
        if (tracker.state == CupTracker::RESTING && !pumpRunning &&
            tracker.stableWeight <= REFILL_THRESHOLD && fault == NO_FAULT) {
          touchBaseline = readTouchAvg(); lastSpillCheckMs = now; startPump();
          tracker.sample(weight, true); previousPumpRunning = pumpRunning;
        }
      }
    }
  }
  if (!reminderPlaying && (int32_t)(now - reminderDueMs) >= 0) {
    reminderPlaying = true; reminderStartMs = now;
    reminderDueMs = now + REMINDER_REPEAT_MS;
  }
  if (reminderPlaying && now - reminderStartMs >= REMINDER_PLAY_MS) reminderPlaying = false;
  int mode = fault == FAULT_SPILL ? 5 : fault != NO_FAULT ? 4 : pumpRunning ? 7 :
    reminderPlaying ? 6 : hydrationLedMode(clockReady, dailyProgress.totalMl);
  if (mode != lastDisplayedMode) { lastDisplayedMode = mode; resetAnimation(now); }
  runMode(mode, now);
  socketServer.loop();
  if (now - lastStatusMs >= 500) { lastStatusMs = now; broadcastStatus(); }
  if (now - lastReplayMs >= 2000) { lastReplayMs = now; replayOne(); }
  delay(1);
}
