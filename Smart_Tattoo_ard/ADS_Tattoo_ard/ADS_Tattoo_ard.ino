#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// =====================================================
// MPU6050
// =====================================================

Adafruit_MPU6050 mpu;


// =====================================================
// FSR PINS
// =====================================================

// Medial Forefoot
const int FSR_MF = A0;

// Lateral Forefoot
const int FSR_LF = A1;

// Medial Mid-foot
const int FSR_MM = A2;

// Heel
const int FSR_HEEL = A3;


// =====================================================
// LED PINS
// =====================================================

const int LED_MF   = 3;
const int LED_LF   = 5;
const int LED_MM   = 6;
const int LED_HEEL = 9;


// =====================================================
// FSR VARIABLES
// =====================================================

int fsrMF = 0;
int fsrLF = 0;
int fsrMM = 0;
int fsrHeel = 0;


// Maximum ADC value expected under pressure.
// We can calibrate this later.
const int FSR_MAX = 900;


// =====================================================
// MOTION DETECTION
// =====================================================

// Magnitude deviation from 1 g required to classify motion
const float MOTION_THRESHOLD = 1.2;

// Current motion state
bool inMotion = false;

// Time when movement started
unsigned long motionStartTime = 0;

// Total accumulated activity time
unsigned long totalActivityTime = 0;


// =====================================================
// TIMING
// =====================================================

unsigned long lastSend = 0;

// 50 ms = 20 Hz
const unsigned long SEND_PERIOD = 50;


// =====================================================
// SETUP
// =====================================================

void setup() {

  Serial.begin(115200);

  Wire.begin();


  // ---------------------------------------------------
  // LED setup
  // ---------------------------------------------------

  pinMode(LED_MF, OUTPUT);
  pinMode(LED_LF, OUTPUT);
  pinMode(LED_MM, OUTPUT);
  pinMode(LED_HEEL, OUTPUT);


  analogWrite(LED_MF, 0);
  analogWrite(LED_LF, 0);
  analogWrite(LED_MM, 0);
  analogWrite(LED_HEEL, 0);


  // ---------------------------------------------------
  // MPU6050 setup
  // ---------------------------------------------------

  if (!mpu.begin()) {

    Serial.println("ERROR: MPU6050 not found");

    while (1) {
      delay(10);
    }
  }


  // Accelerometer range
  mpu.setAccelerometerRange(MPU6050_RANGE_4_G);

  // Gyroscope range
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);

  // Digital low-pass filter
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);


  Serial.println("System ready");
}


// =====================================================
// MAIN LOOP
// =====================================================

void loop() {

  // ===================================================
  // 1. READ FSRs
  // ===================================================

  fsrMF   = analogRead(FSR_MF);
  fsrLF   = analogRead(FSR_LF);
  fsrMM   = analogRead(FSR_MM);
  fsrHeel = analogRead(FSR_HEEL);


  // ===================================================
  // 2. CONTROL LEDs
  // ===================================================

  int ledMF = map(
    constrain(fsrMF, 0, FSR_MAX),
    0,
    FSR_MAX,
    0,
    255
  );

  int ledLF = map(
    constrain(fsrLF, 0, FSR_MAX),
    0,
    FSR_MAX,
    0,
    255
  );

  int ledMM = map(
    constrain(fsrMM, 0, FSR_MAX),
    0,
    FSR_MAX,
    0,
    255
  );

  int ledHeel = map(
    constrain(fsrHeel, 0, FSR_MAX),
    0,
    FSR_MAX,
    0,
    255
  );


  analogWrite(LED_MF, ledMF);
  analogWrite(LED_LF, ledLF);
  analogWrite(LED_MM, ledMM);
  analogWrite(LED_HEEL, ledHeel);


  // ===================================================
  // 3. READ MPU6050
  // ===================================================

  sensors_event_t a;
  sensors_event_t g;
  sensors_event_t temp;

  mpu.getEvent(&a, &g, &temp);


  float ax = a.acceleration.x;
  float ay = a.acceleration.y;
  float az = a.acceleration.z;


  // ===================================================
  // 4. ACCELERATION MAGNITUDE
  // ===================================================

  float accelerationMagnitude =
    sqrt(
      ax * ax +
      ay * ay +
      az * az
    );


  // At rest, gravity gives approximately 9.81 m/s².
  // Calculate deviation from gravity.

  float motionValue =
    abs(accelerationMagnitude - 9.81);


  bool newMotionState =
    motionValue > MOTION_THRESHOLD;


  // ===================================================
  // 5. ACTIVITY TIME
  // ===================================================

  if (newMotionState && !inMotion) {

    // Movement just started
    motionStartTime = millis();
  }


  if (!newMotionState && inMotion) {

    // Movement just stopped
    totalActivityTime +=
      millis() - motionStartTime;
  }


  inMotion = newMotionState;


  // Current activity time including active interval
  unsigned long currentActivityTime =
    totalActivityTime;


  if (inMotion) {

    currentActivityTime +=
      millis() - motionStartTime;
  }


  // ===================================================
  // 6. SEND DATA TO PROCESSING
  // ===================================================

  if (millis() - lastSend >= SEND_PERIOD) {

    lastSend = millis();


    // Format:
    //
    // DATA,
    // MF,
    // LF,
    // MM,
    // HEEL,
    // ax,
    // ay,
    // az,
    // motion,
    // activitySeconds


    Serial.print("DATA,");

    Serial.print(fsrMF);
    Serial.print(",");

    Serial.print(fsrLF);
    Serial.print(",");

    Serial.print(fsrMM);
    Serial.print(",");

    Serial.print(fsrHeel);
    Serial.print(",");


    Serial.print(ax, 2);
    Serial.print(",");

    Serial.print(ay, 2);
    Serial.print(",");

    Serial.print(az, 2);
    Serial.print(",");


    Serial.print(inMotion ? 1 : 0);
    Serial.print(",");


    Serial.println(
      currentActivityTime / 1000.0,
      2
    );
  }


  delay(10);
}