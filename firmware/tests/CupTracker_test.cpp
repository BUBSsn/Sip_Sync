#include "../smart_coaster/CupTracker.h"
#include <assert.h>
#include <stdio.h>

static int settle(CupTracker& tracker, float grams) {
  int sip = 0;
  for (int i = 0; i < 12; i++) sip += tracker.sample(grams, false);
  return sip;
}
int main() {
  CupTracker t;
  assert(settle(t, 655) == 0);
  assert(t.state == CupTracker::RESTING);
  // Added water without lifting becomes a new baseline but is never intake.
  assert(settle(t, 620) == 0);
  assert(t.referenceWeight == 620);
  assert(settle(t, 655) == 0);
  t.sample(0, false);
  assert(settle(t, 555) == 100);
  assert(settle(t, 555) == 0); // same reading is never counted twice
  t.sample(0, false);
  assert(settle(t, 555) == 0); // lift without drinking
  t.sample(0, false);
  assert(settle(t, 650) == 0); // added water
  t.sample(0, false);
  assert(settle(t, 647) == 0); // noise below threshold
  t.sample(0, false);
  assert(settle(t, 350) == 297); // record before refilling
  t.sample(450, true); t.sample(655, true); t.filled();
  assert(settle(t, 655) == 0);
  t.sample(0, false);
  assert(settle(t, 605) == 50); // updated post-fill reference
  t.sample(655, true); t.sample(0, true); t.filled();
  assert(settle(t, 258) == 0); // removing cup during pumping
  t.sample(0, false);
  for (int i = 0; i < 20; i++) assert(t.sample(i % 2 ? 400 : 420, false) == 0);
  assert(t.state == CupTracker::SETTLING);
  assert(settle(t, 258) == 0);
  assert(t.sample(NAN, false) == 0);
  assert(!t.hasReference);
  puts("CupTracker: all physical-cycle state tests passed");
}
