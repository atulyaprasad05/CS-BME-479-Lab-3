/*
 * robot_mouse.pde — moves/clicks the real OS mouse using java.awt.Robot,
 * driven by 4 on/off buttons over serial.
 *
 * Serial lines expected (one per line, buttons numbered 0..3):
 *   "0 pressed"   "0 released"
 *   "1 pressed"   "1 released"
 *   ...
 *
 * Remap what each button does by editing the `action` array below.
 */

import java.awt.Robot;
import java.awt.AWTException;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.event.InputEvent;

// Possible actions for a button
final int ACT_NONE        = 0;
final int ACT_MOVE_LEFT   = 1;
final int ACT_MOVE_RIGHT  = 2;
final int ACT_MOVE_UP     = 3;
final int ACT_MOVE_DOWN   = 4;
final int ACT_CLICK_LEFT  = 5;   // held = button held down (so you can drag)
final int ACT_CLICK_RIGHT = 6;

class RobotMouse {
  Robot robot;
  boolean enabled = true;

  // What each of the 4 buttons does. Change these to remap.
  int[] action = { ACT_MOVE_LEFT, ACT_MOVE_RIGHT, ACT_MOVE_UP, ACT_MOVE_DOWN };

  //number of defined buttons, increment when more buttons added
  boolean[] held = new boolean[6];
  int[] heldFrames = new int[6];

  float baseSpeed = 4;      // pixels per frame when a button is first pressed
  float accel = 0.35;       // extra pixels/frame for each frame held
  float maxSpeed = 30;

  RobotMouse() {
    try {
      robot = new Robot();
    } catch (AWTException e) {
      println("Robot unavailable: " + e);
      robot = null;
      enabled = false;
    }
  }

  // ---------- serial input ----------

  // Returns true if the line was a "<id> pressed|released" message
  boolean handleSerialLine(String line) {
    String[] p = splitTokens(line);
    if (p.length != 2 || !p[0].matches("\\d+")) return false;
    int id = int(p[0]);
    if (id < 0 || id >= held.length) return false;

    if (p[1].equals("pressed"))       press(id);
    else if (p[1].equals("released")) release(id);
    else return false;
    return true;
  }

  synchronized void press(int id) {
    if (held[id]) return;
    held[id] = true;
    heldFrames[id] = 0;
    if (!enabled || robot == null) return;
    if (action[id] == ACT_CLICK_LEFT)  robot.mousePress(InputEvent.BUTTON1_DOWN_MASK);
    if (action[id] == ACT_CLICK_RIGHT) robot.mousePress(InputEvent.BUTTON3_DOWN_MASK);
  }

  synchronized void release(int id) {
    if (!held[id]) return;
    held[id] = false;
    if (robot == null) return;
    if (action[id] == ACT_CLICK_LEFT)  robot.mouseRelease(InputEvent.BUTTON1_DOWN_MASK);
    if (action[id] == ACT_CLICK_RIGHT) robot.mouseRelease(InputEvent.BUTTON3_DOWN_MASK);
  }

  // ---------- per-frame movement ----------

  // Call once per frame from draw()
  synchronized void update() {
    if (!enabled || robot == null) return;

    float dx = 0, dy = 0;
    for (int i = 0; i < held.length; i++) {
      if (!held[i]) continue;
      heldFrames[i]++;
      float s = min(maxSpeed, baseSpeed + accel * heldFrames[i]);
      if (action[i] == ACT_MOVE_LEFT)  dx -= s;
      if (action[i] == ACT_MOVE_RIGHT) dx += s;
      if (action[i] == ACT_MOVE_UP)    dy -= s;
      if (action[i] == ACT_MOVE_DOWN)  dy += s;
    }

    if (dx != 0 || dy != 0) {
      Point p = MouseInfo.getPointerInfo().getLocation();   // screen coordinates
      robot.mouseMove(p.x + round(dx), p.y + round(dy));
    }
  }

  // ---------- safety ----------

  synchronized void releaseAll() {
    for (int i = 0; i < held.length; i++) release(i);
  }

  synchronized void toggle() {
    if (robot == null) return;
    if (enabled) releaseAll();
    enabled = !enabled;
  }
}
