#include <Wire.h>
#include <Adafruit_MPR121.h>

// =====================================================
// MPR121
// =====================================================

Adafruit_MPR121 cap = Adafruit_MPR121();

const int NUM_BUTTONS = 10;

// Several pads can be pressed at once, but a touched pad
// much weaker than the strongest one is treated as
// crosstalk from its neighbour and ignored.
// A pad turns on above PRESS_RATIO of the strongest signal
// and stays on until it drops below RELEASE_RATIO.
const float PRESS_RATIO = 0.6;
const float RELEASE_RATIO = 0.4;

// Set true only when debugging capacitive pads
const bool DEBUG = false;

bool active[NUM_BUTTONS];


// =====================================================
// FLEX SENSOR
// =====================================================

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


// =====================================================
// SETUP
// =====================================================

void setup() {

  Serial.begin(115200);

  // -------------------------
  // MPR121 initialization
  // -------------------------

  if (!cap.begin(0x5A)) {

    // MPR121 not detected
    while (1);
  }

  cap.setAutoconfig(true);


  // -------------------------
  // FLEX calibration
  // -------------------------

  calibrateFlex();
}


// =====================================================
// FLEX CALIBRATION
// =====================================================

void calibrateFlex() {

  long sum = 0;
  int samples = 0;

  unsigned long startTime = millis();

  // User should keep the arm in a comfortable
  // neutral position during these 2 seconds
  while (millis() - startTime < CALIBRATION_TIME) {

    sum += analogRead(FLEX_PIN);
    samples++;

    delay(20);
  }

  flexBaseline = sum / (float)samples;

  // Start filter from baseline
  flexFiltered = flexBaseline;
}


// =====================================================
// CAPACITIVE SIGNAL STRENGTH
// =====================================================

int signalStrength(int i) {

  return (int)cap.baselineData(i)
       - (int)cap.filteredData(i);
}


// =====================================================
// MAIN LOOP
// =====================================================

void loop() {

  // ===================================================
  // 1. CAPACITIVE BUTTONS
  // ===================================================

  uint16_t touched = cap.touched();


  // Optional debugging
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


  // ---------------------------------------------------
  // Find strongest touched electrode
  // ---------------------------------------------------

  int strength[NUM_BUTTONS];
  int best = 0;

  for (int i = 0; i < NUM_BUTTONS; i++) {

    strength[i] = signalStrength(i);

    if ((touched & (1 << i)) && strength[i] > best) {
      best = strength[i];
    }
  }


  // ---------------------------------------------------
  // Decide each pad, filtering out crosstalk
  // ---------------------------------------------------

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


  // ===================================================
  // 2. FLEX SENSOR
  // ===================================================

  int flexRaw = analogRead(FLEX_PIN);


  // Low-pass filtering
  flexFiltered =
    flexFiltered +
    FLEX_ALPHA * (flexRaw - flexFiltered);


  // Difference from user's initial position
  int flexDifference =
    (int)(flexFiltered - flexBaseline);


  // ---------------------------------------------------
  // Dead zone
  // ---------------------------------------------------

  if (abs(flexDifference) < FLEX_DEADZONE) {

    flexDifference = 0;
  }


  // ---------------------------------------------------
  // Send flex information to Processing
  // ---------------------------------------------------

  if (millis() - lastFlexSend >= FLEX_SEND_PERIOD) {

    lastFlexSend = millis();

    Serial.print("F,");
    Serial.println(flexDifference);
  }


  delay(20);
}
