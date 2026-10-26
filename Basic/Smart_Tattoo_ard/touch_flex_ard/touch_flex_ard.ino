// Arduino: reads 4 touch pads (MPR121 channels 0-3) and a flex sensor (A0)
// Sends one line over serial: "touchBits,flexPercent"   e.g. "5,63"
// touchBits: bit0 = pad 0, bit1 = pad 1, bit2 = pad 2, bit3 = pad 3

#include <Wire.h>
#include "Adafruit_MPR121.h"

Adafruit_MPR121 cap = Adafruit_MPR121();

const int FLEX_PIN = A0;

// Tune these: open Serial Monitor and watch the raw value while
// holding the flex sensor straight, then fully bent.
// (Bending lowers the voltage, so the bent value is smaller.)
const int STRAIGHT_ADC = 570;
const int BENT_ADC = 350;

void setup() {
  Serial.begin(115200);
  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 not found, check wiring?");
    while (1);
  }
  cap.setAutoconfig(true);
}

void loop() {
  int touchBits = cap.touched() & 0x0F;   // keep only pads 0-3

  int flexRaw = analogRead(FLEX_PIN);
  int flexPercent = map(flexRaw, STRAIGHT_ADC, BENT_ADC, 0, 100);
  flexPercent = constrain(flexPercent, 0, 100);

  Serial.print(touchBits);
  Serial.print(",");
  Serial.println(flexPercent);

  delay(20);
}
