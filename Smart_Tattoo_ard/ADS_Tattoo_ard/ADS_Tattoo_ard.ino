#include <Wire.h>
#include <Adafruit_MPR121.h>

// =====================================================
// MPR121
// =====================================================

Adafruit_MPR121 cap = Adafruit_MPR121();

const int NUM_BUTTONS = 10;

// Difference required before switching from one
// touched pad to another nearby pad
const int SWITCH_MARGIN = 10;

// Set true only when debugging capacitive pads
const bool DEBUG = false;

int activeButton = -1;


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

  int newActive = -1;
  int best = 0;

  for (int i = 0; i < NUM_BUTTONS; i++) {

    // Skip electrode if it is not touched
    if (!(touched & (1 << i))) {
      continue;
    }

    int strength = signalStrength(i);

    if (newActive < 0 || strength > best) {

      newActive = i;
      best = strength;
    }
  }


  // ---------------------------------------------------
  // Avoid jumping between nearby electrodes
  // ---------------------------------------------------

  if (activeButton >= 0 &&
      (touched & (1 << activeButton)) &&
      best - signalStrength(activeButton) < SWITCH_MARGIN) {

    newActive = activeButton;
  }


  // ---------------------------------------------------
  // Detect button change
  // ---------------------------------------------------

  if (newActive != activeButton) {

    // Previous button released
    if (activeButton >= 0) {

      Serial.print("B,");
      Serial.print(activeButton);
      Serial.println(",0");
    }


    // New button pressed
    if (newActive >= 0) {

      Serial.print("B,");
      Serial.print(newActive);
      Serial.println(",1");
    }


    activeButton = newActive;
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
