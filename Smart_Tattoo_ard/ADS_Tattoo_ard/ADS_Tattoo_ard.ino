// Arduino: reports press and release for MPR121 pads 0 and 1
// Sends one line per change: "button,state"
//   state 1 = pressed, 0 = released     e.g. "0,1" then "0,0"
//
// The pads are close enough that touching one also trips the other, so
// only one button is active at a time: the pad with the strongest signal
// (baseline - filtered). Set DEBUG to true to print those signals.

#include <Wire.h>
#include <Adafruit_MPR121.h>

const int NUM_BUTTONS = 2;
const bool DEBUG = false;
const int SWITCH_MARGIN = 10;

Adafruit_MPR121 cap = Adafruit_MPR121();

int activeButton = -1;

void setup() {
  Serial.begin(115200);

  if (!cap.begin(0x5A)) {
    while (1);
  }

  cap.setAutoconfig(true);
}

int signalStrength(int i) {
  return (int)cap.baselineData(i) - (int)cap.filteredData(i);
}

void loop() {
  uint16_t touched = cap.touched();

  if (DEBUG) {
    Serial.print("signal");
    for (int i = 0; i < NUM_BUTTONS; i++) {
      Serial.print("  ");
      Serial.print(i);
      Serial.print(": ");
      Serial.print(signalStrength(i));
    }
    Serial.println();
  }

  int newActive = -1;
  int best = 0;
  for (int i = 0; i < NUM_BUTTONS; i++) {
    if (!(touched & (1 << i))) continue;
    int s = signalStrength(i);
    if (newActive < 0 || s > best) {
      newActive = i;
      best = s;
    }
  }

  // Only switch away from a still-touched button if the other is clearly stronger
  if (activeButton >= 0 && (touched & (1 << activeButton)) &&
      best - signalStrength(activeButton) < SWITCH_MARGIN) {
    newActive = activeButton;
  }

  if (newActive != activeButton) {
    if (activeButton >= 0) {
      Serial.print(activeButton);
      Serial.println(",0");
    }
    if (newActive >= 0) {
      Serial.print(newActive);
      Serial.println(",1");
    }
    activeButton = newActive;
  }

  delay(20);
}
