/*
 * ADS TATTOO - TUTORIAL
 *
 * Teaches a new user the tattoo buttons, step by step:
 *   1-4  move the pointer up / down / left / right onto a target circle
 *   5    left click and right click
 *   6    left toggle / right toggle cycle through all 10 buttons
 *   7    toggle to the RIGHT SQUARE, then right click to change that button
 *   8    press a keyboard key -> that button now sends that key
 *   then free play: remap any button, press S to save bindings.txt
 *
 * Put this file in a folder named ADS_Tattoo_Tutorial (Processing needs the
 * folder and the .pde to share a name), then run it.
 *
 * Arduino sends one line per change: "button,state"   e.g. "0,1" then "0,0"
 * Button number = index in buttonActions below (same order as the shapes):
 *   0 up  1 left  2 right  3 down  4 left circle  5 right circle
 *   6 left square  7 right square  8 left rectangle  9 right rectangle
 * Reorder buttonActions if your wiring is different.
 *
 * Only pointer MOVEMENT is real here (java.awt.Robot). Clicks and keys are
 * simulated, so the tutorial never clicks or types on your desktop.
 *
 * Keyboard testing without the Arduino:
 *   0-9 act like the buttons, LEFT/RIGHT arrows = toggles, ENTER = right click.
 *   While waiting for a new key, any key (including Esc and digits) is captured.
 */

import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Component;
import java.awt.event.KeyEvent;
import java.util.concurrent.ConcurrentLinkedQueue;

// ---------------------------------------------------------------
// BUTTON TABLE  (index = Arduino button number = shape number)
// Actions: MOVE_UP/DOWN/LEFT/RIGHT, LEFT_CLICK, RIGHT_CLICK,
//          TOGGLE_LEFT, TOGGLE_RIGHT, KEY:<java keycode>
// ---------------------------------------------------------------
String[] buttonActions = {
  "MOVE_UP", "MOVE_LEFT", "MOVE_RIGHT", "MOVE_DOWN",
  "LEFT_CLICK", "RIGHT_CLICK",
  "KEY:27", "KEY:10",                    // left square = Esc, right square = Enter
  "TOGGLE_LEFT", "TOGGLE_RIGHT"
};

String[] shapeNames = {
  "Up arrow", "Left arrow", "Right arrow", "Down arrow",
  "Left circle", "Right circle",
  "Left square", "Right square",
  "Left rectangle", "Right rectangle"
};

final int NUM_BUTTONS = 10;
final int BTN_RIGHT_SQUARE = 7;

boolean[] held = new boolean[NUM_BUTTONS];
int[] flashAt = new int[NUM_BUTTONS];

int moveSpeed = 8;   // pixels per frame while held (60 fps)

// ---------------------------------------------------------------
// TUTORIAL STATE
// ---------------------------------------------------------------
final int S_UP = 0;
final int S_DOWN = 1;
final int S_LEFT = 2;
final int S_RIGHT = 3;
final int S_CLICK = 4;
final int S_TOGGLE = 5;
final int S_SELECT = 6;
final int S_WAIT_KEY = 7;
final int S_FREE = 8;

int state = S_UP;
boolean celebrating = false;
int celebrateStart = 0;
String celebrateText = "Great job!";

boolean gotLeftClick = false;
boolean gotRightClick = false;
boolean usedToggleL = false;
boolean usedToggleR = false;

int selected = 0;        // shape currently highlighted by the toggles
int remapTarget = -1;    // button being remapped
String msg = "";
String lastEvent = "waiting for input...";
boolean needCenter = true;

Serial port;
Robot robot;
ConcurrentLinkedQueue<int[]> events = new ConcurrentLinkedQueue<int[]>();


