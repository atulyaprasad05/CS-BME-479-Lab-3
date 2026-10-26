// snake.pde - Snake game logic
//
// Usage from the main sketch:
//   SnakeGame snake;
//   setup():      snake = new SnakeGame(20, 12);   // 20 cols x 12 rows
//   draw():       snake.update();
//                 snake.display(0, 40, 24);
//   keyPressed(): snake.handleKey(key, keyCode);
//
// Other calls: turnLeft(), turnRight(), setDirection(UP), getSnake(), getFood()

class Pair {
  int x, y;
  Pair(int x, int y) {
    this.x = x;
    this.y = y;
  }
}

class SnakeGame {
  // turnRight = +1, turnLeft = -1
  final int UP = 0, RIGHT = 1, DOWN = 2, LEFT = 3;

  int cols, rows;
  ArrayList<Pair> body = new ArrayList<Pair>();   // body.get(0) is the head
  Pair food;
  int dir, nextDir;
  boolean alive;
  int score;
  int stepMillis = 500;
  int lastStep;

  SnakeGame(int cols, int rows) {
    this.cols = cols;
    this.rows = rows;
    reset();
  }

  void reset() {
    body.clear();
    int cx = cols / 2;
    int cy = rows / 2;
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

  void setDirection(int d) {
    if ((d + 2) % 4 == dir) return;   // ignore 180-degree reversals
    nextDir = d;
  }

  void turnLeft()  { setDirection((dir + 3) % 4); }
  void turnRight() { setDirection((dir + 1) % 4); }

  // Arrows or WASD to turn, R to restart
  void handleKey(char k, int kc) {
    if (kc == PApplet.UP    || k == 'w' || k == 'W') setDirection(UP);
    if (kc == PApplet.RIGHT || k == 'd' || k == 'D') setDirection(RIGHT);
    if (kc == PApplet.DOWN  || k == 's' || k == 'S') setDirection(DOWN);
    if (kc == PApplet.LEFT  || k == 'a' || k == 'A') setDirection(LEFT);
    if (k == 'r' || k == 'R') reset();
  }

  // Call every frame; the snake only moves when the step timer runs out
  void update() {
    if (!alive) return;
    if (millis() - lastStep >= stepMillis) {
      lastStep = millis();
      step();
    }
  }

  // Move the snake one cell
  void step() {
    if (!alive) return;
    dir = nextDir;

    Pair head = body.get(0);
    int nx = head.x;
    int ny = head.y;
    if (dir == UP)    ny--;
    if (dir == DOWN)  ny++;
    if (dir == LEFT)  nx--;
    if (dir == RIGHT) nx++;

    // hit a wall
    if (nx < 0 || nx >= cols || ny < 0 || ny >= rows) {
      alive = false;
      return;
    }

    boolean eating = (food != null && nx == food.x && ny == food.y);

    // hit itself (the tail moves away unless we are eating)
    int checkLen = eating ? body.size() : body.size() - 1;
    for (int i = 0; i < checkLen; i++) {
      Pair p = body.get(i);
      if (p.x == nx && p.y == ny) {
        alive = false;
        return;
      }
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
    // board is full: you win
    if (body.size() >= cols * rows) {
      food = null;
      alive = false;
      return;
    }
    while (true) {
      int fx = (int) random(cols);
      int fy = (int) random(rows);
      boolean clash = false;
      for (Pair p : body) {
        if (p.x == fx && p.y == fy) clash = true;
      }
      if (!clash) {
        food = new Pair(fx, fy);
        return;
      }
    }
  }

  // Snake positions, index 0 is the head (copies, so game state is safe)
  Pair[] getSnake() {
    Pair[] out = new Pair[body.size()];
    for (int i = 0; i < out.length; i++) {
      out[i] = new Pair(body.get(i).x, body.get(i).y);
    }
    return out;
  }

  Pair getFood() {
    return food == null ? null : new Pair(food.x, food.y);
  }

  boolean isAlive() { return alive; }
  int getScore()    { return score; }

  // Draw the board at (x0, y0) with square cells of size "cell"
  void display(int x0, int y0, int cell) {
    noStroke();
    fill(240);
    rect(x0, y0, cols * cell, rows * cell);

    if (food != null) {
      fill(220, 40, 40);
      rect(x0 + food.x * cell, y0 + food.y * cell, cell, cell);
    }

    // head is darker green than the body
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
      String result = (food == null) ? "You win" : "Game over";
      text(result + " — score " + score + "\nPress R to restart",
           x0 + cols * cell / 2, y0 + rows * cell / 2);
      textAlign(LEFT, BASELINE);
    }
  }
}
