/*
 * SMART TATTOO  (main tab)
 *
 * Home screen = the live tattoo pad (right click a pad to remap it).
 * Top-right row of buttons:  [Tutorial] [Snake] [Whack]
 * Click one to start it; click it again ("Exit ...") or press Esc to go home.
 *
 * Tabs:
 *   Smart_Tattoo.pde  this file: serial, input routing, desktop control, home pad
 *   tutorial.pde      guided walkthrough
 *   snake.pde         Snake game
 *   whack.pde         Whack-a-Mole game (needs the Sound library)
 *
 * Arduino sends one line per change: "B,button,state"   e.g. "B,0,1" then "B,0,0"
 * ("button,state" also works; "F,<flex>" is the flex sensor reading)
 * Button number = MPR121 electrode = index in buttonActions:
 *   0 up  1 down  2 left  3 right  4 left square  5 right square
 *   6-9 circles (see button table below)
 *
 * Keyboard: press 1 or 2 to choose device 1 or 2 (nothing is shown on screen).
 * Keys q w e r t y u i o p act like pads 0-9 (for testing without the Arduino).
 * Only the home screen and tutorial move the real mouse; games never touch your desktop.
 */

import processing.serial.*;
import processing.sound.*;          // used by whack.pde
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Component;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;
import java.util.concurrent.ConcurrentLinkedQueue;

// ---------------------------------------------------------------
// MODES
// ---------------------------------------------------------------
final int M_HOME     = 0;
final int M_TUTORIAL = 1;
final int M_SNAKE    = 2;
final int M_WHACK    = 3;
int mode = M_HOME;

// the row of buttons beside each other in the top-right corner
final int[] modeBtnMode = { M_TUTORIAL, M_SNAKE, M_WHACK };
final String[] modeBtnLabel = { "Tutorial", "Snake", "Whack" };
final int MODE_BTN_W = 110;
final int MODE_BTN_H = 32;
final int MODE_BTN_GAP = 10;
final int MODE_BTN_Y = 12;

final int PORT_INDEX = 2;   // index into the printed Serial.list(); change if the Arduino is elsewhere

// ---------------------------------------------------------------
// BUTTON TABLE  (index = Arduino button number)
// Actions: MOVE_UP/DOWN/LEFT/RIGHT, LEFT_CLICK, RIGHT_CLICK,
//          SCROLL_TOGGLE, KEY:<java keycode>
// ---------------------------------------------------------------
final String[] DEFAULT_ACTIONS = {
  "MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT",
  "LEFT_CLICK", "KEY:10",
  "RIGHT_CLICK", "KEY:9", "SCROLL_TOGGLE", "KEY:32"   // Enter, Tab, Space, scroll
};

// ---------------------------------------------------------------
// DEVICES: each device has its own config on each screen
//   pad + tutorial : padActions[device]   (this table, remap with right click)
//   snake          : snakeBtn[device]     (snake.pde, "Remap pads" button)
//   whack          : saved hole/mute/flex setup per device (whack.pde)
// Keyboard keys 1 / 2 switch between device 1 and 2.
// ---------------------------------------------------------------
int device = 0;                               // 0 = Device 1, 1 = Device 2
String[][] padActions = new String[2][];
String[] buttonActions;                       // always points at padActions[device]

String[] shapeNames = {
  "Up arrow", "Down arrow", "Left arrow", "Right arrow",
  "Left square", "Top-left circle",
  "Right square", "Top-right circle", "Bottom-left circle", "Bottom-right circle"
};

// shape per button index: 0 = arrow, 1 = square, 2 = circle
final int[] shapeType = { 0, 0, 0, 0, 1, 2, 1, 2, 2, 2 };

// the four circle buttons, in on-screen order (TL, TR, BL, BR)
final int[] circleIdx = { 5, 7, 8, 9 };
final int[] squareIdx = { 4, 6 };   // left click, right click

final int NUM_BUTTONS = 10;

boolean[] held = new boolean[NUM_BUTTONS];
String[] realDown = new String[NUM_BUTTONS];   // action actually pressed on the desktop
float[] bx = new float[NUM_BUTTONS];
float[] by = new float[NUM_BUTTONS];
final float PAD_SIZE = 56;

int moveSpeed = 8;                   // pixels per frame while held (60 fps)
boolean scrollDown = true;           // flipped by SCROLL_TOGGLE
volatile int flexValue = 0;          // latest "F,value" from the Arduino
final int FLEX_THRESHOLD = 20;       // at or below this = no scroll
final int FLEX_MAX = 100;            // flex reading that gives the fastest scroll
final float MAX_NOTCHES = 0.5;       // wheel notches per frame at FLEX_MAX (60 fps)
float scrollAccum = 0;

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