// ===============================================================
// SETUP
// ===============================================================
void setup() {
  size(1000, 640);
  frameRate(60);
  surface.setTitle("ADS Tattoo - Tutorial");

  try {
    robot = new Robot();
  } catch (Exception e) {
    println("Could not create Robot: " + e);
    exit();
  }

  printArray(Serial.list());
  String name = findArduinoPort();
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


String findArduinoPort() {
  String[] list = Serial.list();
  for (String n : list) {
    if (n.contains("usbmodem") || n.contains("usbserial") ||
        n.contains("ttyACM") || n.contains("ttyUSB")) return n;
  }
  return list.length > 0 ? list[0] : null;
}


// ===============================================================
// DRAW
// ===============================================================
void draw() {
  processQueue();

  Point origin = canvasOrigin();

  // put the pointer in the middle of the window at the start of each move step
  if (needCenter && origin != null && robot != null && frameCount > 5) {
    robot.mouseMove(origin.x + width / 2, origin.y + height / 2);
    needCenter = false;
  }

  moveHeld(origin);

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

  background(247);
  drawHeader();

  if (state <= S_RIGHT)       drawMoveStep();
  else if (state == S_CLICK)  drawClickStep();
  else                        drawToggleStep();

  drawFooter();
}


// ===============================================================
// STEP LOGIC
// ===============================================================
void complete(String text) {
  celebrating = true;
  celebrateStart = millis();
  celebrateText = text;
}


void nextStep() {
  celebrating = false;
  msg = "";
  state++;
  if (state <= S_RIGHT) needCenter = true;
}


void doToggle(int dir) {
  if (state < S_TOGGLE || state == S_WAIT_KEY || celebrating) return;
  selected = (selected + dir + NUM_BUTTONS) % NUM_BUTTONS;
  msg = "";
  if (state == S_TOGGLE) {
    if (dir < 0) usedToggleL = true; else usedToggleR = true;
    if (usedToggleL && usedToggleR) complete("Great job!");
  }
}


void doConfirm() {
  if (celebrating) return;
  if (state == S_SELECT) {
    if (selected == BTN_RIGHT_SQUARE) {
      remapTarget = selected;
      state = S_WAIT_KEY;
      msg = "";
    } else {
      msg = "Toggle to the right square first.";
    }
  } else if (state == S_FREE) {
    remapTarget = selected;
    state = S_WAIT_KEY;
    msg = "";
  }
}


void handleAction(int b, String a) {
  flashAt[b] = millis();
  if (celebrating) return;

  if (a.equals("TOGGLE_LEFT"))       doToggle(-1);
  else if (a.equals("TOGGLE_RIGHT")) doToggle(1);
  else if (a.equals("LEFT_CLICK")) {
    if (state == S_CLICK) {
      gotLeftClick = true;
      if (gotRightClick) complete("Great job!");
    }
  } else if (a.equals("RIGHT_CLICK")) {
    if (state == S_CLICK) {
      gotRightClick = true;
      if (gotLeftClick) complete("Great job!");
    } else {
      doConfirm();
    }
  }
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

  if (pressed) handleAction(b, buttonActions[b]);
}


void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length != 2) return;
  events.add(new int[] { parseInt(parts[0]), parseInt(parts[1]) });
}


void keyPressed() {
  // waiting for the new key: capture whatever is pressed
  if (state == S_WAIT_KEY) {
    if (key == ESC) key = 0;            // stop Esc from closing the sketch
    if (celebrating) return;
    if (keyCode == 0) { msg = "That key can't be used, try another."; return; }
    buttonActions[remapTarget] = "KEY:" + keyCode;
    complete(shapeNames[remapTarget] + " now sends " + keyLabel(keyCode) + ". Great job!");
    return;
  }

  if (key == CODED) {
    if (keyCode == LEFT)  doToggle(-1);
    if (keyCode == RIGHT) doToggle(1);
    return;
  }
  if (key == ENTER || key == RETURN) { doConfirm(); return; }

  if (state == S_FREE && (key == 's' || key == 'S')) { saveBindings(); return; }

  if (key >= '0' && key <= '9') events.add(new int[] { key - '0', 1 });
}


void keyReleased() {
  if (key >= '0' && key <= '9') events.add(new int[] { key - '0', 0 });
}


void saveBindings() {
  String[] lines = new String[buttonActions.length];
  for (int i = 0; i < lines.length; i++) lines[i] = i + "," + buttonActions[i];
  saveStrings("bindings.txt", lines);
  msg = "Saved bindings.txt in the sketch folder.";
}


// ===============================================================
// ROBOT MOUSE (movement only)
// ===============================================================
Point canvasOrigin() {
  try {
    Component c = (Component) surface.getNative();
    return c.getLocationOnScreen();
  } catch (Exception e) {
    return null;
  }
}


void moveHeld(Point origin) {
  if (robot == null || origin == null) return;
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
  int nx = constrain(p.x + dx, origin.x, origin.x + width - 1);   // keep pointer inside window
  int ny = constrain(p.y + dy, origin.y, origin.y + height - 1);
  robot.mouseMove(nx, ny);
}


// ===============================================================
// DRAWING
// ===============================================================
float[] moveTarget(int st) {
  float cx = width / 2.0, cy = height / 2.0;
  if (st == S_UP)    return new float[] { cx, cy - 200 };
  if (st == S_DOWN)  return new float[] { cx, cy + 200 };
  if (st == S_LEFT)  return new float[] { cx - 300, cy };
  return new float[] { cx + 300, cy };
}


