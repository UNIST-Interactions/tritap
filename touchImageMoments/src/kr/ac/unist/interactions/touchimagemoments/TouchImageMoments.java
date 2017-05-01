package kr.ac.unist.interactions.touchimagemoments;

/*
 * For whatever reason, when I compile processing libs for Android, I need use java 1.7
 * Odd as it works fine on PC (OSX). 
 * If I use java 1.8, I get this kind of error:
 ---
 BUILD FAILED
 /Users/ian/Library/Android/sdk/tools/ant/build.xml:888: The following error occurred while executing this line:
 /Users/ian/Library/Android/sdk/tools/ant/build.xml:890: The following error occurred while executing this line:
 /Users/ian/Library/Android/sdk/tools/ant/build.xml:902: The following error occurred while executing this line:
 /Users/ian/Library/Android/sdk/tools/ant/build.xml:283: null returned: 1 
 ---
 * so check your java version:
 java -version

 * and change it (assuming you have a single major version (1.7) installed. You may 
 * need adjust this command if you have a different set of installs. 
 export JAVA_HOME=`/usr/libexec/java_home -v 1.7`
 
 * if you need go back later, use 
 export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
 
 * Finally using java v7 (at least for me) gives a warning if I compile against recent 
 * (3.2.x) versions of processing
 Major version 52 is newer than 51, the highest major version supported by this compiler.
 It is recommended that the compiler be upgraded.
 * This doesn't seem to be serious, but compile against an older version of processing
 * if you don't want it - against 3.0.1 it works fine. 
 */

import java.lang.reflect.Method;
import java.io.RandomAccessFile; 
import java.io.IOException; 
import java.lang.NumberFormatException; 
import java.util.ArrayList;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.StringTokenizer;
import processing.core.*;

/**
 * Polls a proc file on an android phone for the raw touch image
 */
public class TouchImageMoments extends Thread
{
	PApplet myParent;
	public Method touchImageMethod;
	public Method touchEllipseMethod;
	public Method downEllipseMethod;
	public Method upEllipseMethod;
	private boolean running, logData, logging, toggleWait, sendEllipses, reportErrors;
	private String tagWait;
	private int procID;
	private String procFile; 
	
	private long startTime; 
	
	private String FILE_PREFIX = "/sdcard/study/";
	private PrintWriter logger;
	
	// params for sensor mapping
	int sensorThreshold;	// some gamma corrections use an additional threshold.
	int sensorMin;			// min val to use in mapping
	int sensorMax;			// max val to use in mapping
	int sensorMode; 		// sensor gamma correction mode
	
	// report the raw or gamma corrected img
	boolean reportRawData;

	// the total size of the sensor - the "original" size
	int xOrgSize;
	int yOrgSize; 
	
	// the start pos of the grid we care about
	int xStart; 
	int yStart; 
	
	// the size of the grid we care about
	int xSize;
	int ySize; 
	
	int lastpacketID; 
	int pauseCount;  // this is a measure of the time the kernel is waiting for the touchscreen buffer to fill up
					 // technically its in ms, but not actually - more like ms/2. 
					 
	int attemptsLeft = 5; // this is the number of times to try to find the proc file before giving up. 
						  // basically if we run the app on a kernel that doesn't include the proc file
						  // this will make sure we don't just endlessly keep looking for it...

	boolean printDebug = false;
	
