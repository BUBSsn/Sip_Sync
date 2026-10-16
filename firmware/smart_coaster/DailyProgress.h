#pragma once
#include <stdint.h>

// Calendar identity comes from the phone's UTC clock and local offset. Queue
// sequence watermarks prevent replay and acknowledgements from adding twice.
struct DailyProgress {
  int64_t day = -1;
  uint64_t lastSequence = 0;
  uint32_t totalMl = 0;
  int32_t offsetMinutes = 0;

  int64_t dayOf(uint64_t unixMs) const {
    return ((int64_t)unixMs + (int64_t)offsetMinutes * 60000) / 86400000;
  }
  bool rollTo(uint64_t nowUnixMs) {
    if (!nowUnixMs || day == dayOf(nowUnixMs)) return false;
    day = dayOf(nowUnixMs);
    totalMl = 0;
    return true;
  }
  bool record(uint64_t sequence, uint32_t ml, uint64_t eventUnixMs, uint64_t nowUnixMs) {
    bool changed = rollTo(nowUnixMs);
    if (sequence <= lastSequence) return changed;
    lastSequence = sequence;
    if (eventUnixMs && nowUnixMs && dayOf(eventUnixMs) == day) totalMl += ml;
    return true;
  }
  bool synchronize(uint64_t nowUnixMs, int32_t offset, uint32_t savedMl,
      uint32_t pendingMl, uint64_t latestSequence) {
    const int64_t newDay = ((int64_t)nowUnixMs + (int64_t)offset * 60000) / 86400000;
    const bool changed = day != newDay || offsetMinutes != offset ||
      totalMl != savedMl + pendingMl || lastSequence != latestSequence;
    day = newDay; offsetMinutes = offset;
    totalMl = savedMl + pendingMl; lastSequence = latestSequence;
    return changed;
  }
};

inline int hydrationLedMode(bool clockReady, uint32_t dailyMl) {
  return !clockReady ? 0 : dailyMl < 300 ? 1 : dailyMl < 600 ? 2 : 3;
}
