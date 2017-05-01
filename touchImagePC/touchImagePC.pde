/*
 * Can launch and connect to the demo app running on the watch
 */

/*
 * Name of the watch app - get this from the xml file of the watch app
 */
String WatchAppName = "processing.test.touchImageWatch";

/*
 * Will hold the path to the adb exe (required for launching the app, etc)
 */
String adbPath; 

/* 
 * Will hold debug info (if requested) from watch
 */
String debugStatus = "";

/*
 * Command line paramter to indicate the filename for logging data
 * Command line paramter to the ip address of host PC
 */
final String PARAM_LOG_FILE_NAME = "fn";
final String PARAM_IP_ADDRESS    = "ip";


/*
 * Init everything
 */
void setup() 
  {  
  size(400,600);                      // windowsize ;-)
  frameRate(30);                      // framerate ;-)
  adbPath = sketchPath() + "/adb";    // location of the adb exe - here its just in the sketch folder
  initUI();                           // init and prepare UI contents
  initTouchImage();                   // init the touch image data structures 
  oscP5 = new OscP5(this, HOST_PORT); // start oscP5, listening for incoming messages 
  }


/*
 * what we draw
 */
void draw() 
  {
  background(0); // black background
  
  /*
   * Get and show the data
   */
  int[] data = interpretData(touchImageData, (int)gridSizeX, (int)gridSizeY);
  if (data!=null)
    drawData(data, true, false, false, gridCellsX, gridCellsY, gridStartX, gridStartY, gridPixelsX, gridPixelsY);
    
  /*
   * show debug info, if we have it. 
   */
  if (debugStatus.length()>0)
    {
    textAlign(CENTER, CENTER);
    fill(255);
    text(debugStatus, width/2, height-120);
    }
}