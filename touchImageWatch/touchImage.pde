/*
 * Touch image code - work with the lib, parse and draw data.  
 */

/*
 * Import lib to grab/store/process touch image and fit ellipses using moments
 */
import kr.ac.unist.interactions.touchimagemoments.*;
TouchImageMoments tImage;    // Class for reading the proc file/processing the touch image
int touchImagePID = -1;      // The packetID of the lastest touchimage - check if we get all data
String touchImageData;       // Raw touch image data ends up here.  
ArrayList<MomentsData> localMoments; // Ellispes end up in here. 


/*
 * The name of the proc file produced by the kernel - this shouldn't be changed unless you are recompiling the kernel 
 * and using a different name for the raw data output final there
 */
final String PROC_FILE_NAME = "/proc/touch_img_reporting"; 


/*
 * Size params for the SonySW3
 */
// the number of grid cells in the screen. Sony SW has 7x7 touch sensors
final float gridCellsX  = 7; 
final float gridCellsY  = 7; 
// this is the start coords of the grid we are using. Sony SW starts at 0,0 - cover whole screen 
final float gridStartX  = 0;
final float gridStartY  = 0;
// this is the size of the grid we are using. Sony SW this is 7,7 - covers the whole screen 
final float gridSizeX   = 7;
final float gridSizeY   = 7;
// this is the pixel size of each grid cell. Need init after startup to get correct width/height (its 320x320)
float    gridPixelsX; 
float    gridPixelsY; 


/*
 * Threshold mappings params for the sensor data -  
 */
int sensorMin = 10;        // no/low activation. If you want to threshold all mappings, raise this value >0
int sensorMax = 255;       // high activaton. If you want to magnify low level changes, make this value small 
int sensorThreshold = 10;  // additional threshold for the data - some of the mapping modes use a threshold, some do not
int sensorMode = ImageMoments.LOG; // the mapping mode we are using (basically different gamma corrections)


/*
 * The size (as a devisor of the large screen) of the mini display
 */
final float MINI_SIZE_DIVISOR  = 5.0;


/*
 * Initialize the touch image. 
 */
void initTouchImage(String logFile)
  {
  /*
   * Finalize sensor size vars - this finalizes the sensor size in terms of display pixels
   * Must be cal'd in setup (after width/height are defined)
   */
  gridPixelsX = width/(float)gridCellsX; 
  gridPixelsY = height/(float)gridCellsY;  
    
  /*
   * Init local data stores for the touch/ellipses info
   */
  touchImageData = "";
  localMoments = new ArrayList<MomentsData>();  
    
  /*
   * Init touchImage object. Params are 
   * 1. pointer to sketch (PApplet), 
   * 2. name of proc file (string), 
   * 3. logData_True/False (boolean), 
   * 4. logDataFileID  (string)
   * Leave the first two unchanged. Change the boolean depending on if you want the lib to log data. 
   * Any string should work with logDataFileID. The lib appends other details such as a path and datestamp. 
   */  
  tImage = new TouchImageMoments(this, PROC_FILE_NAME, logFile!=null, logFile); 
  // config the sensor with the threshold and size settings - see comments for these vars above
  tImage.configThreshold(sensorMin, sensorMax, sensorThreshold, sensorMode, true);
  tImage.configSensor((int)gridCellsX, (int)gridCellsY, (int)gridStartX, (int)gridStartY, (int)gridSizeX, (int)gridSizeY);
  // report problems in the lib to adb
  tImage.showErrors();
  // start running: checking the proc file for the touch image
  tImage.start();
  }


/*
 * Receives touch image data from the lib via an event
 * Format: touchPacketID;TouchData0,TouchData1,TouchData2,...TouchDataN 
 * touchPacketID is 0-99, where TouchData<N> is a signed int 
 * Example:"59;0,0,0,0,15,0,1428,0,0,0,0,0,0,0,0,26,14,...N"
 */
void onTouchImage(String touchImageData_In)
{
  synchronized(this)
  {
    if (touchImageData_In!=null && touchImageData_In.length()>0)
    {
      String[] parts = split(touchImageData_In, ";"); 
      if (parts.length!=2)
        {
        println("Sketch-onTouchImage: Malformed data: " + touchImageData_In);
        return;
        }
      
      try 
        {
        int newTouchImagePID = Integer.parseInt(parts[0]); 
        if (!((newTouchImagePID == touchImagePID+1) || (newTouchImagePID==0 && touchImagePID==99) || touchImagePID==-1))
          println("Sketch-onTouchImage: TouchImagePID skipped from " + touchImagePID + " to " + newTouchImagePID); 
        touchImagePID = newTouchImagePID;
        touchImageData = parts[1]; // make a local copy
        }
      catch (NumberFormatException e)
        {
        println("Sketch-onTouchImage: Number format exception: " + touchImageData_In);
        }
    }
  }
}


/*
 * Ellipse processing events - regular update to ellispes
 */
void onEllipse(ArrayList<MomentsData> m)
  {
  synchronized(this)
    {
    localMoments = new ArrayList<MomentsData>();
    for (int i=0;i<m.size();i++)
      localMoments.add(m.get(i));
    }
  }


/*
 * Ellipse processing events - down as regular update for now
 */
