/*
 * 02 — Interaction Basics
 * Teaches: mouse & keys, state machine, functions returning values
 */
import processing.serial.*;

SnakeGame snake;
RobotMouse rmouse;
Serial port;

int touchBits = 0;
int flexPercent = 0;

int mode = 0; // 0=paint, 1=erase
color paintColor = color(220, 40, 90);
int buttonId = -1;
boolean buttonDown = false;

void setup() {
  size(800, 480);                 // must be first
  frameRate(60);
  background(255);
  surface.setTitle("02 — Interaction Basics");

  snake = new SnakeGame(20, 12);
  rmouse = new RobotMouse();      // create before opening serial

  String[] ports = Serial.list();
  printArray(ports);
  if (ports.length > 1) {         // change 1 to your Arduino's index
    port = new Serial(this, ports[1], 115200);
    port.bufferUntil('\n');
  } else {
    println("No Arduino found, running without serial");
  }
}

void draw() {
  drawHUD();
  if (mousePressed) {
    if (mode == 0) stroke(paintColor);
    else           stroke(255);
    strokeWeight(12);
    line(pmouseX, pmouseY, mouseX, mouseY);
  }
  rmouse.update();                // move the OS mouse from held buttons
  snake.update();
  snake.display(0, 40, 24);       // optional built-in renderer
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  line = trim(line);

  // "0 pressed", "0 released", ... "3 released"
  if (rmouse.handleSerialLine(line)) return;

  // otherwise, old format e.g. "5,42" -> touchBits, flexPercent
  String[] parts = split(line, ',');
  if (parts.length == 2) {
    touchBits = int(parts[0]);
    flexPercent = int(parts[1]);
  }
}

void keyPressed() {
  if (key == 'e' || key == 'E') mode = 1;
  if (key == 'p' || key == 'P') mode = 0;
  if (key == 'c' || key == 'C') background(255);
  if (key == 'm' || key == 'M') rmouse.toggle();   // enable/disable Robot mouse
  snake.handleKey(key, keyCode);
}

void mousePressed() {
  buttonId = mouseButton;
  buttonDown = true;
}

void mouseReleased() {
  buttonDown = false;
}

// make sure no mouse button is left stuck down when the sketch closes
void exit() {
  rmouse.releaseAll();
  super.exit();
}

void drawHUD() {
  noStroke();
  fill(255, 240);
  rect(0, 0, width, 36);
  fill(20);
  textSize(14);
  text("Press P=paint, E=erase, C=clear, M=robot mouse • mode = " + (mode==0?"PAINT":"ERASE")
       + " • robot = " + (rmouse.enabled ? "ON" : "OFF"), 10, 24);
}
