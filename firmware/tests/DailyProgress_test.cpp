#include "../smart_coaster/DailyProgress.h"
#include <assert.h>
#include <stdio.h>

int main() {
  const uint64_t noon = 1791979200000ULL;
  DailyProgress daily;
  assert(daily.synchronize(noon, 480, 720, 50, 42));
  assert(daily.totalMl == 770);
  // Pending sequences are already represented; replay cannot add again.
  assert(!daily.record(42, 50, noon, noon));
  daily.record(43, 100, noon, noon);
  assert(daily.totalMl == 870);
  // Acknowledging does not subtract intake. A canonical edit/deletion can.
  daily.synchronize(noon, 480, 850, 0, 43);
  assert(daily.totalMl == 850);
  DailyProgress restarted = daily;
  assert(restarted.totalMl == 850);
  assert(hydrationLedMode(true, restarted.totalMl) == 3);
  assert(hydrationLedMode(false, restarted.totalMl) == 0);
  assert(!restarted.record(43, 100, noon, noon));
  assert(restarted.rollTo(noon + 86400000));
  assert(restarted.totalMl == 0);
  assert(hydrationLedMode(true, restarted.totalMl) == 1);
  // A late queued event from yesterday must not count toward today.
  restarted.record(44, 120, noon, noon + 86400000);
  assert(restarted.totalMl == 0);
  restarted.record(45, 90, noon + 86400000, noon + 86400000);
  assert(restarted.totalMl == 90);
  // Local midnight, not UTC midnight.
  DailyProgress local;
  const uint64_t utcMidnight = 1791936000000ULL;
  local.synchronize(utcMidnight, 480, 500, 0, 5);
  assert(!local.rollTo(utcMidnight + 15 * 3600000ULL));
  assert(local.rollTo(utcMidnight + 16 * 3600000ULL));
  puts("DailyProgress: rollover, restart, edits and replay tests passed");
}
