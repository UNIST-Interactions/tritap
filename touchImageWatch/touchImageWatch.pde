/*
 * Main demo app for Sony SW3 raw touch screen reading
 * You need to install the librarys
 * 1. touchImageMoments (included with this app)
 * 2. oscP5 (download it)
 * 
 * You also need run this on a Sony SW3 with a modified kernel that reports raw touch events (also included with this app).
 *
 * Compiled using Processing 3.2.3 and Android Mode 4.0 beta 3
 */


/*
 * Lib for logging to adb
 */
import android.util.Log;


/*
 * font for displaying debug info
 */
PFont fontA;


/* 
 * Bools that control drawing options 
 */
boolean debugMode         = false; // show debug info (turns off draw screen), prints some basic stats instead
boolean showScreen        = true;  // show touches full screen
boolean showMiniScreen    = true;  // show a minimap of touches
boolean showTextMsgs      = false; // show formatted data from the library
boolean showSketchData    = false; // report messages, data and parsing problems in the sketch


/*
 * Command line paramter to indicate the filename for logging data
 * Command line paramter to the ip address of host PC
 */
final String PARAM_LOG_FILE_NAME = "fn";
final String PARAM_IP_ADDRESS    = "ip";


/* 
 * Some state vars that enable an event when the whole screen is touched - hacky
 */
int        palmBrightness;          // overall brightness of the screen - palm detection  
long       palmChange;              // last time we triggered an event based on screen brightness (palm detected) 
boolean    palmState;               // the current mode (toggle) for the screen brightness (palm) event
final int  palmBrightnessThreshold = 180;  // the threshold over which to trigger an event (subjectively selected...)
final long palmWait                = 2000; // how long to wait between trigger palm events (2 seconds)

/*
 * whole screen (palming) used to control framerate
 */
final int FRAMERATE_SLOW = 1; 
final int FRAMERATE_FAST = 15; 
 

/*
 * Init everything
 */
void setup()
{  
  /*
   * Init basic graphics
   */
  orientation(PORTRAIT);
  size(displayWidth, displayHeight, P2D);  

  /* 
   * Init palm detection vars. Used to control framerate at the moment
   */
  palmChange = millis();       // say we switched it now to be stable at startup
  palmState = true;            // set to an initial state
  frameRate(FRAMERATE_FAST);   // Currently using it to set the frameRate

  /*
   * Init/config system utils
   */
  keepScreenOn(); // Keep the screen always on. 
  initBattery();  // init the battery level checker

  /*
   * Setup font - just use standard android...
   */
  textSize(32);
  textAlign(CENTER, CENTER);

  /*
   * Look for a file name as a command parameter - if found, will start logging
   */
  String fn = surface.getActivity().getIntent().getStringExtra(PARAM_LOG_FILE_NAME); 
  if (fn==null)
    Log.d("LogFile", "No file found for data logging. Disabled.");
  else
    Log.d("LogFile", "Using filename for data logging: " + fn);

  /*
   * Init the touch image object - takes the logfile 
   */
  initTouchImage(fn); 

  /*
   * Init networking - check to see if we have an ip address as a command line param. If so, we will send msgs there. 
   */
  initOSC(surface);
}


/*
 * Update and draw everything.
 */
void draw()
{
  // work on the thread safe local copy of the data in touchImageData
  int[] data = interpretData(touchImageData, (int)gridSizeX, (int)gridSizeY, showSketchData);     
  
  if (data!=null)                         // if we have data
  {
    background(64);                       // first blank the screen...
    
    if (debugMode)                        // if we are showing debug info
    {
      drawData(data, false, true, false); // only draw data on the mini screen
      drawDebugMode();                    // draw debug text
    } 
    else                                   
      drawData(data);                     // just draw the standard contents - set by sketch vars

    sendOSC();                            // if OSC messages enabled, send them

    drawEllipses(localMoments);           // draw ellipses using a thread safe local copy of the data 

    checkPalmEvent();                     // check for a hand over the device event to trigger some functionality
  }
}


/*
 * An on watch UI to control a setting (frameRate at the moment
 * Just cover the watch with your hand
 */
void checkPalmEvent()
{
  if (palmBrightness>palmBrightnessThreshold) 
  {
    long now = millis(); 
    if (now-palmChange>palmWait)
    {
      palmChange = now;   
      palmState = !palmState;
      
      // here adjust this to do whatever you want on the palm event (e.g. quit?) 
      // currently used for framerate toggle (fast/slow)
      if (palmState)
        frameRate(FRAMERATE_FAST); 
      else
        frameRate(FRAMERATE_SLOW);
    }
  }
}


/*
 * Print various debug/status info
 */
void drawDebugMode()
{
  fill(255);  
  text("Rate: " + tImage.getPacketRate(), width/2, height/6);
  text("Fail: " + tImage.getPacketFail(), width/2, height/6*2);
  text("Time: " + millis()/1000, width/2, height/6*3);
  text("Wait: " + tImage.getPauseCount(), width/2, height/6*4);
  text("Power: "+ (int)(checkBattery()*100), width/2, height/6*5);
}