	int packetRate = 0; // the number of packets we've read in the last second
	int packetFail = 0; // the number of packetID's we've skipped. zero is good, hard to interpret other results
	
	
	// the list of operators that manipulate the sensor grid arrangement
	final int OP_NONE	    = 0;
	final int OP_TRANSPOSE  = 1;
	final int OP_FLIPX 		= 2;
	final int OP_FLIPY 		= 3;
	ArrayList<Integer> operators; 
	
	
	ImageMoments moments;

	
	public TouchImageMoments(PApplet theParent, String procFileIn, boolean logData, String logPrefix) {
		myParent = theParent;
		myParent.registerMethod("dispose", this);
		
		startTime = System.currentTimeMillis();
		
		sendEllipses = false;
		reportErrors = false;
		
		// should be "/proc/touch_img_reporting"
		procFile = procFileIn;
		
		moments = new ImageMoments(); 
		
		System.out.println("TouchImageMsg: assigning 'void onTouchImage(String touchImage)' method");
		try { touchImageMethod = myParent.getClass().getMethod("onTouchImage", new Class[] { String.class });}
		catch (Exception e) 
		{ 
			System.out.println("TouchImageMsg: missing or wrong 'void onTouchImage(String touchImage)' method");
			touchImageMethod = null;
		}
		
		
		System.out.println("TouchImageMsg: assigning 'void onEllipse(ArrayList<MomentsData> m)' method");
		try { touchEllipseMethod = myParent.getClass().getMethod("onEllipse", new Class[] { ArrayList.class });}
		catch (Exception e) 
		{ 
			System.out.println("TouchImageMsg: missing or wrong 'void onEllipse(ArrayList<MomentsData> m)' method");
			touchEllipseMethod = null;
		}
		
		System.out.println("TouchImageMsg: assigning 'void downEllipse(ArrayList<MomentsData> m)' method");
		try { downEllipseMethod = myParent.getClass().getMethod("downEllipse", new Class[] { ArrayList.class });}
		catch (Exception e) 
		{ 
			System.out.println("TouchImageMsg: missing or wrong 'void downEllipse(ArrayList<MomentsData> m)' method");
			downEllipseMethod = null;
		}
		
		System.out.println("TouchImageMsg: assigning 'void upEllipse()' method");
		try { upEllipseMethod = myParent.getClass().getMethod("upEllipse");}
		catch (Exception e) 
		{ 
			System.out.println("TouchImageMsg: missing or wrong 'void upEllipse()' method");
			upEllipseMethod = null;
		}
		
		// init operators for changing the sensor config/arrangment
		operators = new ArrayList<Integer>();
		
		// config for nexus 5...
		//configThreshold(0,255,0, 255, 75); 
		//configSensor(7, 0, 15, 27, 10, 10); 
		// would also need to add transpose and then xflip I think. 
		
		// config for Sony SW3
		configThreshold(10, 255, 10, ImageMoments.NORM, true); 
		configSensor(0, 0, 7, 7, 7, 7);
		addOperator(OP_TRANSPOSE); 
				
		lastpacketID = -1;
		
		this.logData = logData;
        
        if (logData)
        {
        	String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(Calendar.getInstance().getTime());
        	
        	try
    		{
    			String fn = FILE_PREFIX + "Log_Touches_" + logPrefix + "_" + timeStamp + ".csv";
        		logger = new PrintWriter(fn, "UTF-8");
            	logger.println("@@@Starting_Logging: " + fn);
            	logger.flush();
            	logging = false;
				toggleWait = false;
				tagWait = ""; 
				System.out.println("TouchImageMsg: Successfully opened log file at " + fn);
    		}
    		catch (Exception e) { System.out.println("TouchImageMsg: Log file error: " + e); }						
        }
	}
	

	public void configThreshold(int minIn, int maxIn, int threshIn, int modeIn, boolean reportRawDataIn)
		{
		configThreshold(minIn, maxIn, threshIn, modeIn); 
		setUseRawData(reportRawDataIn);
		}

	public void configThreshold(int minIn, int maxIn, int threshIn, int modeIn)
		{
		sensorMin = minIn;
		sensorMax = maxIn;
		sensorThreshold = threshIn;
		sensorMode = modeIn;
		}	
		
	public void useRawData() 	{reportRawData = true;}	
	public void useMappedData() {reportRawData = false;}	
	public void toggleUseRawData() {reportRawData = !reportRawData;}
	public void setUseRawData(boolean in) {reportRawData = in;}	
	public boolean getUseRawData() {return reportRawData;}	
	
	
	
	public void configSensor(int _xOrgSize, int _yOrgSize, int _xStart, int _yStart, int _xSize, int _ySize)
		{
 		xOrgSize = _xOrgSize;
 		yOrgSize = _yOrgSize;
 		xStart   = _xStart;
 		yStart   = _yStart;
 		xSize    = _xSize;
 		ySize    = _ySize;
		}
		
		
	public void showErrors()
		{reportErrors = true;}
	public void hideErrors()
		{reportErrors = false;}
	
	/**
	 * Invoke method: onTouchImage
	 */
	public void touchImage(String s)
	{
		if (touchImageMethod != null)
		{
			try { touchImageMethod.invoke(myParent, new Object[] {s}); }
			catch (Exception e) {System.out.println("TouchImageMsg: Exception invoking onTouchImage");}
		}
	}
	
	
    /**
	 * Invoke method: onEllipse
	 */
	public void touchEllipse(ArrayList<MomentsData> m)
	{
		if (touchEllipseMethod != null)
		{
			try { touchEllipseMethod.invoke(myParent, new Object[] {m}); }
			catch (Exception e) {System.out.println("TouchImageMsg: Exception invoking onEllipse");}
		}
	}


