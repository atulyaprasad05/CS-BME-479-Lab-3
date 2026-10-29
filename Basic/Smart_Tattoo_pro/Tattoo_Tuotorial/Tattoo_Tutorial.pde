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
 * Arduino sends one line per change: "button,state"   e.g. "0,1" then "0,0"
 * Button number = index in buttonActions below:
 *   0 up  1 left  2 right  3 down  4 left circle  5 right circle
 *   6 left square  7 right square  8 left rectangle  9 right rectangle
 * Reorder buttonActions if needed
 *
 * Only pointer MOVEMENT implemented via java.awt.Robot. Clicks and keys are
 * simulated.
 */

import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Component;
import java.awt.event.KeyEvent;
import java.util.concurrent.ConcurrentLinkedQueue;
import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;

String[] names = {
  "Up arrow", "Left arrow", "Right arrow", "Down arrow",
  "Left circle", "Right circle",
  "Left square", "Right square",
  "Left rectangle", "Right rectangle"
};

boolean[] held = new boolean[10];
int moveSpeed = 8;
String message = "Waiting for input...";

Serial port;
Robot robot;

import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;

// ... names[], held[], moveSpeed, message, Serial port, Robot robot ...

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

  String[] ports = Serial.list();
  printArray(ports);

  if (ports.length > 0) {
    // Change the index to match your Arduino in the printed list
    // (on Windows "COMx", on Mac "/dev/cu.usbmodem..." or "/dev/cu.usbserial...")
    port = new Serial(this, ports[0], 115200);
    port.bufferUntil('\n');
  } else {
    println("No Arduino found - use keys 0-9 to test");
  }
}

void draw() {
  background(255);
  fill(0);
  textAlign(CENTER, CENTER);
  textSize(28);
  text(message, width / 2, height / 2);

  moveMouse();
}

// Move the pointer while an arrow button is held down
void moveMouse() {
  int dx = 0;
  int dy = 0;

  if (held[0]) dy -= moveSpeed;   // up
  if (held[1]) dx -= moveSpeed;   // left
  if (held[2]) dx += moveSpeed;   // right
  if (held[3]) dy += moveSpeed;   // down

  if (dx != 0 || dy != 0) {
    Point p = MouseInfo.getPointerInfo().getLocation();
    robot.mouseMove(p.x + dx, p.y + dy);
  }
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;

  String[] parts = split(trim(line), ',');
  if (parts.length == 0) return;

  if (parts[0].equals("B") && parts.length == 3) {
    int b = int(parts[1]);
    boolean pressed = int(parts[2]) == 1;
    buttonChanged(b, pressed);
  } else if (parts[0].equals("F") && parts.length == 2) {
    int flex = int(parts[1]);
    // flex value not used yet in the tutorial
  }
}

void buttonChanged(int b, boolean pressed) {
  if (b < 0 || b > 9) return;
  held[b] = pressed;

  if (pressed) {
    message = "Button " + names[b] + " pressed";
  } else {
    message = "Button " + names[b] + " released";
  }
  println(message);
}

// Keyboard testing: keys 0-9 act like the buttons
void keyPressed() {
  if (key >= '0' && key <= '9') buttonChanged(key - '0', true);
}

void keyReleased() {
  if (key >= '0' && key <= '9') buttonChanged(key - '0', false);
}
