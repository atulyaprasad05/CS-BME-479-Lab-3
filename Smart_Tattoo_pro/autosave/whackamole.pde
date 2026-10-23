// Bare-bones Whack-a-Mole: 3x3 holes, 1 mute button, flex sensor picks speed.
// Needs the Sound library (Sketch > Import Library > Manage Libraries > "Sound").
// Put this file in a folder named "whackamole".
//
// No Arduino? It falls back to the keyboard:
//   keys 1-9 = buttons 0-8, key 0 = button 9, mouse X = flex sensor.
//
// Expects your MPR121 sketch's protocol at 115200 baud:
//   B,<index>,<1|0>   button pressed / released
//   F,<difference>    flex difference from baseline (signed)

import processing.serial.*;
import processing.sound.*;

final int PORT_INDEX = 0;       // index into the printed Serial.list()
final int ROUND_MS   = 30000;   // length of one round
final int SLOW_SHOW  = 1200;    // ms mole stays up (slow)
final int FAST_SHOW  = 600;     // ms mole stays up (fast)
final int SLOW_GAP   = 600;     // ms between moles (slow)
final int FAST_GAP   = 300;     // ms between moles (fast)

Serial port;
boolean useSerial = false;

boolean[] btn  = new boolean[10];   // current state from hardware / keyboard
boolean[] prev = new boolean[10];
boolean[] kb   = new boolean[10];
boolean[] hit  = new boolean[10];   // "was pressed this frame" events
float flex = 0;                     // smoothed flex reading 0..1023

int[] holeBtn = new int[9];         // hole index -> button index
int muteBtn = -1;
float slowAngle, fastAngle;

final int S_MAP = 0, S_SLOW = 1, S_FAST = 2, S_PLAY = 3, S_OVER = 4;
int state = S_MAP;
int mapStep = 0;                    // 0-8 = holes, 9 = mute

int mole = -1, moleStart, nextSpawn;
int score, misses, roundStart;
boolean muted = false;

SinOsc osc;
int beepEnd = 0;

void setup() {
  size(420, 520);
  textAlign(CENTER, CENTER);
  textSize(18);
  printArray(Serial.list());
  try {
    port = new Serial(this, Serial.list()[PORT_INDEX], 115200);
    port.bufferUntil('\n');
    useSerial = true;
  } catch (Exception e) {
    println("No serial port, using keyboard + mouse.");
  }
  osc = new SinOsc(this);
  osc.play(440, 0);
  for (int i = 0; i < 9; i++) holeBtn[i] = -1;
}

void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;
  String[] t = split(trim(s), ',');
  if (t[0].equals("B") && t.length == 3) {          // B,index,1|0
    int i = int(t[1]);
    if (i < 0 || i > 9) return;
    boolean down = t[2].equals("1");
    btn[i] = down;
    if (down) hit[i] = true;
  } else if (t[0].equals("F") && t.length == 2) {   // F,difference
    flex = int(t[1]);                               // already filtered on the Arduino
  }
}

void keyPressed()  { setKey(true); }
void keyReleased() { setKey(false); }
void setKey(boolean v) {
  int idx = -1;
  if (key >= '1' && key <= '9') idx = key - '1';
  if (key == '0') idx = 9;
  if (idx < 0) return;
  if (v && !kb[idx]) hit[idx] = true;
  kb[idx] = v;
}

boolean pressed(int i) { return i >= 0 && hit[i]; }

void beep(float f) {
  if (muted) return;
  osc.freq(f);
  osc.amp(0.3);
  beepEnd = millis() + 80;
}

void draw() {
  if (!useSerial) {
    flex = lerp(flex, map(mouseX, 0, width, -512, 512), 0.3);
  }
  if (millis() > beepEnd) osc.amp(0);

  background(30);
  fill(255);

  switch (state) {
    case S_MAP:  drawMap();  break;
    case S_SLOW: drawAngle("SLOW", slowAngle); break;
    case S_FAST: drawAngle("FAST", fastAngle); break;
    case S_PLAY: drawPlay(); break;
    case S_OVER: drawOver(); break;
  }

  for (int i = 0; i < 10; i++) hit[i] = false;
}

// ---------- setup screens ----------