    /**
	 * Invoke method: downEllipse
	 */
	public void downEllipse(ArrayList<MomentsData> m)
	{
		if (downEllipseMethod != null)
		{
			try { downEllipseMethod.invoke(myParent, new Object[] {m}); }
			catch (Exception e) {System.out.println("TouchImageMsg: Exception invoking downEllipse");}
		}
	}
	
	
    /**
	 * Invoke method: upEllipse
	 */
	public void upEllipse()
	{
		if (upEllipseMethod != null)
		{
			try { upEllipseMethod.invoke(myParent); }
			catch (Exception e) {System.out.println("TouchImageMsg: Exception invoking upEllipse");}
		}
	}
	
	
		
	/**
	 * Anything in here will be called automatically when the parent
	 * sketch shuts down. For instance, this might shut down a thread
	 * used by this library
	 */
	public void dispose() 
	{	
	}
	
	
   /**
     * Starts the thread that listens for touch messages in the proc file
     */
    public void start()
    {
        running = true;
        Thread.currentThread().setPriority(Thread.MAX_PRIORITY);
        super.start();
    }
    
    
    
    // pull out data about the packet update rate, reliability and timing
    public int getPacketRate()
    	{return packetRate;}
    public int getPacketFail()
    	{return packetFail;}
    public int getPauseCount()
    	{return pauseCount;}
    
    
    
