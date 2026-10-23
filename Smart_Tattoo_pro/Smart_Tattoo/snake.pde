/*
 * snake.pde — Snake game (started from the Snake button)
 *
 * No setup()/draw()/keyPressed() on purpose: Smart_Tattoo.pde drives it.
 *   - tattoo pads steer the snake using Snake's own per-device table (snakeBtn),
 *     defaulting to the tutorial's arrows; use "Remap pads" to change it
 *   - keyboard: arrow keys steer; q w e r t y u i o p are pads 0-9
 *   - after game over, any pad press restarts
 */

// Simple integer (x, y) pair — Processing/Java has no built-in pair<int,int>
class Pair {
  int x, y;
  Pair(int x, int y) { this.x = x; this.y = y; }
  boolean same(Pair o) { return x == o.x && y == o.y; }
}

class SnakeGame {
  // directions, clockwise so turnRight = +1, turnLeft = -1
  final int UP = 0, RIGHT = 1, DOWN = 2, LEFT = 3;

  int cols, rows;
  ArrayList<Pair> body = new ArrayList<Pair>();   // body.get(0) = head
  Pair food;
  int dir, nextDir;
  boolean alive;
  int score;
  int stepMillis = 500;      // time between moves
  int lastStep;

  SnakeGame(int cols, int rows) {
    this.cols = cols;
    this.rows = rows;
    reset();
  }

  void reset() {
    body.clear();
    int cx = cols / 2, cy = rows / 2;
    body.add(new Pair(cx, cy));
    body.add(new Pair(cx - 1, cy));
    body.add(new Pair(cx - 2, cy));
    dir = RIGHT;
    nextDir = RIGHT;
    alive = true;
    score = 0;
    lastStep = millis();
    placeFood();
  }

  // ---------- INPUT ----------

  void setDirection(int d) {
    // ignore 180-degree reversals
    if ((d + 2) % 4 == dir) return;
    nextDir = d;
  }

  void turnLeft()  { setDirection((dir + 3) % 4); }
  void turnRight() { setDirection((dir + 1) % 4); }

  // Call from keyPressed(): arrows or WASD; R restarts
  void handleKey(char k, int kc) {
    if (kc == PApplet.UP    || k == 'w' || k == 'W') setDirection(UP);
    if (kc == PApplet.RIGHT || k == 'd' || k == 'D') setDirection(RIGHT);
    if (kc == PApplet.DOWN  || k == 's' || k == 'S') setDirection(DOWN);
    if (kc == PApplet.LEFT  || k == 'a' || k == 'A') setDirection(LEFT);
    if (k == 'r' || k == 'R') reset();
  }

  // ---------- LOGIC ----------

  // Call every frame; moves the snake only when the step timer elapses
  void update() {
    if (!alive) return;
    if (millis() - lastStep >= stepMillis) {
      lastStep = millis();
      step();
    }
  }

  // Advance exactly one tick
  void step() {
    if (!alive) return;
    dir = nextDir;

    Pair head = body.get(0);
    int nx = head.x, ny = head.y;
    if (dir == UP)    ny--;
    if (dir == DOWN)  ny++;
    if (dir == LEFT)  nx--;
    if (dir == RIGHT) nx++;

    // wall collision
    if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) { alive = false; return; }

    boolean eating = (food != null && nx == food.x && ny == food.y);

    // self collision (tail will move away unless we're eating)
    int checkLen = eating ? body.size() : body.size() - 1;
    for (int i = 0; i < checkLen; i++) {
      Pair p = body.get(i);
      if (p.x == nx && p.y == ny) { alive = false; return; }
    }

    body.add(0, new Pair(nx, ny));
    if (eating) {
      score++;
      placeFood();
    } else {
      body.remove(body.size() - 1);
    }
  }

  void placeFood() {
    if (body.size() >= cols * rows) { food = null; alive = false; return; }
    while (true) {
      Pair f = new Pair((int) random(cols), (int) random(rows));
      boolean clash = false;
      for (Pair p : body) if (p.same(f)) { clash = true; break; }
      if (!clash) { food = f; return; }
    }
  }

  // ---------- OUTPUT ----------

  // Snake positions as an array of (x, y) pairs; index 0 is the head
  Pair[] getSnake() {
    Pair[] out = new Pair[body.size()];
    for (int i = 0; i < out.length; i++) {
      Pair p = body.get(i);
      out[i] = new Pair(p.x, p.y);   // copies, so callers can't corrupt game state
    }
    return out;
  }

  Pair getFood() { return food == null ? null : new Pair(food.x, food.y); }

  boolean isAlive() { return alive; }
  int getScore()    { return score; }

  void display(int x0, int y0, int cell) {
    noStroke();
    fill(240);
    rect(x0, y0, cols * cell, rows * cell);

    // food (skip if the board is full)
    if (food != null) {
      fill(220, 40, 40);
      rect(x0 + food.x * cell, y0 + food.y * cell, cell, cell);
    }

    // snake body: head is darker green
    for (int i = 0; i < body.size(); i++) {
      Pair p = body.get(i);
      fill(i == 0 ? color(0, 120, 0) : color(40, 180, 60));
      rect(x0 + p.x * cell, y0 + p.y * cell, cell, cell);
    }

    if (!alive) {
      fill(0, 160);
      rect(x0, y0, cols * cell, rows * cell);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(20);
      text((food == null ? "You win" : "Game over") + " — score " + score
           + "\nPress R or any pad to restart",
           x0 + cols * cell / 2, y0 + rows * cell / 2);
      textAlign(LEFT, BASELINE);
    }
  }
}


