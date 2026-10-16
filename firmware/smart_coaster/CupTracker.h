#pragma once
#include <stdint.h>
#include <math.h>

// Pure state machine, shared by firmware and host-side tests. Pump control and
// persistence stay outside this class so a network cannot alter detection.
class CupTracker {
 public:
  enum State { NO_CUP, SETTLING, RESTING, LIFTED, FILLING };
  State state = NO_CUP;
  float stableWeight = 0;
  float referenceWeight = 0;
  bool hasReference = false;
  bool returning = false;

  // Samples arrive every 100 ms. Ten readings within a 2 g band are required.
  int sample(float weight, bool pumping) {
    if (!isfinite(weight)) { reset(); return 0; }
    if (weight < 100) {
      if (pumping) { hasReference = false; returning = false; }
      else if (state == RESTING || state == SETTLING) returning = hasReference;
      state = hasReference && returning ? LIFTED : NO_CUP;
      count = 0;
      return 0;
    }
    if (pumping) {
      state = FILLING;
      hasReference = false;
      returning = false;
      count = 0;
      return 0;
    }
    if (state == RESTING) {
      // Idle drift is not drinking. Keep the reference until a physical lift.
      if (fabsf(weight - referenceWeight) <= 2) return 0;
      // A manual refill or accumulated drift establishes a new stable baseline
      // without ever emitting a sip while the cup stays on the coaster.
      returning = false;
    }
    state = SETTLING;
    if (count == 0 || weight < low - 2 || weight > high + 2 ||
        fmaxf(high, weight) - fminf(low, weight) > 2) {
      low = high = weight; total = weight; count = 1;
      return 0;
    }
    low = fminf(low, weight); high = fmaxf(high, weight);
    total += weight;
    if (++count < 10) return 0;
    stableWeight = total / count;
    int sip = 0;
    if (returning && hasReference) {
      const float drop = referenceWeight - stableWeight;
      // Larger drops are invalid for the supported fixed cup, not extra intake.
      if (drop >= 5 && drop <= 397) sip = (int)lroundf(drop);
    }
    referenceWeight = stableWeight;
    hasReference = true;
    returning = false;
    state = RESTING;
    count = 0;
    return sip;
  }
  void reset() {
    state = NO_CUP; hasReference = false; returning = false; count = 0;
  }
  // A refill changes mass while the cup remains on the coaster. Start a fresh
  // stability window after shutdown instead of counting the pump as a sip.
  void filled() {
    state = SETTLING; hasReference = false; returning = false; count = 0;
  }
 private:
  int count = 0;
  float low = 0, high = 0, total = 0;
};
