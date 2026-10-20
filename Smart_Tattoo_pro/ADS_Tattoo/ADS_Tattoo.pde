/*
 * ADS TATTOO - control the computer's mouse from the tattoo buttons
 *
 * Arduino (ADS_Tattoo_ard) sends one line per change: "button,state"
 *   state 1 = pressed, 0 = released     e.g. "0,1" then "0,0"
 *
 * Move actions keep moving the cursor while the button is held.
 * Click actions press on touch and release on let-go, so holding drags.
 *
 * buttonActions maps each button to an action, so a settings app can
 * change the bindings later without touching the serial/Robot code.
 *
 * macOS: the first run needs Accessibility permission for Processing
 * (System Settings > Privacy & Security > Accessibility), otherwise
 * Robot calls silently do nothing.
 */

import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.event.InputEvent;

final String MOVE_LEFT   = "MOVE_LEFT";
final String MOVE_RIGHT  = "MOVE_RIGHT";
final String MOVE_UP     = "MOVE_UP";
final String MOVE_DOWN   = "MOVE_DOWN";
final String LEFT_CLICK  = "LEFT_CLICK";
final String RIGHT_CLICK = "RIGHT_CLICK";

String[] buttonActions = { MOVE_LEFT, LEFT_CLICK };
boolean[] held = new boolean[buttonActions.length];

int moveSpeed = 8;   // pixels per frame while held (60 fps)

Serial port;
Robot robot;
String lastEvent = "waiting for input...";


void setup() {
  size(400, 200);
  frameRate(60);
  surface.setTitle("ADS Tattoo - Mouse Control");

  try {
    robot = new Robot();
  } catch (Exception e) {
    println("Could not create Robot: " + e);
    exit();
  }

  printArray(Serial.list());
  port = new Serial(this, findArduinoPort(), 115200);
  port.bufferUntil('\n');
  port.clear();
}


void draw() {
  for (int i = 0; i < buttonActions.length; i++) {
    if (held[i]) moveFor(buttonActions[i]);
  }

  background(255);
  fill(20);
  textSize(16);
  text("ADS TATTOO - MOUSE CONTROL", 20, 30);
  textSize(14);
  for (int i = 0; i < buttonActions.length; i++) {
    text("Button " + i + ": " + buttonActions[i] + (held[i] ? "  [held]" : ""), 20, 70 + i * 22);
  }
  text("Last: " + lastEvent, 20, 170);
}


// Picks the first USB serial device (macOS names), falling back to the first port
String findArduinoPort() {
  for (String name : Serial.list()) {
    if (name.contains("usbmodem") || name.contains("usbserial")) return name;
  }
  return Serial.list()[2];
}


void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;

  String[] parts = split(trim(line), ',');
  if (parts.length != 2) return;

  setButton(int(parts[0]), int(parts[1]) == 1);
}


void setButton(int button, boolean pressed) {
  if (button < 0 || button >= buttonActions.length) return;
  if (held[button] == pressed) return;
  held[button] = pressed;

  String action = buttonActions[button];
  if (action.equals(LEFT_CLICK))  setMouseButton(InputEvent.BUTTON1_DOWN_MASK, pressed);
  if (action.equals(RIGHT_CLICK)) setMouseButton(InputEvent.BUTTON3_DOWN_MASK, pressed);

  lastEvent = "button " + button + (pressed ? " pressed" : " released") + " -> " + action;
  println(lastEvent);
}


void moveFor(String action) {
  int dx = 0, dy = 0;
  if (action.equals(MOVE_LEFT))  dx = -moveSpeed;
  if (action.equals(MOVE_RIGHT)) dx = moveSpeed;
  if (action.equals(MOVE_UP))    dy = -moveSpeed;
  if (action.equals(MOVE_DOWN))  dy = moveSpeed;
  if (dx == 0 && dy == 0) return;

  Point pos = MouseInfo.getPointerInfo().getLocation();
  robot.mouseMove(pos.x + dx, pos.y + dy);
}


void setMouseButton(int buttonMask, boolean pressed) {
  if (pressed) robot.mousePress(buttonMask);
  else         robot.mouseRelease(buttonMask);
}


// Keyboard testing without the Arduino: hold '0' / '1' like the pads
void keyPressed()  { setButton(key - '0', true); }
void keyReleased() { setButton(key - '0', false); }
