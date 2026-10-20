// Processing: moves a circle based on 4 touch pads, speed set by flex sensor.
// Pad 0 = up, Pad 1 = down, Pad 2 = left, Pad 3 = right
// Flex sensor: 0% (straight) = slow, 100% (fully bent) = fast

import processing.serial.*;

Serial port;
float x, y;
int touchBits = 0;
int flexPercent = 0;

void setup() {
  size(600, 600);
  x = width / 2;
  y = height / 2;

  println(Serial.list());          // check this list in the console
  // Change the 0 to the index of your Arduino's port in the list above
  port = new Serial(this, Serial.list()[0], 115200);
  port.bufferUntil('\n');
}

void draw() {
  background(30);

  // speed from 1 (straight) to 10 (fully bent)
  float speed = map(flexPercent, 0, 100, 1, 10);

  if ((touchBits & 1) != 0) y -= speed;  // pad 0: up
  if ((touchBits & 2) != 0) y += speed;  // pad 1: down
  if ((touchBits & 4) != 0) x -= speed;  // pad 2: left
  if ((touchBits & 8) != 0) x += speed;  // pad 3: right

  x = constrain(x, 25, width - 25);
  y = constrain(y, 25, height - 25);

  fill(255, 120, 60);
  noStroke();
  ellipse(x, y, 50, 50);

  fill(255);
  text("speed: " + nf(speed, 1, 1), 10, 20);
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length == 2) {
    touchBits = int(parts[0]);
    flexPercent = int(parts[1]);
  }
}
