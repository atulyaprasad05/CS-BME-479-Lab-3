/*
 * ADS TATTOO
 *
 * Live display of the tattoo buttons, laid out like the tattoo:
 *     o  o        circles: Enter, Tab, Space, Scroll toggle
 *     o  o
 *    [ ][ ]       squares: left click, right click
 *      ^
 *    <   >        arrows: move the mouse pointer
 *      v
 * Each button lights up while it is held. Right click a button on screen to
 * change what that tattoo pad does.
 *
 * The Tutorial button in the top-right corner starts a walkthrough:
 *   1-4  move the pointer up / down / left / right onto a target circle
 *   5    left click and right click (the squares)
 *   6    press each of the four circles
 * During the tutorial only pointer movement is real; clicks and keys are
 * simulated so it never clicks or types on your desktop.
 *
 * Arduino sends one line per change: "B,button,state"   e.g. "B,0,1" then "B,0,0"
 * ("button,state" also works; "F,<flex>" lines are ignored)
 * Button number = MPR121 electrode = index in buttonActions:
 *   0 up  1 left  2 right  3 down  4 left square  5 right square
 *   6 top-left circle  7 top-right circle  8 bottom-left circle  9 bottom-right circle
 *
 * Keyboard testing without the Arduino: keys 0-9 act like the buttons.
 */

import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Component;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;
import java.util.concurrent.ConcurrentLinkedQueue;

// ---------------------------------------------------------------
// BUTTON TABLE  (index = Arduino button number)
// Actions: MOVE_UP/DOWN/LEFT/RIGHT, LEFT_CLICK, RIGHT_CLICK,
//          SCROLL_TOGGLE, KEY:<java keycode>
// ---------------------------------------------------------------
String[] buttonActions = {
  "MOVE_UP", "MOVE_LEFT", "MOVE_RIGHT", "MOVE_DOWN",
  "LEFT_CLICK", "RIGHT_CLICK",
  "KEY:10", "KEY:9", "KEY:32", "SCROLL_TOGGLE"   // Enter, Tab, Space, scroll
};

String[] shapeNames = {
  "Up arrow", "Left arrow", "Right arrow", "Down arrow",
  "Left square", "Right square",
  "Top-left circle", "Top-right circle", "Bottom-left circle", "Bottom-right circle"
};

final int NUM_BUTTONS = 10;
final int FIRST_CIRCLE = 6;

boolean[] held = new boolean[NUM_BUTTONS];
String[] realDown = new String[NUM_BUTTONS];   // action actually pressed on the desktop
float[] bx = new float[NUM_BUTTONS];
float[] by = new float[NUM_BUTTONS];
final float PAD_SIZE = 56;

int moveSpeed = 8;   // pixels per frame while held (60 fps)
boolean scrollDown = true;   // flipped by SCROLL_TOGGLE; scrolling itself comes later

// ---------------------------------------------------------------
// REMAP MENU
// ---------------------------------------------------------------
String[] menuLabels = {
  "Move up", "Move down", "Move left", "Move right",
  "Left click", "Right click", "Scroll toggle",
  "Enter", "Tab", "Space", "Esc", "Press a key..."
};
String[] menuActions = {
  "MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT",
  "LEFT_CLICK", "RIGHT_CLICK", "SCROLL_TOGGLE",
  "KEY:10", "KEY:9", "KEY:32", "KEY:27", null
};
final int MENU_W = 170;
final int ITEM_H = 26;

int menuFor = -1;      // button the menu is open for
int menuX, menuY;
int capturing = -1;    // button waiting for a key press

// ---------------------------------------------------------------
// TUTORIAL STATE
// ---------------------------------------------------------------
final int S_UP = 0;
final int S_DOWN = 1;
final int S_LEFT = 2;
final int S_RIGHT = 3;
final int S_CLICK = 4;
final int S_CIRCLES = 5;

boolean tutorial = false;
int state = S_UP;
boolean celebrating = false;
int celebrateStart = 0;
String celebrateText = "Great job!";

boolean gotLeftClick = false;
boolean gotRightClick = false;
int[] clickFlashAt = new int[2];
boolean[] gotCircle = new boolean[4];

String msg = "";
String lastEvent = "waiting for input...";
boolean needCenter = false;

Serial port;
Robot robot;
ConcurrentLinkedQueue<int[]> events = new ConcurrentLinkedQueue<int[]>();