void drawMap() {
  String what = (mapStep < 9) ? "HOLE " + (mapStep + 1) : "MUTE";
  text("SETUP: press the button for\n" + what, width / 2, 60);
  drawHoles(mapStep < 9 ? mapStep : -1);

  for (int i = 0; i < 10; i++) {
    if (pressed(i)) {
      boolean used = (i == muteBtn);
      for (int h = 0; h < mapStep && h < 9; h++) if (holeBtn[h] == i) used = true;
      if (used) continue;
      if (mapStep < 9) holeBtn[mapStep] = i; else muteBtn = i;
      mapStep++;
      beep(600);
      if (mapStep > 9) state = S_SLOW;
      break;
    }
  }
}

void drawAngle(String name, float saved) {
  text("Bend sensor to the " + name + " angle\nthen press MUTE button to confirm", width / 2, 60);
  drawBar(flex, -1, -1);
  if (pressed(muteBtn)) {
    beep(800);
    if (state == S_SLOW) { slowAngle = flex; state = S_FAST; }
    else { fastAngle = flex; startRound(); }
  }
}

// ---------- game ----------

void startRound() {
  score = 0; misses = 0; mole = -1;
  roundStart = millis();
  nextSpawn = millis() + 500;
  state = S_PLAY;
}

boolean isFast() { return abs(flex - fastAngle) < abs(flex - slowAngle); }

void drawPlay() {
  int left = ROUND_MS - (millis() - roundStart);
  if (left <= 0) { state = S_OVER; mole = -1; return; }

  boolean fast = isFast();
  int showMs = fast ? FAST_SHOW : SLOW_SHOW;
  int gapMs  = fast ? FAST_GAP  : SLOW_GAP;

  // spawn / expire mole
  if (mole == -1 && millis() > nextSpawn) {
    mole = int(random(9));
    moleStart = millis();
  } else if (mole != -1 && millis() - moleStart > showMs) {
    misses++;
    mole = -1;
    nextSpawn = millis() + gapMs;
  }

  // hits
  if (pressed(muteBtn)) { muted = !muted; }
  for (int h = 0; h < 9; h++) {
    if (pressed(holeBtn[h]) && h == mole) {
      score++;
      beep(900);
      mole = -1;
      nextSpawn = millis() + gapMs;
    }
  }

  text("Score " + score + "   Missed " + misses + "   " + ceil(left / 1000.0) + "s", width / 2, 30);
  text((fast ? "FAST" : "SLOW") + (muted ? "   (muted)" : ""), width / 2, 60);
  drawHoles(-1);
}

void drawOver() {
  text("TIME UP\nScore " + score + "   Missed " + misses
       + "\n\nPress any hole button to replay\nPress R to redo setup", width / 2, height / 2);
  for (int h = 0; h < 9; h++) if (pressed(holeBtn[h])) startRound();
  if (keyPressed && (key == 'r' || key == 'R')) {
    mapStep = 0; muteBtn = -1;
    for (int i = 0; i < 9; i++) holeBtn[i] = -1;
    state = S_MAP;
  }
}

// ---------- drawing helpers ----------

void drawHoles(int highlight) {
  for (int i = 0; i < 9; i++) {
    float x = 90 + (i % 3) * 120;
    float y = 160 + (i / 3) * 120;
    noStroke();
    fill(i == highlight ? color(200, 160, 40) : color(70, 45, 25));
    ellipse(x, y, 90, 70);
    if (i == mole) { fill(160, 110, 70); ellipse(x, y - 10, 60, 55); }
    fill(255);
    if (state == S_MAP && holeBtn[i] >= 0) text("b" + holeBtn[i], x, y + 50);
  }
  if (state == S_MAP && muteBtn >= 0) text("mute: b" + muteBtn, width / 2, 500);
}

void drawBar(float v, float a, float b) {
  noFill(); stroke(255);
  rect(60, 240, 300, 30);
  noStroke(); fill(80, 200, 120);
  float w = map(constrain(v, -512, 512), -512, 512, -150, 150);
  rect(210, 240, w, 30);   // grows left/right from the centre (0 = your baseline)
  fill(255);
  text(int(v), width / 2, 300);
}
