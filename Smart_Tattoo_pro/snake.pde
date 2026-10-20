/*
 * snake.pde — Snake game logic (no setup()/draw()/keyPressed() on purpose)
 *
 * Put this file in the same sketch folder as Smart_Tattoo_pro.pde. Processing
 * loads it as a tab, so everything shares one scope. Because of that, this
 * tab only defines classes; your main sketch drives it.
 *
 * Usage from Smart_Tattoo_pro.pde:
 *
 *   SnakeGame snake;
 *
 *   // in setup():
 *   snake = new SnakeGame(20, 12);        // grid is 20 cols x 12 rows
 *
 *   // in draw():
 *   snake.update();                        // advances game on its own timer
 *   Pair[] body = snake.getSnake();        // body[0] is the head
 *   Pair   food = snake.getFood();
 *   snake.display(0, 40, 24);              // optional: draw at (x0, y0), cell size
 *
 *   // in keyPressed():
 *   snake.handleKey(key, keyCode);
 *
 *   // or from any other input source (buttons, serial, etc.):
 *   snake.turnLeft();   snake.turnRight();
 *   snake.setDirection(SnakeGame.UP);      // UP, RIGHT, DOWN, LEFT
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
  int stepMillis = 150;      // time between moves
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

  // Call from keyPressed(): arrows or WASD; R restarts after game over
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

  // Advance exactly one tick (useful if you want to drive timing yourself)
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

  // Optional built-in renderer so you can test snake.pde on its own
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
      text((food == null ? "You win" : "Game over") + " — score " + score + "\nPress R to restart",
           x0 + cols * cell / 2, y0 + rows * cell / 2);
      textAlign(LEFT, BASELINE);
    }
  }
}