// ===============================================================
// SETUP
// ===============================================================
void setup() {
  size(1000, 640);
  frameRate(60);
  surface.setTitle("ADS Tattoo");

  float cx = width / 2.0;
  bx[0] = cx;      by[0] = 420;   // up
  bx[1] = cx - 80; by[1] = 490;   // left
  bx[2] = cx + 80; by[2] = 490;   // right
  bx[3] = cx;      by[3] = 560;   // down
  bx[4] = cx - 60; by[4] = 340;   // squares
  bx[5] = cx + 60; by[5] = 340;
  bx[6] = cx - 60; by[6] = 180;   // circles
  bx[7] = cx + 60; by[7] = 180;
  bx[8] = cx - 60; by[8] = 260;
  bx[9] = cx + 60; by[9] = 260;

  try {
    robot = new Robot();
  } catch (Exception e) {
    println("Could not create Robot: " + e);
    exit();
  }

  printArray(Serial.list());
  String[] ports = Serial.list();
  String name = ports.length > 2 ? ports[2] : null;   // change the index if the Arduino is on a different port
  if (name != null) {
    try {
      port = new Serial(this, name, 115200);
      port.bufferUntil('\n');
      port.clear();
      println("Connected to " + name);
    } catch (Exception e) {
      println("Could not open " + name + ": " + e);
    }
  }
  if (port == null) println("No Arduino - keyboard testing only (keys 0-9)");
}


// ===============================================================
// DRAW
// ===============================================================
void draw() {
  processQueue();

  Point origin = canvasOrigin();

  // put the pointer in the middle of the window at the start of each move step
  if (tutorial && needCenter && origin != null && robot != null && frameCount > 5) {
    robot.mouseMove(origin.x + width / 2, origin.y + height / 2);
    needCenter = false;
  }

  moveHeld(origin);
  if (tutorial) updateTutorial(origin);

  background(247);
  if (tutorial) drawTutorial();
  else          drawPad();
  drawCornerButton();
  drawFooter();
}


// ===============================================================
// TUTORIAL LOGIC
// ===============================================================
void startTutorial() {
  tutorial = true;
  state = S_UP;
  celebrating = false;
  gotLeftClick = gotRightClick = false;
  for (int i = 0; i < gotCircle.length; i++) gotCircle[i] = false;
  menuFor = -1;
  capturing = -1;
  msg = "";
  needCenter = true;
}


void endTutorial(String m) {
  tutorial = false;
  celebrating = false;
  msg = m;
}


void updateTutorial(Point origin) {
  // pointer position in window coordinates
  float px = mouseX, py = mouseY;
  if (origin != null) {
    Point sp = MouseInfo.getPointerInfo().getLocation();
    px = sp.x - origin.x;
    py = sp.y - origin.y;
  }

  if (celebrating && millis() - celebrateStart > 1500) nextStep();

  if (!celebrating && state <= S_RIGHT) {
    float[] t = moveTarget(state);
    if (dist(px, py, t[0], t[1]) < 36) complete("Great job!");
  }
}


void complete(String text) {
  celebrating = true;
  celebrateStart = millis();
  celebrateText = text;
}


void nextStep() {
  celebrating = false;
  state++;
  if (state > S_CIRCLES) endTutorial("Tutorial complete!");
  else if (state <= S_RIGHT) needCenter = true;
}


void tutorialPress(int b) {
  if (celebrating) return;
  String a = buttonActions[b];
  if (state == S_CLICK) {
    if (a.equals("LEFT_CLICK"))  tutorialClick(true);
    if (a.equals("RIGHT_CLICK")) tutorialClick(false);
  } else if (state == S_CIRCLES && b >= FIRST_CIRCLE) {
    gotCircle[b - FIRST_CIRCLE] = true;
    boolean all = true;
    for (boolean g : gotCircle) all &= g;
    if (all) complete("Great job!");
  }
}


void tutorialClick(boolean left) {
  if (celebrating || state != S_CLICK) return;
  clickFlashAt[left ? 0 : 1] = millis();
  if (left) gotLeftClick = true; else gotRightClick = true;
  if (gotLeftClick && gotRightClick) complete("Great job!");
}


// ===============================================================
// INPUT
// ===============================================================
void processQueue() {
  int[] e;
  while ((e = events.poll()) != null) onButton(e[0], e[1] == 1);
}


