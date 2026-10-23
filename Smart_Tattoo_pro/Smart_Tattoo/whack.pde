/*
 * whack.pde — Whack-a-Mole (started from the Whack button)
 *
 * 2 x 3 holes laid out like the tattoo: the two squares on top, then the four circles.
 * Hole pads use the same Arduino numbers as the tutorial screen:
 *     hole 1 = pad 4 (left square)         hole 2 = pad 6 (right square)
 *     hole 3 = pad 7 (top-left circle)     hole 4 = pad 5 (top-right circle)
 *     hole 5 = pad 9 (bottom-left circle)  hole 6 = pad 8 (bottom-right circle)
 * MUTE / confirm = pad 0 (the up arrow). Muting toggles during a round.
 *
 * Flex sensor picks speed. First visit (per device): bend to the SLOW angle and
 * press MUTE, then bend to the FAST angle and press MUTE. After that it starts
 * playing straight away (press R on the results screen to redo the angles).
 * Angles are stored separately for device 1 and device 2 (keyboard 1 / 2 picks the device).
 *
 * Needs the Sound library (Sketch > Import Library > Manage Libraries > "Sound").
 * No Arduino? Keys q w e r t y u i o p act like pads 0-9, and mouse X acts as the flex sensor.
 * No setup()/draw() here: Smart_Tattoo.pde drives it.
 */

final int ROUND_MS   = 30000;   // length of one round
final int SLOW_SHOW  = 1200;    // ms mole stays up (slow)
final int FAST_SHOW  = 600;     // ms mole stays up (fast)
final int SLOW_GAP   = 600;     // ms between moles (slow)
final int FAST_GAP   = 300;     // ms between moles (fast)

// the game is laid out for a 420 x 520 area, centred in the window
final int WK_W = 420;
final int WK_H = 520;

final int NUM_HOLES = 6;
final int HOLE_COLS = 2;
// hole index -> Arduino pad number (copied from the tutorial layout), reading
// left-to-right, top-to-bottom
final int[] HOLE_PADS = { 4, 6, 7, 5, 9, 8 };
final int MUTE_PAD = 0;

final int W_SLOW = 0, W_FAST = 1, W_PLAY = 2, W_OVER = 3;
int wState = W_SLOW;
boolean wSetupDone = false;         // flex angles calibrated for the current device

boolean[] wHit = new boolean[10];   // "was pressed this frame" events
float wFlex = 0;                    // flex reading (Arduino difference, or mouse X without Arduino)

float slowAngle, fastAngle;

int mole = -1, moleStart, nextSpawn;
int wScore, wMisses, roundStart;
boolean muted = false;

SinOsc osc;
int beepEnd = 0;

// calibration stored per device
float[] slowStore = new float[2];
float[] fastStore = new float[2];
boolean[] doneStore = new boolean[2];


// ===============================================================
// LIFECYCLE (called from Smart_Tattoo.pde)
// ===============================================================
void whackSetup() {
  osc = new SinOsc(this);
  osc.play(440, 0);
}


// copy the live calibration into the current device's slot (called before the device changes)
void whackSave() {
  slowStore[device] = slowAngle;
  fastStore[device] = fastAngle;
  doneStore[device] = wSetupDone;
}


void whackLoad() {
  slowAngle = slowStore[device];
  fastAngle = fastStore[device];
  wSetupDone = doneStore[device];
}


void whackEnter() {
  whackLoad();
  for (int i = 0; i < 10; i++) wHit[i] = false;
  if (wSetupDone) whackStartRound();
  else            wState = W_SLOW;
}


// a tattoo pad was pressed while Whack is showing
void whackPress(int b) {
  if (b >= 0 && b < 10) wHit[b] = true;
}


// runs every frame in every mode so a beep never gets stuck on when you leave mid-sound
void whackAudio() {
  if (osc != null && millis() > beepEnd) osc.amp(0);
}


boolean wPressed(int i) { return i >= 0 && wHit[i]; }


void wBeep(float f) {
  if (muted) return;
  osc.freq(f);
  osc.amp(0.3);
  beepEnd = millis() + 80;
}