// ===============================================================
// GLUE (called from Smart_Tattoo.pde)
// ===============================================================
SnakeGame snake;
int snakeDeadSince = 0;

// Snake's own pad config, one row per device: pad number for { UP, DOWN, LEFT, RIGHT }.
// Defaults are copied from the tutorial's arrow pads (0 up, 1 down, 2 left, 3 right),
// but this table is independent: changing it never affects the home pad or the tutorial.
final String[] SNAKE_DIR_NAMES = { "UP", "DOWN", "LEFT", "RIGHT" };
int[][] snakeBtn = { { 0, 1, 2, 3 }, { 0, 1, 2, 3 } };
int snakeRemapStep = -1;        // -1 = not remapping, else 0-3 = which direction is being assigned


void snakeEnter() {
  snake = new SnakeGame(20, 12);
  snakeDeadSince = 0;
  snakeRemapStep = -1;
}


// "Remap pads" button geometry (just left of the Tutorial button)
float snakeRemapX() { return modeBtnX(0) - MODE_BTN_GAP - MODE_BTN_W; }

boolean snakeRemapHit(float x, float y) {
  return x > snakeRemapX() && x < snakeRemapX() + MODE_BTN_W
      && y > MODE_BTN_Y && y < MODE_BTN_Y + MODE_BTN_H;
}

void snakeToggleRemap() {
  snakeRemapStep = (snakeRemapStep >= 0) ? -1 : 0;
}


// a tattoo pad was pressed while Snake is showing
void snakePress(int b) {
  if (snake == null) return;

  // remapping: assign this pad to the next direction (no pad twice)
  if (snakeRemapStep >= 0) {
    for (int k = 0; k < snakeRemapStep; k++) {
      if (snakeBtn[device][k] == b) return;
    }
    snakeBtn[device][snakeRemapStep] = b;
    snakeRemapStep++;
    if (snakeRemapStep >= 4) {
      snakeRemapStep = -1;
      snake.reset();
    }
    return;
  }

  if (!snake.isAlive()) {
    // short delay so mashing directions as you die doesn't skip the game-over screen
    if (snakeDeadSince > 0 && millis() - snakeDeadSince > 800) snake.reset();
    return;
  }

  int[] m = snakeBtn[device];
  if (b == m[0])      snake.setDirection(snake.UP);
  else if (b == m[1]) snake.setDirection(snake.DOWN);
  else if (b == m[2]) snake.setDirection(snake.LEFT);
  else if (b == m[3]) snake.setDirection(snake.RIGHT);
}


void snakeDraw() {
  if (snake == null) return;
  boolean remapping = snakeRemapStep >= 0;
  if (!remapping) snake.update();

  if (snake.isAlive()) snakeDeadSince = 0;
  else if (snakeDeadSince == 0) snakeDeadSince = millis();

  fill(20);
  textAlign(LEFT, BASELINE);
  textSize(20);
  text("SNAKE - Score " + snake.getScore(), 20, 28);

  // Remap pads / Cancel remap button
  float rx = snakeRemapX();
  stroke(140);
  strokeWeight(1);
  fill(snakeRemapHit(mouseX, mouseY) ? color(255, 220, 120) : (remapping ? color(255, 235, 190) : color(255)));
  rect(rx, MODE_BTN_Y, MODE_BTN_W, MODE_BTN_H, 6);
  fill(20);
  textAlign(CENTER, CENTER);
  textSize(15);
  text(remapping ? "Cancel remap" : "Remap pads", rx + MODE_BTN_W / 2, MODE_BTN_Y + MODE_BTN_H / 2 - 1);

  int top = 56;       // room for the mode buttons
  int bottom = 34;    // room for the footer
  int availH = height - top - bottom;
  int cell = min(width / snake.cols, availH / snake.rows);
  int x0 = (width - cell * snake.cols) / 2;           // center horizontally
  int y0 = top + (availH - cell * snake.rows) / 2;    // center vertically
  snake.display(x0, y0, cell);

  if (remapping) {
    noStroke();
    fill(0, 170);
    rect(x0, y0, cell * snake.cols, cell * snake.rows);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(26);
    text("Press the pad for " + SNAKE_DIR_NAMES[snakeRemapStep]
         + "\n(" + (snakeRemapStep + 1) + " of 4)", width / 2, height / 2);
  }
}
