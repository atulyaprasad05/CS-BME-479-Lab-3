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

  // CHANGE COM3 if necessary
  port = new Serial(this, "COM3", 115200);

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


  // Convert Arduino message to integer
  int pad = int(line);

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