void onButton(int b, boolean pressed) {
  if (b < 0 || b >= NUM_BUTTONS) return;
  if (held[b] == pressed) return;
  held[b] = pressed;

  lastEvent = "button " + b + (pressed ? " pressed" : " released")
            + " -> " + shortAction(buttonActions[b]);
  println(lastEvent);

  if (!pressed)      realRelease(b);
  else if (tutorial) tutorialPress(b);
  else               realPress(b);
}


void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length == 3 && parts[0].equals("B")) {
    events.add(new int[] { parseInt(parts[1]), parseInt(parts[2]) });
  } else if (parts.length == 2 && !parts[0].equals("F")) {
    events.add(new int[] { parseInt(parts[0]), parseInt(parts[1]) });
  }
}


void mousePressed() {
  if (overCornerButton()) {
    if (tutorial) endTutorial("");
    else          startTutorial();
    return;
  }

  if (tutorial) {
    if (mouseButton == LEFT)       tutorialClick(true);
    else if (mouseButton == RIGHT) tutorialClick(false);
    return;
  }

  if (menuFor >= 0) {
    int item = menuItemAt(mouseX, mouseY);
    if (item >= 0) chooseMenuItem(item);
    menuFor = -1;
    return;
  }

  int b = buttonAt(mouseX, mouseY);
  if (b >= 0 && mouseButton == RIGHT) {
    capturing = -1;
    menuFor = b;
    menuX = min(mouseX, width - MENU_W - 4);
    menuY = min(mouseY, height - menuLabels.length * ITEM_H - 4);
  }
}


void keyPressed() {
  if (key == ESC) key = 0;            // stop Esc from closing the sketch

  if (capturing >= 0) {
    if (keyCode == 0) { msg = "That key can't be used, try another."; return; }
    buttonActions[capturing] = "KEY:" + keyCode;
    msg = shapeNames[capturing] + " now sends " + keyLabel(keyCode) + ".";
    capturing = -1;
    return;
  }

  // ignore keys the tattoo itself is typing into this window
  for (String a : realDown) {
    if (a != null && a.equals("KEY:" + keyCode)) return;
  }

  if (key >= '0' && key <= '9') events.add(new int[] { key - '0', 1 });
}


void keyReleased() {
  if (key >= '0' && key <= '9') events.add(new int[] { key - '0', 0 });
}


void chooseMenuItem(int item) {
  if (menuActions[item] == null) {
    capturing = menuFor;
    msg = "";
    return;
  }
  buttonActions[menuFor] = menuActions[item];
  msg = shapeNames[menuFor] + " now does " + shortAction(menuActions[item]) + ".";
}


// ===============================================================
// ROBOT OUTPUT
// ===============================================================
void realPress(int b) {
  if (robot == null) return;
  String a = buttonActions[b];
  if (a.equals("SCROLL_TOGGLE")) { scrollDown = !scrollDown; return; }
  try {
    if (a.equals("LEFT_CLICK"))       robot.mousePress(InputEvent.BUTTON1_DOWN_MASK);
    else if (a.equals("RIGHT_CLICK")) robot.mousePress(InputEvent.BUTTON3_DOWN_MASK);
    else if (a.startsWith("KEY:"))    robot.keyPress(parseInt(a.substring(4)));
    else return;
    realDown[b] = a;
  } catch (IllegalArgumentException e) {
    println("Can't send " + a + ": " + e);
  }
}


void realRelease(int b) {
  String a = realDown[b];
  if (a == null || robot == null) return;
  realDown[b] = null;
  if (a.equals("LEFT_CLICK"))       robot.mouseRelease(InputEvent.BUTTON1_DOWN_MASK);
  else if (a.equals("RIGHT_CLICK")) robot.mouseRelease(InputEvent.BUTTON3_DOWN_MASK);
  else                              robot.keyRelease(parseInt(a.substring(4)));
}


Point canvasOrigin() {
  try {
    Component c = (Component) surface.getNative();
    return c.getLocationOnScreen();
  } catch (Exception e) {
    return null;
  }
}


void moveHeld(Point origin) {
  if (robot == null) return;
  int dx = 0, dy = 0;
  for (int i = 0; i < NUM_BUTTONS; i++) {
    if (!held[i]) continue;
    String a = buttonActions[i];
    if (a.equals("MOVE_LEFT"))  dx -= moveSpeed;
    if (a.equals("MOVE_RIGHT")) dx += moveSpeed;
    if (a.equals("MOVE_UP"))    dy -= moveSpeed;
    if (a.equals("MOVE_DOWN"))  dy += moveSpeed;
  }
  if (dx == 0 && dy == 0) return;

  Point p = MouseInfo.getPointerInfo().getLocation();
  int nx = p.x + dx, ny = p.y + dy;
  if (tutorial) {                                  // keep pointer inside window
    if (origin == null) return;
    nx = constrain(nx, origin.x, origin.x + width - 1);
    ny = constrain(ny, origin.y, origin.y + height - 1);
  }
  robot.mouseMove(nx, ny);
}