String instruction() {
  switch (state) {
    case S_UP:       return "Click the up arrow button to move the mouse pointer up";
    case S_DOWN:     return "Click the down arrow button to move the mouse pointer down";
    case S_LEFT:     return "Click the left arrow button to move the mouse pointer left";
    case S_RIGHT:    return "Click the right arrow button to move the mouse pointer right";
    case S_CLICK:    return "Click the left circle and the right circle";
    case S_TOGGLE:   return "Press the left toggle and right toggle to cycle through the buttons";
    case S_SELECT:   return "Toggle to the right square, then right click to change that button";
    case S_WAIT_KEY: return "Press the key you want the " + shapeNames[remapTarget].toLowerCase() + " to send";
    default:         return "Free play: toggle to any button, right click to change it. Press S to save.";
  }
}


void drawHeader() {
  fill(120);
  textAlign(LEFT, BASELINE);
  textSize(14);
  String step = state <= S_WAIT_KEY ? "Step " + (state + 1) + " of 8" : "Free play";
  text("ADS TATTOO - TUTORIAL     " + step, 20, 28);

  fill(20);
  textAlign(CENTER, BASELINE);
  textSize(26);
  text(instruction(), width / 2, 85);

  if (celebrating) {
    fill(40, 160, 80);
    textSize(40);
    text(celebrateText, width / 2, 140);
  } else if (msg.length() > 0) {
    fill(210, 110, 20);
    textSize(18);
    text(msg, width / 2, 135);
  }
}


void drawFooter() {
  fill(130);
  textAlign(LEFT, BASELINE);
  textSize(12);
  text("Last: " + lastEvent, 20, height - 14);
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
    int b = side == 0 ? 4 : 5;                 // left / right circle
    boolean got = side == 0 ? gotLeftClick : gotRightClick;
    boolean flashing = millis() - flashAt[b] < 250;
    float x = cx + (side == 0 ? -150 : 150);
    noStroke();
    fill(got ? color(60, 175, 100) : (flashing ? color(255, 200, 60) : color(225)));
    ellipse(x, cy, 120, 120);
    fill(20);
    textAlign(CENTER, BASELINE);
    textSize(18);
    text(side == 0 ? "Left click" : "Right click", x, cy + 100);
  }
}


void drawToggleStep() {
  float cx = width / 2.0, cy = height / 2.0;

  // big view of the currently selected button
  drawShape(selected, cx, cy - 20, 140, true);
  fill(20);
  textAlign(CENTER, BASELINE);
  textSize(24);
  text(shapeNames[selected], cx, cy + 90);
  textSize(16);
  fill(90);
  text("sends: " + shortAction(buttonActions[selected]), cx, cy + 118);

  if (state == S_WAIT_KEY && !celebrating && (millis() / 500) % 2 == 0) {
    fill(210, 110, 20);
    textSize(20);
    text("waiting for a key...", cx, cy + 155);
  }

  // row of all buttons with what each one currently sends
  for (int i = 0; i < NUM_BUTTONS; i++) {
    float x = cx + (i - 4.5) * 92;
    drawShape(i, x, height - 85, 34, i == selected);
    fill(60);
    textAlign(CENTER, BASELINE);
    textSize(11);
    text(shortAction(buttonActions[i]), x, height - 45);
  }
}


void drawShape(int i, float x, float y, float s, boolean on) {
  pushMatrix();
  translate(x, y);
  stroke(on ? 20 : 140);
  strokeWeight(on ? 3 : 1.5);
  fill(on ? color(255, 200, 60) : color(232));

  if (i <= 3) {                                   // arrows: up, left, right, down
    float[] ang = { 0, -HALF_PI, HALF_PI, PI };
    rotate(ang[i]);
    triangle(0, -s / 2, -s / 2, s / 2, s / 2, s / 2);
  } else if (i <= 5) {                            // circles
    ellipse(0, 0, s, s);
  } else if (i <= 7) {                            // squares
    rectMode(CENTER);
    rect(0, 0, s, s);
    rectMode(CORNER);
  } else {                                        // rectangles
    rectMode(CENTER);
    rect(0, 0, s * 1.6, s * 0.6);
    rectMode(CORNER);
  }
  popMatrix();
}


// ===============================================================
// LABELS
// ===============================================================
String keyLabel(int code) {
  return KeyEvent.getKeyText(code);
}


String shortAction(String a) {
  if (a.startsWith("KEY:"))        return keyLabel(parseInt(a.substring(4)));
  if (a.equals("MOVE_UP"))         return "Up";
  if (a.equals("MOVE_DOWN"))       return "Down";
  if (a.equals("MOVE_LEFT"))       return "Left";
  if (a.equals("MOVE_RIGHT"))      return "Right";
  if (a.equals("LEFT_CLICK"))      return "Left click";
  if (a.equals("RIGHT_CLICK"))     return "Right click";
  if (a.equals("TOGGLE_LEFT"))     return "Toggle left";
  if (a.equals("TOGGLE_RIGHT"))    return "Toggle right";
  return a;
}
