#include <Wire.h>
#include <Adafruit_MPR121.h>

Adafruit_MPR121 cap = Adafruit_MPR121();

const int NUM_BUTTONS = 10;
const float PRESS_RATIO = 0.6;
const float RELEASE_RATIO = 0.4;
const bool DEBUG = false;

bool active[NUM_BUTTONS];
const int FLEX_PIN = A0;

// Initial calibration
const unsigned long CALIBRATION_TIME = 2000;

// Baseline obtained during calibration
float flexBaseline = 0;

// Filtered flex value
float flexFiltered = 0;

// Low-pass filter coefficient
// Smaller = smoother
const float FLEX_ALPHA = 0.15;

// Ignore small movements around baseline
const int FLEX_DEADZONE = 15;

// Used to avoid sending flex data too frequently
unsigned long lastFlexSend = 0;
const unsigned long FLEX_SEND_PERIOD = 50;

void setup() {

  Serial.begin(115200);
  if (!cap.begin(0x5A)) {
    while (1);
  }

  cap.setAutoconfig(true);

  calibrateFlex();
}

void calibrateFlex() {

  long sum = 0;
  int samples = 0;

  unsigned long startTime = millis();
  while (millis() - startTime < CALIBRATION_TIME) {

    sum += analogRead(FLEX_PIN);
    samples++;

    delay(20);
  }

  flexBaseline = sum / (float)samples;
  flexFiltered = flexBaseline;
}

int signalStrength(int i) {

  return (int)cap.baselineData(i)
       - (int)cap.filteredData(i);
}

void loop() {

  uint16_t touched = cap.touched();

  if (DEBUG) {

    Serial.print("DEBUG");

    for (int i = 0; i < NUM_BUTTONS; i++) {

      Serial.print(",");
      Serial.print(i);
      Serial.print(":");
      Serial.print(signalStrength(i));
    }

    Serial.println();
  }

  int strength[NUM_BUTTONS];
  int best = 0;

  for (int i = 0; i < NUM_BUTTONS; i++) {

    strength[i] = signalStrength(i);

    if ((touched & (1 << i)) && strength[i] > best) {
      best = strength[i];
    }
  }

  for (int i = 0; i < NUM_BUTTONS; i++) {

    bool isTouched = touched & (1 << i);
    float ratio = active[i] ? RELEASE_RATIO : PRESS_RATIO;

    bool nowActive = isTouched && strength[i] >= best * ratio;

    if (nowActive != active[i]) {

      Serial.print("B,");
      Serial.print(i);
      Serial.println(nowActive ? ",1" : ",0");

      active[i] = nowActive;
    }
  }

  int flexRaw = analogRead(FLEX_PIN);

  flexFiltered =
    flexFiltered +
    FLEX_ALPHA * (flexRaw - flexFiltered);

  int flexDifference =
    (int)(flexFiltered - flexBaseline);

  if (abs(flexDifference) < FLEX_DEADZONE) {

    flexDifference = 0;
  }

  if (millis() - lastFlexSend >= FLEX_SEND_PERIOD) {

    lastFlexSend = millis();

    Serial.print("F,");
    Serial.println(flexDifference);
  }


  delay(20);
}
