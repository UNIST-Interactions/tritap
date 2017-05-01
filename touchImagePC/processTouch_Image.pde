/*
 * Processes and draws touch packets. 
 */

/*
 * variable we store the touch image packets in
 */
String touchImageData;

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
int sensorMode = 0;        // the mapping mode we are using (basically different gamma corrections)


/*
 * The size (as a devisor of the large screen) of the mini display
 */
final float MINI_SIZE_DIVISOR  = 5.0;


/*
 * Initialize the touch image. 
 */
void initTouchImage()
  {
  /*
   * Finalize sensor size vars - this finalizes the sensor size in terms of display pixels
   * Must be cal'd in setup (after width/height are defined)
   */
  gridPixelsX = min(width, height)/(float)gridCellsX; 
  gridPixelsY = min(width, height)/(float)gridCellsY; 
  
  /*
   * Init local data stores for the touch/ellipses info
   */
  touchImageData = "";
  }



/* 
 * Process a packet of touch input data into an int array
 * dataIn should be <data0, data1,... dataN>.
 * dataN == dataXSize * dataYSize
 * Example:"0,0,0,0,15,0,1428,0,0,0,0,0,0,0,0,26,14,13,540,0,0,32,0,0,0,0,6,0,0,0,0,15,113,116,57,59,0,0,0,0,0,0,1301,1813,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,146,0,2,0,0,0,0,2,2,3,3,1,2,4,2,1,1,1,2,1,1,3,2,2,2,1,1,3,4,5,2,1,0,1,1,0,3,4,1,2,3,2,2,6,6,3,1,2,3,3,2,3,0,0,0,0,0,6,43,36,5,0,0,0,0,0,0,0,0,0,0,0,59,150,143,25,1,0,0,0,0,0,0,0,0,0,1,87,160,143,22,0,0,0,0,0,0,0,0,0,0,2,29,84,74,16,5,2,2,0,0,0,0,0,1,0,1,5,16,9,4,1,0,0,0,0,0,2,0,4,2,0,1,2,4,2,4,2,1,4,1,0";
 */
int[] interpretData(String dataIn, int dataXSize, int dataYSize)
{
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
          println("Integer parsing number format error at " +i); 
          data[i] = 0; // just set to zero and continue.
        }
        catch (Exception e) {
          println("Unknown error at " +i); 
          return null;
        }
      }
    return data;
    }
  return null;
}



/*
 * Draw a raw touch packet
 */
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

  // start checking cells
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

    // set brightness
    fill(constrain(data[i], 0, 255));
    
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
}