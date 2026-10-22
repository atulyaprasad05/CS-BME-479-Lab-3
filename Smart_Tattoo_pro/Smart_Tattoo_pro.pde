/*
 * SMART TATTOO - SNAKE GAME
 *
 * Arduino sends:
 * 0 = UP
 * 1 = DOWN
 * 2 = LEFT
 * 3 = RIGHT
 */

import processing.serial.*;

SnakeGame snake;
Serial port;


// =====================================================
// SETUP
// =====================================================

void setup() {

  size(800, 480);
  frameRate(60);

  surface.setTitle("Smart Tattoo - Snake Game");

  // Create Snake game
  snake = new SnakeGame(20, 12);


  // ===================================================
  // SERIAL CONNECTION
  // ===================================================

  // Show available serial ports
  printArray(Serial.list());

  // change the index if the Arduino is on a different port
  port = new Serial(this, Serial.list()[2], 115200);

  // Call serialEvent every time \n is received
  port.bufferUntil('\n');

  // Clear old serial data
  port.clear();

  println("Smart Tattoo Snake started");
}


// =====================================================
// DRAW
// =====================================================

void draw() {

  background(255);

  fill(20);
  textSize(20);
  text("SMART TATTOO - SNAKE", 20, 28);

  snake.update();
  snake.display(0, 40, 24);
}


// =====================================================
// SERIAL FROM ARDUINO
// =====================================================

void serialEvent(Serial p) {

  String line = p.readStringUntil('\n');

  if (line == null) {
    return;
  }

  line = trim(line);

  if (line.length() == 0) {
    return;
  }


  // Accepts "B,pad,state" (only presses are used; flex "F,..." and
  // releases are ignored) or the older plain "pad" format
  int pad;
  String[] parts = split(line, ',');

  if (parts.length == 3 && parts[0].equals("B")) {
    if (int(parts[2]) != 1) return;
    pad = int(parts[1]);
  } else if (parts.length == 1 && line.matches("\\d+")) {
    pad = int(line);
  } else {
    return;
  }

  println("Arduino sent: " + pad);


  // ===================================================
  // PAD -> SNAKE DIRECTION
  // ===================================================

  if (pad == 0) {

    println("UP");

    snake.setDirection(snake.UP);
  }

  else if (pad == 1) {

    println("DOWN");

    snake.setDirection(snake.DOWN);
  }

  else if (pad == 2) {

    println("LEFT");

    snake.setDirection(snake.LEFT);
  }

  else if (pad == 3) {

    println("RIGHT");

    snake.setDirection(snake.RIGHT);
  }
}


// =====================================================
// KEYBOARD CONTROL
// =====================================================

void keyPressed() {

  // Keep keyboard control for testing
  snake.handleKey(key, keyCode);
}
