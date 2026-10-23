/*
 * tutorial.pde — guided walkthrough (started from the Tutorial button)
 *
 *   1-4  move the pointer up / down / left / right onto a target circle
 *   5    left click and right click (the squares)
 *   6    press each of the four circles
 *
 * During the tutorial only pointer movement is real; clicks and keys are
 * simulated so it never clicks or types on your desktop.
 * This tab has no setup()/draw(); Smart_Tattoo.pde drives it.
 */

final int T_UP = 0;
final int T_DOWN = 1;
final int T_LEFT = 2;
final int T_RIGHT = 3;
final int T_CLICK = 4;
final int T_CIRCLES = 5;

int tState = T_UP;
boolean celebrating = false;
int celebrateStart = 0;
String celebrateText = "Great job!";

boolean gotLeftClick = false;
boolean gotRightClick = false;
int[] clickFlashAt = new int[2];
boolean[] gotCircle = new boolean[4];

boolean needCenter = false;


// ===============================================================
// LOGIC
// ===============================================================
void tutorialStart() {
  tState = T_UP;
  celebrating = false;
  gotLeftClick = gotRightClick = false;
  for (int i = 0; i < gotCircle.length; i++) gotCircle[i] = false;
  needCenter = true;
}


void endTutorial(String m) {
  setMode(M_HOME);
  msg = m;
}


// put the pointer in the middle of the window at the start of each move step
void tutorialCenter(Point origin) {
  if (needCenter && origin != null && robot != null && frameCount > 5) {
    robot.mouseMove(origin.x + width / 2, origin.y + height / 2);
    needCenter = false;
  }
}


void tutorialUpdate(Point origin) {
  // pointer position in window coordinates
  float px = mouseX, py = mouseY;
  if (origin != null) {
    Point sp = MouseInfo.getPointerInfo().getLocation();
    px = sp.x - origin.x;
    py = sp.y - origin.y;
  }

  if (celebrating && millis() - celebrateStart > 1500) {
    tutorialNext();
    return;
  }

  if (!celebrating && tState <= T_RIGHT) {
    float[] t = moveTarget(tState);
    if (dist(px, py, t[0], t[1]) < 36) tutorialComplete("Great job!");
  }
}


void tutorialComplete(String text) {
  celebrating = true;
  celebrateStart = millis();
  celebrateText = text;
}


void tutorialNext() {
  celebrating = false;
  tState++;
  if (tState > T_CIRCLES) endTutorial("Tutorial complete!");
  else if (tState <= T_RIGHT) needCenter = true;
}


void tutorialPress(int b) {
  if (celebrating) return;
  String a = buttonActions[b];
  if (tState == T_CLICK) {
    if (a.equals("LEFT_CLICK"))  tutorialClick(true);
    if (a.equals("RIGHT_CLICK")) tutorialClick(false);
  } else if (tState == T_CIRCLES) {
    for (int k = 0; k < circleIdx.length; k++) {
      if (circleIdx[k] == b) gotCircle[k] = true;
    }
    boolean all = true;
    for (boolean g : gotCircle) all &= g;
    if (all) tutorialComplete("Great job!");
  }
}


void tutorialClick(boolean left) {
  if (celebrating || tState != T_CLICK) return;
  clickFlashAt[left ? 0 : 1] = millis();
  if (left) gotLeftClick = true; else gotRightClick = true;
  if (gotLeftClick && gotRightClick) tutorialComplete("Great job!");
}


// real mouse clicks on the window count as simulated clicks in the tutorial
void tutorialMouse() {
  if (mouseButton == LEFT)       tutorialClick(true);
  else if (mouseButton == RIGHT) tutorialClick(false);
}


// ===============================================================
// DRAWING
// ===============================================================
void drawTutorial() {
  fill(120);
  textAlign(LEFT, BASELINE);
  textSize(14);
  text("ADS TATTOO - TUTORIAL     Step " + (tState + 1) + " of 6", 20, 28);

  fill(20);
  textAlign(CENTER, BASELINE);
  textSize(26);
  text(instruction(), width / 2, 85);

  if (celebrating) {
    fill(40, 160, 80);
    textSize(40);
    text(celebrateText, width / 2, 140);
  }

  if (tState <= T_RIGHT)      drawMoveStep();
  else if (tState == T_CLICK) drawClickStep();
  else                        drawCircleStep();
}


float[] moveTarget(int st) {
  float cx = width / 2.0, cy = height / 2.0;
  if (st == T_UP)    return new float[] { cx, cy - 200 };
  if (st == T_DOWN)  return new float[] { cx, cy + 200 };
  if (st == T_LEFT)  return new float[] { cx - 300, cy };
  return new float[] { cx + 300, cy };
}


String instruction() {
  switch (tState) {
    case T_UP:    return "Press the up arrow button to move the mouse pointer up";
    case T_DOWN:  return "Press the down arrow button to move the mouse pointer down";
    case T_LEFT:  return "Press the left arrow button to move the mouse pointer left";
    case T_RIGHT: return "Press the right arrow button to move the mouse pointer right";
    case T_CLICK: return "Press the left square and the right square to click";
    default:      return "Press each of the four circles";
  }
}


void drawMoveStep() {
  float cx = width / 2.0, cy = height / 2.0;

  // start marker
  stroke(200);
  strokeWeight(1);
  line(cx - 12, cy, cx + 12, cy);
  line(cx, cy - 12, cx, cy + 12);

  int a = (tState == T_UP || tState == T_DOWN) ? T_UP : T_LEFT;   // the pair being shown
  for (int st = a; st <= a + 1; st++) {
    float[] t = moveTarget(st);
    boolean isTarget = (st == tState);
    noStroke();
    if (isTarget && celebrating) fill(60, 175, 100);
    else if (isTarget)           fill(255, 200, 60);
    else                         fill(225);
    ellipse(t[0], t[1], 72, 72);
  }
}


void drawClickStep() {
  float cx = width / 2.0, cy = height / 2.0;
  for (int side = 0; side < 2; side++) {
    boolean got = side == 0 ? gotLeftClick : gotRightClick;
    boolean flashing = millis() - clickFlashAt[side] < 250;
    float x = cx + (side == 0 ? -150 : 150);
    color c = got ? color(60, 175, 100) : (flashing ? color(255, 200, 60) : color(225));
    drawShape(squareIdx[side], x, cy, 120, c, false);
    fill(20);
    textAlign(CENTER, BASELINE);
    textSize(18);
    text(side == 0 ? "Left click" : "Right click", x, cy + 100);
  }
}


void drawCircleStep() {
  float cx = width / 2.0, cy = height / 2.0;
  for (int k = 0; k < 4; k++) {
    int b = circleIdx[k];
    float x = cx + (k % 2 == 0 ? 90 : -90);
    float y = cy + (k < 2 ? -70 : 80);
    color c = gotCircle[k] ? color(60, 175, 100) : (held[b] ? color(255, 200, 60) : color(225));
    drawShape(b, x, y, 110, c, false);
    fill(20);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(shortAction(buttonActions[b]), x, y);
  }
}