String msg = "";
String lastEvent = "waiting for input...";

Serial port;
Robot robot;
ConcurrentLinkedQueue<int[]> events = new ConcurrentLinkedQueue<int[]>();


// ===============================================================
// SETUP
// ===============================================================
void setup() {
  size(1000, 640);
  frameRate(60);
  surface.setTitle("Smart Tattoo");

  float cx = width / 2.0;
  bx[0] = cx;      by[0] = 180;   // up arrow
  bx[2] = cx - 80; by[2] = 250;   // left arrow
  bx[3] = cx + 80; by[3] = 250;   // right arrow
  bx[1] = cx;      by[1] = 320;   // down arrow
  bx[4] = cx - 60; by[4] = 400;   // left square
  bx[6] = cx + 60; by[6] = 400;   // right square
  bx[7] = cx - 60; by[7] = 480;   // top-left circle
  bx[5] = cx + 60; by[5] = 480;   // top-right circle
  bx[9] = cx - 60; by[9] = 560;   // bottom-left circle
  bx[8] = cx + 60; by[8] = 560;   // bottom-right circle

  try {
    robot = new Robot();
  } catch (Exception e) {
    println("Could not create Robot: " + e);
    exit();
  }

  printArray(Serial.list());
  String[] ports = Serial.list();
  String name = ports.length > PORT_INDEX ? ports[PORT_INDEX] : null;
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
  if (port == null) println("No Arduino - keyboard testing only (keys q w e r t y u i o p = pads 0-9)");

  for (int d = 0; d < 2; d++) padActions[d] = subset(DEFAULT_ACTIONS, 0);
  buttonActions = padActions[device];

  whackSetup();
}


// ===============================================================
// DRAW
// ===============================================================
void draw() {
  processQueue();

  Point origin = canvasOrigin();

  if (mode == M_TUTORIAL) tutorialCenter(origin);
  moveHeld(origin);
  scrollWithFlex();
  if (mode == M_TUTORIAL) tutorialUpdate(origin);
  whackAudio();

  // note: mode may have changed inside tutorialUpdate, so switch afterwards
  switch (mode) {
    case M_TUTORIAL: background(247); drawTutorial(); break;
    case M_SNAKE:    background(247); snakeDraw();    break;
    case M_WHACK:    background(30);  whackDraw();    break;
    default:         background(247); drawPad();      break;
  }
  drawModeButtons();
  drawFooter();
}


// ===============================================================
// MODE SWITCHING
// ===============================================================
void setMode(int m) {
  releaseAll();
  menuFor = -1;
  capturing = -1;
  msg = "";
  mode = m;
  if (m == M_TUTORIAL)   tutorialStart();
  else if (m == M_SNAKE) snakeEnter();
  else if (m == M_WHACK) whackEnter();
}


// switch between device 1 and 2; every screen then uses that device's own config
void selectDevice(int d) {
  if (d == device) return;
  whackSave();                       // keep the current device's whack setup
  device = d;
  buttonActions = padActions[device];
  setMode(mode);                     // re-enter the current screen with the new config
}


// let go of anything held on the desktop before the mode changes
void releaseAll() {
  for (int b = 0; b < NUM_BUTTONS; b++) {
    if (realDown[b] != null) realRelease(b);
    held[b] = false;
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

  if (!pressed) {
    realRelease(b);          // no-op unless something was really pressed
    return;
  }
  switch (mode) {
    case M_TUTORIAL: tutorialPress(b); break;
    case M_SNAKE:    snakePress(b);    break;
    case M_WHACK:    whackPress(b);    break;
    default:         realPress(b);     break;
  }
}


void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length == 2 && parts[0].equals("F")) {
    flexValue = parseInt(parts[1]);
  } else if (parts.length == 3 && parts[0].equals("B")) {
    events.add(new int[] { parseInt(parts[1]), parseInt(parts[2]) });
  } else if (parts.length == 2) {
    events.add(new int[] { parseInt(parts[0]), parseInt(parts[1]) });
  }
}