// ===============================================================
// HIT TESTING
// ===============================================================
int buttonAt(float x, float y) {
  for (int i = 0; i < NUM_BUTTONS; i++) {
    if (dist(x, y, bx[i], by[i]) < PAD_SIZE * 0.6) return i;
  }
  return -1;
}


int menuItemAt(float x, float y) {
  if (x < menuX || x > menuX + MENU_W) return -1;
  int i = floor((y - menuY) / ITEM_H);
  return (i >= 0 && i < menuLabels.length) ? i : -1;
}


boolean overCornerButton() {
  return mouseX > width - 150 && mouseX < width - 20 && mouseY > 12 && mouseY < 44;
}


// ===============================================================
// DRAWING
// ===============================================================
void drawPad() {
  fill(120);
  textAlign(LEFT, BASELINE);
  textSize(14);
  text("ADS TATTOO", 20, 28);

  fill(20);
  textAlign(CENTER, BASELINE);
  textSize(26);
  String head = capturing >= 0
    ? "Press the key you want the " + shapeNames[capturing].toLowerCase() + " to send"
    : "Right click a button to change what it does";
  text(head, width / 2, 85);

  if (msg.length() > 0) {
    fill(210, 110, 20);
    textSize(18);
    text(msg, width / 2, 120);
  }

  int hover = menuFor < 0 ? buttonAt(mouseX, mouseY) : -1;
  for (int i = 0; i < NUM_BUTTONS; i++) {
    color c = held[i] ? color(255, 200, 60)
            : (i == capturing || i == menuFor) ? color(255, 230, 170)
            : color(232);
    drawShape(i, bx[i], by[i], PAD_SIZE, c, held[i] || i == hover || i == menuFor);
    fill(60);
    textAlign(CENTER, BASELINE);
    textSize(12);
    text(shortAction(buttonActions[i]), bx[i], by[i] + PAD_SIZE / 2 + 16);
  }

  if (menuFor >= 0) drawMenu();
}


void drawMenu() {
  stroke(140);
  strokeWeight(1);
  fill(255);
  rect(menuX, menuY, MENU_W, menuLabels.length * ITEM_H, 6);

  int over = menuItemAt(mouseX, mouseY);
  textAlign(LEFT, CENTER);
  textSize(14);
  for (int i = 0; i < menuLabels.length; i++) {
    float y = menuY + i * ITEM_H;
    boolean current = buttonActions[menuFor].equals(menuActions[i]);
    if (i == over) {
      noStroke();
      fill(255, 220, 120);
      rect(menuX + 2, y + 1, MENU_W - 4, ITEM_H - 2, 4);
    }
    fill(current ? color(40, 140, 70) : color(20));
    text((current ? "> " : "   ") + menuLabels[i], menuX + 10, y + ITEM_H / 2);
  }
}


void drawCornerButton() {
  boolean over = overCornerButton();
  stroke(140);
  strokeWeight(1);
  fill(over ? color(255, 220, 120) : color(255));
  rect(width - 150, 12, 130, 32, 6);
  fill(20);
  textAlign(CENTER, CENTER);
  textSize(15);
  text(tutorial ? "Exit tutorial" : "Tutorial", width - 85, 28);
}


void drawFooter() {
  fill(130);
  textAlign(LEFT, BASELINE);
  textSize(12);
  text("Last: " + lastEvent, 20, height - 14);
}


void drawTutorial() {
  fill(120);
  textAlign(LEFT, BASELINE);
  textSize(14);
  text("ADS TATTOO - TUTORIAL     Step " + (state + 1) + " of 6", 20, 28);

  fill(20);
  textAlign(CENTER, BASELINE);
  textSize(26);
  text(instruction(), width / 2, 85);

  if (celebrating) {
    fill(40, 160, 80);
    textSize(40);
    text(celebrateText, width / 2, 140);
  }

  if (state <= S_RIGHT)      drawMoveStep();
  else if (state == S_CLICK) drawClickStep();
  else                       drawCircleStep();
}