void downEllipse(ArrayList<MomentsData> m)
  {onEllipse(m);}  
  
  
/* 
 * No ellipses left - clear
 */
void upEllipse()
  {
  synchronized(this)
    {localMoments.clear();}  
  }  
  

/* 
 * Process a packet of touch input data into an int array
 * dataIn should be <data0, data1,... dataN>.
 * dataN == dataXSize * dataYSize
 * Example:"0,0,0,0,15,0,1428,0,0,0,0,0,0,0,0,26,14,13,540,...N"
 */
int[] interpretData(String dataIn, int dataXSize, int dataYSize, boolean logTextIn)
{
  if (logTextIn) Log.d("RawTouches", "Line: " + dataIn);

  if (dataIn==null || dataIn.length()==0)
    return null; 

  int[] data = new int [dataXSize*dataYSize];
  String[] contents = split(dataIn, ","); 

  // process main data packet.
  if (contents.length==(dataXSize*dataYSize))
    {
      for (int i = 0; i<(dataXSize*dataYSize); i++)
      {
        try {
          data[i] = Integer.parseInt(contents[i]);
        }
        catch (NumberFormatException e) {
          if (logTextIn) Log.d("RawTouches", "Number format error at " + i);
          data[i] = 0; // just set to zero and continue.
        }
        catch (Exception e) { 
          if (logTextIn) Log.d("RawTouches", "Unknown error at " + i);
          return null;
        }
      }
    return data;
    }
  return null;
}



/*
 * Draw a raw touch packet - several different versiosn using global defaults or set vars
 */
void drawData(int data[])
  {drawData(data, showScreen, showMiniScreen, showTextMsgs, gridCellsX, gridCellsY, gridStartX, gridStartY, gridPixelsX, gridPixelsY);}

void drawData(int data[], boolean showScreenIn, boolean showMiniScreenIn, boolean showTextMsgsIn)
  {drawData(data, showScreenIn, showMiniScreenIn, showTextMsgsIn, gridCellsX, gridCellsY, gridStartX, gridStartY, gridPixelsX, gridPixelsY);}
 
// the data, to show the main screen, to show a mini screen, to output log text, whether we do rows->cols or cols->rows
void drawData(int data[], boolean showScreenIn, boolean showMiniScreenIn, boolean showTextMsgsIn,
             float gcX, float gcY, // the number of cells/sensors: (7x7) in SW3
             float gsX, float gsY, // the start cell to begin drawing: (0,0) in SW3 
             float gpX, float gpY) // the size of each cell: (320/7) in SW3 - screen size/number sensors
{  
  if (showTextMsgsIn) println("--"); 
    
  // total number of sensors. 
  int numberCells = (int)(gcX * gcY);
  
  // get start pos for the grid - this means we can handle non-zero starts (in case of phone areas)
  float xStart = gsX*gpX;
  float yStart = gsY*gpY;
  
  // make a mini display (for watch)
  float gpXMini  = gpX/MINI_SIZE_DIVISOR;
  float gpYMini  = gpY/MINI_SIZE_DIVISOR;

  // set total brightness to zero and start checking cells
  palmBrightness = 0; 
  for (int i=0; i<numberCells; i++)
  {
    // assumes first rows, then cols
    int xCell = i%(int)gcX; 
    int yCell = i/(int)gcX; 
    
    // adjustment to show lines on extreme right/bottom edges of screen
    float xSzTmp = gpX; 
    if (xCell==gcX-1)   
      xSzTmp--;
    float ySzTmp = gpY; 
    if (yCell==gcY-1) 
      ySzTmp--;

    // set and tally brightness.
    float col = data[i];
    palmBrightness += (int)col; 
    fill(col);
    
    if (showScreenIn)
    {
      stroke(255);     
      rect(xStart+xCell*gpX, yStart+yCell*gpY, xSzTmp, ySzTmp);
    }

    if (showMiniScreenIn)
    {
      stroke(128);
      rect(xStart+xCell*gpXMini, yStart+(yCell*gpYMini), gpXMini, gpYMini);
    }

    if (showTextMsgsIn)
    {
      print(data[i] + "\t"); 
      if ((i+1)%(gcX)==0)
        println();
    }
  }
  
  /*
   * Calculate the overall brightness for the palm down gesture.
   */
  palmBrightness /= numberCells;
}


/*
 * Draw the ellipses
 */
void drawEllipses(ArrayList<MomentsData> ellipses)
  {
  if (ellipses.size()>0)
    {
    noFill();
    stroke(255, 0, 0);
    for (int i=0;i<ellipses.size();i++)
      { 
      pushMatrix(); 
        MomentsData localMoment = ellipses.get(i);
        translate(gridPixelsX/2.0/MINI_SIZE_DIVISOR+(gridPixelsX*(float)localMoment.x)/MINI_SIZE_DIVISOR,
                  gridPixelsY/2.0/MINI_SIZE_DIVISOR+(gridPixelsY*(float)localMoment.y)/MINI_SIZE_DIVISOR);
        rotate((float)localMoment.theta);  
        ellipse(0, 0, gridPixelsX*(float)localMoment.l1/MINI_SIZE_DIVISOR, gridPixelsY*(float)localMoment.l2/MINI_SIZE_DIVISOR);
      popMatrix(); 
      }
    }
  }