void mousePressed() {
  if (mode == M_SNAKE && snakeRemapHit(mouseX, mouseY)) {
    snakeToggleRemap();
    return;
  }

  int m = modeButtonAt(mouseX, mouseY);
  if (m >= 0) {
    setMode(mode == m ? M_HOME : m);    // clicking the active one exits it
    return;
  }

  if (mode == M_TUTORIAL) {
    tutorialMouse();
    return;
  }
  if (mode != M_HOME) return;

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

  // Esc leaves tutorial / games
  if (keyCode == 27 && mode != M_HOME) {
    setMode(M_HOME);
    return;
  }

  // ignore keys the tattoo itself is typing into this window
  for (String a : realDown) {
    if (a != null && a.equals("KEY:" + keyCode)) return;
  }

  // 1 / 2 pick the device
  if (key == '1') { selectDevice(0); return; }
  if (key == '2') { selectDevice(1); return; }

  // q w e r t y u i o p = pads 0-9
  int pad = keyPad(key);
  if (pad >= 0) events.add(new int[] { pad, 1 });

  // arrow keys also steer Snake (letters are pads now, so they aren't passed through)
  if (mode == M_SNAKE && snake != null && key == CODED) snake.handleKey(key, keyCode);
}


void keyReleased() {
  int pad = keyPad(key);
  if (pad >= 0) events.add(new int[] { pad, 0 });
}


// keyboard stand-in for the tattoo pads: q=0 w=1 e=2 r=3 t=4 y=5 u=6 i=7 o=8 p=9
int keyPad(char k) {
  if (k == CODED) return -1;
  return "qwertyuiop".indexOf(Character.toLowerCase(k));
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
// ROBOT OUTPUT  (home screen and tutorial only)
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
  if (robot == null || (mode != M_HOME && mode != M_TUTORIAL)) return;
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
  if (mode == M_TUTORIAL) {                        // keep pointer inside window
    if (origin == null) return;
    nx = constrain(nx, origin.x, origin.x + width - 1);
    ny = constrain(ny, origin.y, origin.y + height - 1);
  }
  robot.mouseMove(nx, ny);
}


void scrollWithFlex() {
  // only on the home screen, so tutorial and games never scroll your desktop
  if (robot == null || mode != M_HOME || flexValue <= FLEX_THRESHOLD) {
    scrollAccum = 0;
    return;
  }
  float speed = map(constrain(flexValue, FLEX_THRESHOLD, FLEX_MAX),
                    FLEX_THRESHOLD, FLEX_MAX, 0.1, MAX_NOTCHES);
  scrollAccum += speed;
  int n = (int) scrollAccum;
  if (n > 0) {
    robot.mouseWheel(scrollDown ? n : -n);   // positive = scroll down
    scrollAccum -= n;
  }
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


// x of the i-th mode button (0 = Tutorial, 1 = Snake, 2 = Whack), laid out right to left
float modeBtnX(int i) {
  int n = modeBtnMode.length;
  return width - 20 - (n - i) * MODE_BTN_W - (n - 1 - i) * MODE_BTN_GAP;
}


// returns the mode (M_...) of the button under (x, y), or -1
int modeButtonAt(float x, float y) {
  if (y < MODE_BTN_Y || y > MODE_BTN_Y + MODE_BTN_H) return -1;
  for (int i = 0; i < modeBtnMode.length; i++) {
    float bxx = modeBtnX(i);
    if (x > bxx && x < bxx + MODE_BTN_W) return modeBtnMode[i];
  }
  return -1;
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


// Tutorial | Snake | Whack, side by side in the top-right corner
void drawModeButtons() {
  int over = modeButtonAt(mouseX, mouseY);
  for (int i = 0; i < modeBtnMode.length; i++) {
    int m = modeBtnMode[i];
    boolean active = (mode == m);
    float x = modeBtnX(i);

    stroke(140);
    strokeWeight(1);
    fill(m == over ? color(255, 220, 120) : active ? color(255, 235, 190) : color(255));
    rect(x, MODE_BTN_Y, MODE_BTN_W, MODE_BTN_H, 6);

    fill(20);
    textAlign(CENTER, CENTER);
    textSize(15);
    text(active ? "Exit " + modeBtnLabel[i].toLowerCase() : modeBtnLabel[i],
         x + MODE_BTN_W / 2, MODE_BTN_Y + MODE_BTN_H / 2 - 1);
  }
}


void drawFooter() {
  fill(130);
  textAlign(LEFT, BASELINE);
  textSize(12);
  text("Last: " + lastEvent + "     Flex: " + flexValue
       + (mode != M_HOME ? "     Esc: back to menu" : ""), 20, height - 14);
}


void drawShape(int i, float x, float y, float s, color c, boolean on) {
  pushMatrix();
  translate(x, y);
  stroke(on ? 20 : 140);
  strokeWeight(on ? 3 : 1.5);
  fill(c);

  if (shapeType[i] == 0) {                        // arrows: up, down, left, right
    float[] ang = { 0, PI, -HALF_PI, HALF_PI };
    rotate(ang[i]);
    triangle(0, -s / 2, -s / 2, s / 2, s / 2, s / 2);
  } else if (shapeType[i] == 1) {                 // squares
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