float[] moveTarget(int st) {
  float cx = width / 2.0, cy = height / 2.0;
  if (st == S_UP)    return new float[] { cx, cy - 200 };
  if (st == S_DOWN)  return new float[] { cx, cy + 200 };
  if (st == S_LEFT)  return new float[] { cx - 300, cy };
  return new float[] { cx + 300, cy };
}


String instruction() {
  switch (state) {
    case S_UP:    return "Press the up arrow button to move the mouse pointer up";
    case S_DOWN:  return "Press the down arrow button to move the mouse pointer down";
    case S_LEFT:  return "Press the left arrow button to move the mouse pointer left";
    case S_RIGHT: return "Press the right arrow button to move the mouse pointer right";
    case S_CLICK: return "Press the left square and the right square to click";
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

  int a = (state == S_UP || state == S_DOWN) ? S_UP : S_LEFT;   // the pair being shown
  for (int st = a; st <= a + 1; st++) {
    float[] t = moveTarget(st);
    boolean isTarget = (st == state);
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
    drawShape(4 + side, x, cy, 120, c, false);
    fill(20);
    textAlign(CENTER, BASELINE);
    textSize(18);
    text(side == 0 ? "Left click" : "Right click", x, cy + 100);
  }
}


void drawCircleStep() {
  float cx = width / 2.0, cy = height / 2.0;
  for (int k = 0; k < 4; k++) {
    int b = FIRST_CIRCLE + k;
    float x = cx + (k % 2 == 0 ? -90 : 90);
    float y = cy + (k < 2 ? -70 : 80);
    color c = gotCircle[k] ? color(60, 175, 100) : (held[b] ? color(255, 200, 60) : color(225));
    drawShape(b, x, y, 110, c, false);
    fill(20);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(shortAction(buttonActions[b]), x, y);
  }
}


void drawShape(int i, float x, float y, float s, color c, boolean on) {
  pushMatrix();
  translate(x, y);
  stroke(on ? 20 : 140);
  strokeWeight(on ? 3 : 1.5);
  fill(c);

  if (i <= 3) {                                   // arrows: up, left, right, down
    float[] ang = { 0, -HALF_PI, HALF_PI, PI };
    rotate(ang[i]);
    triangle(0, -s / 2, -s / 2, s / 2, s / 2, s / 2);
  } else if (i <= 5) {                            // squares
    rectMode(CENTER);
    rect(0, 0, s, s, 6);
    rectMode(CORNER);
  } else {                                        // circles
    ellipse(0, 0, s, s);
  }
  popMatrix();
}


// ===============================================================
// LABELS
// ===============================================================
// macOS getKeyText returns symbols (e.g. ⏎) the default font can't draw
String keyLabel(int code) {
  switch (code) {
    case KeyEvent.VK_ENTER:      return "Enter";
    case KeyEvent.VK_TAB:        return "Tab";
    case KeyEvent.VK_SPACE:      return "Space";
    case KeyEvent.VK_ESCAPE:     return "Esc";
    case KeyEvent.VK_BACK_SPACE: return "Backspace";
    case KeyEvent.VK_DELETE:     return "Delete";
    case KeyEvent.VK_SHIFT:      return "Shift";
    case KeyEvent.VK_CONTROL:    return "Ctrl";
    case KeyEvent.VK_ALT:        return "Option";
    case KeyEvent.VK_META:       return "Cmd";
    case KeyEvent.VK_CAPS_LOCK:  return "Caps Lock";
    case KeyEvent.VK_UP:         return "Up key";
    case KeyEvent.VK_DOWN:       return "Down key";
    case KeyEvent.VK_LEFT:       return "Left key";
    case KeyEvent.VK_RIGHT:      return "Right key";
  }
  String t = KeyEvent.getKeyText(code);
  for (char ch : t.toCharArray()) {
    if (ch > 127) return "Key " + code;
  }
  return t;
}


String shortAction(String a) {
  if (a.startsWith("KEY:"))        return keyLabel(parseInt(a.substring(4)));
  if (a.equals("MOVE_UP"))         return "Move up";
  if (a.equals("MOVE_DOWN"))       return "Move down";
  if (a.equals("MOVE_LEFT"))       return "Move left";
  if (a.equals("MOVE_RIGHT"))      return "Move right";
  if (a.equals("LEFT_CLICK"))      return "Left click";
  if (a.equals("RIGHT_CLICK"))     return "Right click";
  if (a.equals("SCROLL_TOGGLE"))   return "Scroll: " + (scrollDown ? "down" : "up");
  return a;
}
