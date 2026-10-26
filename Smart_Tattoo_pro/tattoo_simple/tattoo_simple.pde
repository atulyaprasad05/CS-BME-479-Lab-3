import processing.serial.*;
import java.awt.Robot;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;

Serial port;
Robot robot;

String[] actions = {
  "UP", "DOWN", "LEFT", "RIGHT",
  "LEFT_CLICK", "ENTER",
  "RIGHT_CLICK", "TAB", "SCROLL", "SPACE"
};

String[] labels = {
  "Up", "Down", "Left", "Right",
  "Left Click", "Enter",
  "Right Click", "Tab", "Scroll", "Space"
};

boolean[] held = new boolean[10];
int speed = 8;
String shown = "";

int flex = 0;
boolean scrollDown = true;
float scrollAmount = 0;

void setup() {
  size(500, 300);
  try {
    robot = new Robot();
  } catch (Exception e) {
    println(e);
  }
  printArray(Serial.list());
  port = new Serial(this, Serial.list()[2], 115200);
  port.bufferUntil('\n');
}

void draw() {
  background(255);
  fill(0);
  textAlign(CENTER, CENTER);
  textSize(40);
  text("Button: " + shown, width / 2, height / 2);

  moveMouse();
  scroll();
}

void moveMouse() {
  int dx = 0;
  int dy = 0;
  for (int i = 0; i < held.length; i++) {
    if (!held[i]) continue;
    if (actions[i].equals("UP")) dy -= speed;
    if (actions[i].equals("DOWN")) dy += speed;
    if (actions[i].equals("LEFT")) dx -= speed;
    if (actions[i].equals("RIGHT")) dx += speed;
  }
  if (dx == 0 && dy == 0) return;
  Point p = MouseInfo.getPointerInfo().getLocation();
  robot.mouseMove(p.x + dx, p.y + dy);
}

void scroll() {
  if (flex <= 20) {
    scrollAmount = 0;
    return;
  }
  scrollAmount += map(constrain(flex, 20, 100), 20, 100, 0.1, 0.5);
  int n = int(scrollAmount);
  if (n > 0) {
    robot.mouseWheel(scrollDown ? n : -n);
    scrollAmount -= n;
  }
}

void serialEvent(Serial p) {
  String line = trim(p.readStringUntil('\n'));
  if (line == null) return;
  String[] parts = split(line, ',');
  if (parts[0].equals("F") && parts.length == 2) {
    flex = int(parts[1]);
  } else if (parts[0].equals("B") && parts.length == 3) {
    button(int(parts[1]), parts[2].equals("1"));
  }
}

void button(int b, boolean pressed) {
  if (b < 0 || b >= held.length || held[b] == pressed) return;
  held[b] = pressed;
  String a = actions[b];

  if (pressed) {
    shown = labels[b];
    if (a.equals("SCROLL")) {
      scrollDown = !scrollDown;
      shown = scrollDown ? "Scroll Down" : "Scroll Up";
    }
  }

  if (a.equals("LEFT_CLICK")) click(InputEvent.BUTTON1_DOWN_MASK, pressed);
  if (a.equals("RIGHT_CLICK")) click(InputEvent.BUTTON3_DOWN_MASK, pressed);
  if (a.equals("ENTER")) key(KeyEvent.VK_ENTER, pressed);
  if (a.equals("TAB")) key(KeyEvent.VK_TAB, pressed);
  if (a.equals("SPACE")) key(KeyEvent.VK_SPACE, pressed);
}

void click(int mask, boolean pressed) {
  if (pressed) robot.mousePress(mask);
  else robot.mouseRelease(mask);
}

void key(int code, boolean pressed) {
  if (pressed) robot.keyPress(code);
  else robot.keyRelease(code);
}
