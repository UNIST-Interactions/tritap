package kr.ac.unist.interactions.touchimagemoments;

/*
 * Adapted for processing by Ian Oakley from 
 * https://github.com/dmlap/CS640-P1/tree/master/src
 */
 
import java.util.ArrayList;
import java.util.StringTokenizer;
import java.lang.String; 


public class ImageMoments 
{
// the power levels we will use in the calculations for modes POWER_L1, etc 
final float P_L1             = 3;  // for example this will result in pow(x, 3);
final float P_L2             = 5; 
final float P_L3             = 7; 

// the different image enhancement modes.
// image brightness needs be expressed in a 0-1 scale for these to work
public final static int NORM             = 0;
public final static int POWER_L1         = 1;
public final static int POWER_L2         = 2;
public final static int POWER_L3         = 3;
public final static int THRESH_POWER_L1  = 4;
public final static int THRESH_POWER_L2  = 5;
public final static int THRESH_POWER_L3  = 6;
public final static int LOG              = 7;

  ArrayList<MomentsData> moments;        // the moments. 
  
  int[][] img;                           // an array representing processed source data used to calc moments
  String imgSrc;						 // a string rep of the same
  
  
  // just init
  ImageMoments()
    {
    moments = new ArrayList<MomentsData>();
	img = null;
    imgSrc = null;
    }  
  
  
  // Or pass in data in a raw string
  ImageMoments(String s, int gridSize, int min, int max, int threshold, int mode)
    {
    moments = new ArrayList<MomentsData>(); 
    mapAndCalculateMoments(s, gridSize, min, max, threshold, mode);
    }  
  
  
  // calculate the moments
  void mapAndCalculateMoments(String s, int gridSize, int min, int max, int threshold, int mode)
    {
    img = new int[gridSize][gridSize]; 
    imgSrc = "";
    String[] parts = s.split(",");
    if (parts.length!=gridSize*gridSize)
      return;   
    for (int i=0;i<gridSize;i++)
      for (int j=0;j<gridSize;j++)
        {
        // maps to a 0, 255 range, according to one of a predetermined set of mappings
        try 
          {
          int val = Integer.parseInt(parts[j+i*gridSize]); 
          float v = (float)doMapping(val, min, max, threshold, mode);
          img[i][j] = (int)map(constrain(v,0,1), 0, 1, 0, 255); // needs be black contents on white
          imgSrc+=(255-img[i][j]); // flip the text rep back to white on black. Better for the SM screen
          if (!(i==gridSize-1 && j==gridSize-1))
          	 imgSrc+= ",";
          }
        catch (NumberFormatException e) {System.out.println("TouchImageMsg: Number format exception at " + (j+i*gridSize) + ". Data: " + s);}
        }
    calculateMoments(img);
    }
    
    
  // calulate all moments - intended as an internal funciton mainly  
  void calculateMoments(int[][] dataIn)
    {
    int[][] data = new int [dataIn.length][dataIn[0].length];        // work on a local copy of the data
    int[][] solo = new int [dataIn.length][dataIn[0].length];        // used to store individual flood fill regions
    boolean[][] checked = new boolean[data.length][data[0].length];  // keep tabs on what we already looked at  
    // init it all
    for (int row = 0; row < checked.length; row++) 
      for (int col = 0; col < checked[0].length; col++)
        {
        checked[row][col] = false;
        data[row][col]    = dataIn[row][col];
        }
        
    // clear prior
    moments.clear(); 
        
    for (int row = 0; row < data.length; row++) 
      {
      for (int col = 0; col < data[0].length; col++) 
        {
        // run a flood fill on point row, col in the image. returns number of pixels filled
        int changed = floodRecursive(data, checked, row, col); // TODO: implement non-recusive version
        if (changed>0) // we have filled something
          {  
          // look for moments on this data - all changed cells that still have non zero data
          for (int i=0;i<checked.length;i++)  
            {
            for (int j=0;j<checked[0].length;j++)
              {
              if (checked[i][j] && data[i][j]!=255)
                {
                solo[i][j] = data[i][j]; // copy into the solo data structure 
                data[i][j] = 255;        // and zero our data
                }
              else 
                solo[i][j] = 255;        // fill out the solo data structure
              }
            }
          
          // may want to exclude very small (e.g. 1 px) areas. Very unlikely to be touches.  
          MomentsData m = calculateOneMoment(solo);        // calculate moments based on the solo data structure.
          if (m!=null)
            moments.add(m);
          }
        }
      }
    }
     
      
  // calculate a single moment based on an array of ints
  // does do any mapping or segregation of regions.
  MomentsData calculateOneMoment(int[][] data)
    {    
    // Variables to store the first and second order moments.
    double m00, m01, m02, m10, m11, m20;  
    m00 = 0; m01 = 0; m02 = 0; m10 = 0; m11 = 0; m20 = 0;   
    
    MomentsData m = new MomentsData(); 
    
    // init output data
    m.x = 0; m.y = 0;
    m.theta = 0;
    m.l1 = 0; m.l2 = 0;  
      
    for (int w = 0; w < data.length; w++) 
      {
      for (int h = 0; h < data[w].length; h++) 
        {
        //color c = data[h][w];   
        //float intensity = (255-brightness(c)); // invert because the algrithm looks for black not white.
        float intensity = (255-data[h][w]); // invert because the algrithm looks for black not white.
        m00 += intensity;
        m10 += w * intensity;
        m01 += h * intensity;
        m11 += w * h * intensity;
        m20 += w * w * intensity;
        m02 += h * h * intensity;
        }
      }

    double _m00 = m00 == 0 ? 1 : m00;

    m.x = m10/_m00;
    m.y = m01/_m00;

    double a = (m20/_m00) - Math.pow(m.x, 2);
    double b = 2 * ((m11/_m00) - m.x*m.y);
    double c = (m02/_m00) - Math.pow(m.y, 2);

    double b2 = Math.pow(b, 2);
    double aMinusC = a - c;
    double aPlusC = a + c;
    m.theta = Math.atan2(b, (a-c)) / 2;

    double intermediate = Math.sqrt(b2 + Math.pow(aMinusC, 2));
    m.l1 = Math.sqrt(6 * (aPlusC + intermediate));
    m.l2 = Math.sqrt(6 * (aPlusC - intermediate));
    
    m.ecc = 1.0-(m.l2/m.l1); // not well tested. Looks right 
    
    if (m.x == 0 && m.y == 0 && m.theta == 0 && m.l1 == 0 && m.l2 == 0)
      return null;
    return m;
  }
  
  
  // perform mapping according to the specified image adjustment (gamma)
  double doMapping(int val, int min, int max, int threshold, int mode)
    {
    float v = constrain(map(val, min, max, 1, 0), 0, 1);   
    switch (mode)
      {
      case NORM             : return v;
      case POWER_L1         : return Math.pow(v, P_L1);
      case POWER_L2         : return Math.pow(v, P_L2);
      case POWER_L3         : return Math.pow(v, P_L3);
      case THRESH_POWER_L1  : if (val<threshold) return 255; return Math.pow(v, P_L1);
      case THRESH_POWER_L2  : if (val<threshold) return 255; return Math.pow(v, P_L2);
      case THRESH_POWER_L3  : if (val<threshold) return 255; return Math.pow(v, P_L3);
      case LOG              : if (val<threshold) return 255; return Math.log(1+v);
      }
    return val;
    }
    
    
  // recursive flood fill for getting separate touch regions
  int floodRecursive(int[][] img, boolean[][] mark, int row, int col)
    {
    // make sure row and col are inside the image
    if (row < 0) return 0 ;
    if (col < 0) return 0 ;
    // assumes sqaure image...
    if (row >= img.length) return 0 ;
    if (col >= img.length) return 0 ;
  
    // make sure this pixel hasn't been visited yet
    if (mark[col][row]) return 0 ;
  
    // make sure this pixel is the right color to fill
    if (img[col][row]>=255) return 0 ;
  
    // fill pixel with target color and mark it as visited
    mark[col][row] = true;
    int changed = 1; 
  
    // recursively fill surrounding pixels
    // (this is equivelant to depth-first search)
    changed += floodRecursive(img, mark, row - 1, col);
    changed += floodRecursive(img, mark, row + 1, col);
    changed += floodRecursive(img, mark, row, col - 1);
    changed += floodRecursive(img, mark, row, col + 1);
  
    return changed;
    }  
    
  
  // return a string of the mapped, adjusted data used to calculate the moments
  // this causes 
  String getMappedImgData() {
  	String s = "";
  	if (img!=null) // we have a valid array
  		{
	  	for (int i=0;i<img.length;i++)
	  		{ 
	  		if (img[i]!=null) // we have a valid row
	  			{
			  	for (int j=0;j<img[i].length;j++)  		
			  		{
		  			s+=img[i][j] + ","; //check for flip!
			  		}
			  	}
			else 
				return null;
		  	}
		}
	else 
		return null;
	
	// return the complete string....	
   	return s.substring(0, s.length()-1);
	}  
	 
    
  //copied from PApplet because I can't be bothered to figure out the referencing... 
  float constrain(float amt, float low, float high) {
    	return (amt < low) ? low : ((amt > high) ? high : amt);
	}
  
  float map(float value, float istart, float istop, float ostart, float ostop) {
		return ostart + (ostop - ostart) * ((value - istart) / (istop - istart));
	}
  
}