/*
 * 02 — Interaction Basics
 * Teaches: mouse & keys, state machine, functions returning values
 */
SnakeGame snake;

int mode = 0; // 0=paint, 1=erase
color paintColor = color(220, 40, 90);

pair<int, bool> buttonPressed = new ;

void setup() {
  size(800, 480);
  background(255);
  surface.setTitle("02 — Interaction Basics");
}

void setup () {
  frameRate(60);
  snake = new SnakeGame(20, 12);


  for (String f : dataFields) series.put(f, new ArrayList<Float>());
  String[] ports = Serial.list();
  printArray(ports);
  if (serialPortIndex < ports.length) {
    port = new Serial(this, ports[serialPortIndex], 115200);
    port.clear();
  }

  paletteColors = new color[] {red, orange, yellow, green, blue, black, color(255)};
  paint = createGraphics(canvasW, canvasH);

  // fonts
  headerFont = createFont("AveriaSerifLibre-Regular.ttf", 32);
  mainFont  = createFont("ShareTech-Regular.ttf", 20);
}



void draw() {
  drawHUD();
  if (mousePressed) {
    if (mode == 0) stroke(paintColor);
    else           stroke(255);
    strokeWeight(12);
    line(pmouseX, pmouseY, mouseX, mouseY);
  }
  snake.update();
  Pair[] body = snake.getSnake();
  Pair food = snake.getFood();
  snake.display(0, 40, 24);   // optional built-in renderer
}

void keyPressed() {
  if (key == 'e' || key == 'E') mode = 1;
  if (key == 'p' || key == 'P') mode = 0;
  if (key == 'c' || key == 'C') background(255);
  snake.handleKey(key, keyCode);

}

void drawHUD() {
  noStroke();
  fill(255, 240);
  rect(0, 0, width, 36);
  fill(20);
  textSize(14);
  text("Press P=paint, E=erase, C=clear • mode = " + (mode==0?"PAINT":"ERASE"), 10, 24);
}