    /**
     * Thread that listens for SmoothMovesDataStreams.
     * SmoothMovesDataStreams include the user's gaze/head information
     * and messages from the tracker hardware (e.g., device disconnected, pupil not visible)
     */
    public void run()
    {    
    RandomAccessFile reader;
    long time = System.currentTimeMillis() / 1000; // the current second
    long now; 
    int packetCounter = 0;
    
        try
        {       	
    	// init the action here 
            
            while (running)
            {
				try
				{
					reader = new RandomAccessFile(procFile, "r");
				  	String load = reader.readLine();
			      	if (load != null)
    				{
    					// note: need formatting of this message
						// 1,4:1,2,3,...,N
						// the split on :
						// first string split on , to get info, status data
						// second string split on , to get sensor values
						
						String[] parts = load.split(";");
						
						if (parts.length==2) // we have two pieces
							{
							String[] info = parts[0].split(",");
							
							int packetID = -1;
							if (info.length==2)
								{
								packetID = Integer.parseInt(info[0]);
								pauseCount = Integer.parseInt(info[1]);
								}
							else
								{
								// get the second int in the packet - this is a count of the number of pauses
								// we had to execute while waiting for the touch image buffer to fill
								// its in units of ~2ms and should be in the range 1-5 if things are going well
								// sometimes I see this at 13-15, which drops the update rate for the system
								// to 30z - very slow. I don't know why it varies
								// occurs with different runs on same kernel build - battery level?
								// However, I ran the watch till it ran out of juice and didn't see this...  
								pauseCount = -1;
								if (printDebug)
									System.out.println("TouchImageMsg: Failed to get info from \"" + parts[0] +"\"");
								}
									
								
							if (packetID != lastpacketID)
								{
								now = System.currentTimeMillis(); 
								if ((long)(now/1000) != (long)time)  // when we change second
									{
									time = now/1000; 		// update the current second
									packetRate = packetCounter; // store the packetCount
									packetCounter = 0; 		// blank the counter
									if (printDebug)
										System.out.println("TouchImageMsg: Update rate: " + packetRate);
									}
								packetCounter++; 	
							
								// check if we are skipping the counter
								if (!((lastpacketID+1 == packetID) || (lastpacketID==99 && packetID==0)))
									{
									if (printDebug) 
										System.out.println("TouchImageMsg: Packet ID Error: " + lastpacketID + " to " + packetID + ". Total: " + packetFail);
									packetFail++; 
									}
							
								lastpacketID = packetID; 
		
								
								// transform the sensor data into the desired sub-selection and arrangement
								// quite inefficient code....
								String finalData = selectData(parts[1], xOrgSize, yOrgSize, xStart, yStart, xSize, ySize, printDebug); 
								finalData = applyOperators(finalData, xSize, printDebug); 
						
								//System.out.println(finalData);
								if (logData && logging)
									{
									if (toggleWait)
										{
										logger.println(tagWait); 
										toggleWait = false;
										}
									// we say final, but this is the raw data....	
									logger.println((System.currentTimeMillis()-startTime) + "," + packetID + "," + pauseCount + "," + finalData);
									}
							
								// if we are reporting ellipses, or not raw data
		//						if (touchEllipseMethod!=null || !reportRawData)
								moments.mapAndCalculateMoments(finalData, xSize, sensorMin, sensorMax, sensorThreshold, sensorMode);
							
								// send the touch img data - either raw or mapped. 
								if (touchImageMethod!=null)
									{
									// we want mapped data and we are reporting ellipses....
									if (reportRawData)
										touchImage(packetID+";"+finalData);
									else 
										touchImage(packetID+";"+moments.imgSrc);								
									}
								
								// send the ellipses		
								// many limitations to this up/down processing
								// it will pass all info, but basically, it operates on a single touch model; doesn't scale well.	
								if (touchEllipseMethod!=null)
									{								
									if (moments.moments!=null && moments.moments.size()>0)
										{
										if (!sendEllipses && downEllipseMethod!=null)
											{
											//System.out.println("DOWN: " + ellipses.size());
											sendEllipses = true; 	
											downEllipse(moments.moments);
											}
										else if (touchEllipseMethod!=null)
											{
											//System.out.println("ONGOING: " + ellipses.size());
											touchEllipse(moments.moments);									
											}
										}
									else // ellipses==null or ellipses.size()==0
										{
										//System.out.println("NONE");
										if (sendEllipses && upEllipseMethod!=null)
											{
											sendEllipses = false;
											//System.out.println("UP");
											upEllipse(); 
											}
										}
									}	
								}
							}
    				}
			    	reader.close();
			    	this.sleep(1); // wait for 1ms - remove for faster speed?
				}
			  catch (IOException ex)
			  {
			  		System.out.println("TouchImageMsg: Run loop IOException - most likely you don't have the raw touch image kernel installed!");
			  		System.out.println("TouchImageMsg: Will try " + attemptsLeft + " more times....");
			  		attemptsLeft--; 
					ex.printStackTrace();
					if (attemptsLeft<=0)
						{
				  		System.out.println("TouchImageMsg: Halting thread.");						
						running = false; 
						}
			  }
			  catch (InterruptedException ex)
			  {
					System.out.println("TouchImageMsg: Run loop InterruptedException");
					ex.printStackTrace();
			  }
			  catch (ArrayIndexOutOfBoundsException ex)
			  {
					System.out.println("TouchImageMsg: Run loop ArrayIndexOutOfBoundsException");
					ex.printStackTrace();
			  }
			  catch (Exception ex)
			  {
					System.out.println("TouchImageMsg: Run loop unknown exception");
					ex.printStackTrace();
			  }
			
            }
		
    	return;
        }
        catch (Exception ex) 
        	{ 
        	System.out.println("TouchImageMsg: Thread exiting with exception " + ex);
        	ex.printStackTrace(); 
        	}
    }
   
    
   public void startLogging(String tag)
   	{
   	tagWait = "###START, " + tag;
   	toggleWait = true;
	logging = true;
   	} 

   public void stopLogging(String tag)
   	{
	logging = false;
	logger.println("###STOP, " + tag);
   	logger.flush(); 
   	} 

   	
   public void stopLogging()
   	{
	logging = false;
   	logger.flush(); 
   	} 
    
    
   /**
     * Executed automatically when the Processing sketch is closed.
     */
    public void terminate()
    {
		System.out.println("TouchImageMsg: Closing library");
    	if (logData && logger!=null) 
    		{
			System.out.println("TouchImageMsg: Flushing logfile");    		
    		logger.flush();
    		logger.close();
    		logData = false; 
    		}
		System.out.println("TouchImageMsg: Terminating thread");
    	running = false;
    }
    
    
    
    /*
     * Functions to manipulate the sensor data grid
     * Select a sub-region and rearrange its axes
     * This is because we want x across our sensor and y down our sensor (not always true)
     * We can also tun devices so "top left" is odd place - like with the nexus. 
     */
     
