#include <Wire.h>
#include <Adafruit_MPR121.h>

Adafruit_MPR121 cap = Adafruit_MPR121();

uint16_t lastTouched = 0;

void setup() {

  Serial.begin(115200);

  if (!cap.begin(0x5A)) {
    while (1);
  }

  cap.setAutoconfig(true);
}

void loop() {

  uint16_t touched = cap.touched();

  // Check only electrodes 0-3
  for (int i = 0; i < 4; i++) {

    bool isTouched = touched & (1 << i);
    bool wasTouched = lastTouched & (1 << i);

    // Send only when the pad is newly touched
    if (isTouched && !wasTouched) {
      Serial.println(i);
    }
  }

  lastTouched = touched;

  delay(20);
}