void whackDraw() {
  if (port == null) wFlex = lerp(wFlex, map(mouseX, 0, width, -512, 512), 0.3);
  else              wFlex = flexValue;

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(18);

  pushMatrix();
  translate((width - WK_W) / 2, 80);    // keep clear of the mode buttons
  switch (wState) {
    case W_SLOW: whackAngle("SLOW"); break;
    case W_FAST: whackAngle("FAST"); break;
    case W_PLAY: whackPlay(); break;
    case W_OVER: whackOver(); break;
  }
  popMatrix();

  for (int i = 0; i < 10; i++) wHit[i] = false;
}


// ---------- setup screens ----------

void whackAngle(String name) {
  text("Bend sensor to the " + name + " angle\nthen press MUTE (pad "
       + MUTE_PAD + ") to confirm", WK_W / 2, 60);
  whackBar(wFlex);
  if (wPressed(MUTE_PAD)) {
    wBeep(800);
    if (wState == W_SLOW) { slowAngle = wFlex; wState = W_FAST; }
    else { fastAngle = wFlex; wSetupDone = true; whackStartRound(); }
  }
}


// ---------- game ----------

void whackStartRound() {
  wScore = 0; wMisses = 0; mole = -1;
  roundStart = millis();
  nextSpawn = millis() + 500;
  wState = W_PLAY;
}


boolean wIsFast() { return abs(wFlex - fastAngle) < abs(wFlex - slowAngle); }


void whackPlay() {
  int left = ROUND_MS - (millis() - roundStart);
  if (left <= 0) { wState = W_OVER; mole = -1; return; }

  boolean fast = wIsFast();
  int showMs = fast ? FAST_SHOW : SLOW_SHOW;
  int gapMs  = fast ? FAST_GAP  : SLOW_GAP;

  // spawn / expire mole
  if (mole == -1 && millis() > nextSpawn) {
    mole = (int) random(NUM_HOLES);
    moleStart = millis();
  } else if (mole != -1 && millis() - moleStart > showMs) {
    wMisses++;
    mole = -1;
    nextSpawn = millis() + gapMs;
  }

  // hits
  if (wPressed(MUTE_PAD)) { muted = !muted; }
  for (int h = 0; h < NUM_HOLES; h++) {
    if (wPressed(HOLE_PADS[h]) && h == mole) {
      wScore++;
      wBeep(900);
      mole = -1;
      nextSpawn = millis() + gapMs;
    }
  }

  text("Score " + wScore + "   Missed " + wMisses + "   " + ceil(left / 1000.0) + "s", WK_W / 2, 30);
  text((fast ? "FAST" : "SLOW") + (muted ? "   (muted)" : ""), WK_W / 2, 60);
  whackHoles();
}


void whackOver() {
  text("TIME UP\nScore " + wScore + "   Missed " + wMisses
       + "\n\nPress any hole pad to replay\nPress R to redo the flex angles", WK_W / 2, WK_H / 2);
  for (int h = 0; h < NUM_HOLES; h++) if (wPressed(HOLE_PADS[h])) { whackStartRound(); return; }
  if (keyPressed && (key == 'r' || key == 'R')) {
    wSetupDone = false;
    wState = W_SLOW;
  }
}


// ---------- drawing helpers ----------

// 2 columns x 3 rows: squares on top, then the four circles (matches the tattoo)
void whackHoles() {
  for (int i = 0; i < NUM_HOLES; i++) {
    float x = WK_W / 2.0 + (i % HOLE_COLS == 0 ? -60 : 60);
    float y = 150 + (i / HOLE_COLS) * 110;
    noStroke();
    fill(70, 45, 25);
    ellipse(x, y, 90, 70);
    if (i == mole) { fill(160, 110, 70); ellipse(x, y - 10, 60, 55); }
  }
}


void whackBar(float v) {
  noFill(); stroke(255);
  rect(60, 240, 300, 30);
  noStroke(); fill(80, 200, 120);
  float w = map(constrain(v, -512, 512), -512, 512, -150, 150);
  rect(210, 240, w, 30);   // grows left/right from the centre (0 = your baseline)
  fill(255);
  text((int) v, WK_W / 2, 300);
}