    /*
	 * selectData
	 * we get a string of csv data. 
	 * it represents a 2D table of length xOrgSize, yOrgSize. 
	 * we want to create an output string containing a subset rect of
	 * xStart, yStart, xSize, ySize.
	 */
	String selectData(String dataIn, int xOrgSize, int yOrgSize, int xStart, int yStart, int xSize, int ySize, boolean report)
	  {
	  String[] sep = dataIn.split(",");
	  String finalData = "";
			  
	  // create the correct string seq based on the size params
	  // basically, create a window of touch points to look at
	  int sPos = (xOrgSize*yStart) + xStart;               // all full rows before yStart + xStart offset
	  int ePos = (xOrgSize*(yStart+ySize-1)) + xStart + xSize; // all full rows until  yStart + xStart + xSize offset
	  if (ePos>sep.length)
		{
		if (report) 
		  System.out.println("TouchImageMsg: Not enough touch pixels for requested grid. There are " + sep.length + " and you want " + ePos + ". Raw: " + dataIn);
		}
	  else if (report)
		System.out.println("TouchImageMsg: Extra touch pixels - could be ok. There are " + sep.length + " and you need " + ePos + "(from " + sPos+ "). Raw: " + dataIn);
	
	  for (int i=sPos;i<ePos;i++)
		if (i%xOrgSize>=xStart &&        // cond for start x in each row
			i%xOrgSize<xStart+xSize &&   // cond for end x in each row
			i/xOrgSize<yStart+ySize)     // cond for end y (start y already handled in sPos)
		  {
		  if (i<sep.length)
			finalData += sep[i]+",";     // validate sep[i] - basically make it an int, if not possible, put in a default value 
		  else 
			finalData += "-255,"; // add missing impossible vals to cope with errors
		  }
	  finalData = finalData.substring(0, finalData.length()-1); // delete last comma. 
	  return finalData;
	  }

	// functions to manage the operator list
	void clearOperators() 
		{operators.clear();}
	void addOperator(int op) 
		{operators.add((Integer)op);}
	
	// functions to apply different operators (from the operators array) to the sensor cell arrangement. 
	String applyOperator(String dataIn, int operator, int w, boolean report)
		{
		switch (operator)
			{
			case OP_TRANSPOSE: 	return transpose(dataIn, w, report);
			case OP_FLIPX: 		return flipX	(dataIn, w, report);
			case OP_FLIPY: 		return flipY	(dataIn, w, report);
			}
		return dataIn; // default. 
		}
	String applyOperators(String dataIn, int w, boolean report)
		{
		for (int i=0;i<operators.size();i++)
			dataIn = applyOperator(dataIn, (int)operators.get(i), w, report); 
		return dataIn; 
		}

	// Transposes the grid
	String transpose(String dataIn, int w, boolean report)
	  {
	  String[] sep = dataIn.split(",");
	  String finalData = "";
  
	  if (sep.length%w!=0 && report)
		System.out.println("TouchImageMsg: Cannot transpose - wierd length"); 
  
	  int h = sep.length/w;
	  for (int i=0;i<w;i++)
		for (int j=0;j<h;j++)
		  finalData += sep[j*w+i]+",";    

	  finalData = finalData.substring(0, finalData.length()-1); // delete last comma.
	  return finalData; 
	  }
  
  
	// Flips the grid in X
	String flipX(String dataIn, int w, boolean report)
	  {
	  String[] sep = dataIn.split(",");
	  String finalData = "";
  
	  if (sep.length%w!=0 && report)
		System.out.println("TouchImageMsg: Cannot flipX - wierd length"); 
  
	  int h = sep.length/w;
	  for (int i=0;i<h;i++)
		for (int j=0;j<w;j++)
		  finalData += sep[i*w+(w-j-1)]+",";    

	  finalData = finalData.substring(0, finalData.length()-1); // delete last comma.
	  return finalData; 
	  }  
  

	// Flips the grid in Y
	String flipY(String dataIn, int w, boolean report)
	  {
	  String[] sep = dataIn.split(",");
	  String finalData = "";
  
	  if (sep.length%w!=0 && report)
		System.out.println("TouchImageMsg: Cannot flipY - wierd length"); 
  
	  int h = sep.length/w;
	  for (int i=0;i<h;i++)
		for (int j=0;j<w;j++)
		  finalData += sep[(h-i-1)*w+j]+",";    

	  finalData = finalData.substring(0, finalData.length()-1); // delete last comma.
	  return finalData; 
	  }  
    

	void printSpaced(int i) {
		if (i<10) System.out.print("  ");
		else if (i<100) System.out.print(" ");
  		System.out.print(i + " ");
	}
	
}