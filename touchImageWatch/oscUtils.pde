/*
 * Functions to handle networking - OSC messaging protocols to a host app
 */
 
/*
 * Lib import and object vars
 */
import netP5.*;
import oscP5.*;
OscP5 oscP5;
NetAddress remoteLoc;


/*
 * Network state vars
 */
boolean oscOn;         // we are looking for a receiver 
boolean oscRecd;       // we have recevied a handshake packet from a receiver. 
boolean oscStreamData; // are we streaming touch data or not 

/*
 * Vars used to send periodic test packets to establish a connection with a receiver
 */
long oscSentTime;      // last time 
final long OSC_WAIT_TIME = 5000;

/*
 * OSC Ports
 */
final int WATCH_PORT = 12345; 
final int HOST_PORT  = 1234; 
 

/*
 * OSC Message codes
 */
final String DATA_PACKET           = "/data";                  // SEND: sensor data packet
final String SEARCH_HOST           = "/searchHost";            // SEND: looking for a partner PC
final String FOUND_HOST            = "/foundHost";             // RECV: response from a partner PC
final String ACK_HOST              = "/ackHost";               // SEND: handshake to acknowledge partner PC is found
final String REQUEST_DEBUG         = "/requestDebug";          // RECV: request for debug info packet
final String SEND_DEBUG            = "/sendDebug";             // SEND: send the debug info packet
final String TOGGLE_DATA_STREAMING = "/toggleDataStreaming";   // RECV: toggle sensor data streaming over OSC
final String TOGGLE_RAW_DATA       = "/toggleRawData";         // RECV: toggle between streaming raw and mapped data
final String TOGGLE_DEBUG          = "/toggleDebug";           // RECV: toggle between debug and regular modes 
final String SET_FRAME_RATE        = "/setFrameRate";          // RECV: set the processing frame rate
final String SET_SENSOR_MAPPINGS   = "/setMappings";           // RECV: update the sensor mappings (min, max, thresh and mode). 

/*
 * Main function to handle events we receive
 */
void oscEvent(OscMessage theOscMessage) {  
  // signifies a response to our query packet
  if (theOscMessage.checkAddrPattern(FOUND_HOST)==true) 
  {
    if (showSketchData) Log.d(FOUND_HOST, "Host sucessfully located.");
    oscRecd = true; 
    OscMessage msg = new OscMessage(ACK_HOST);
    oscP5.send(msg, remoteLoc); // send a hello packet - at this point should be connected.
  }
  
  // requests to send some debug info
  else if (theOscMessage.checkAddrPattern(REQUEST_DEBUG)==true) 
  {
    if (showSketchData) Log.d(REQUEST_DEBUG, "-");
    OscMessage msg = new OscMessage(SEND_DEBUG);
    msg.add(
            tImage.getPacketRate() + "," + // current packet received rate
            tImage.getPacketFail() + "," + // number of dead packets
            ((int)(millis()/1000)) + "," + // the uptime (in seconds)
            tImage.getPauseCount() + "," + // estimage of buffer clear time for the touch screen debug mode. This varies a lot :-(
                                           // actual data is the number of times we pause for (approx) 1ms while waiting for the buffer to fill
            (int)(checkBattery()*100)      // the battery level in %
            );                        
    oscP5.send(msg, remoteLoc); 
  }
  
  // requests to enable/disable data streaming
  else if (theOscMessage.checkAddrPattern(TOGGLE_DATA_STREAMING)==true) 
  {
    if (showSketchData) Log.d(TOGGLE_DATA_STREAMING, "-");
    oscStreamData = !oscStreamData; 
  }
  
  // switch between raw and mapped data streaming
  else if (theOscMessage.checkAddrPattern(TOGGLE_RAW_DATA)==true) 
  {
    if (showSketchData) Log.d(TOGGLE_RAW_DATA, "-");
    tImage.toggleUseRawData(); 
  }
  
  // requests to show/hide some debug info
  else if (theOscMessage.checkAddrPattern(TOGGLE_DEBUG)==true) 
  {
    if (showSketchData) Log.d(TOGGLE_DEBUG, "-");
    debugMode = !debugMode; 
  }
  
  // setting the framerate
  else if (theOscMessage.checkAddrPattern(SET_FRAME_RATE)==true) 
  {
    if (showSketchData) Log.d(SET_FRAME_RATE, "Setting frame rate to "+theOscMessage.get(0).stringValue());
    int fr = -1;
    try {fr = Integer.parseInt(theOscMessage.get(0).stringValue());}
    catch (Exception e) {if (showSketchData) Log.d(SET_FRAME_RATE, "Failed to get a valid int for the framerate");}
    
    if (fr>0 && fr<=60) // range
      frameRate(fr);
    else if (showSketchData) 
      Log.d(SET_FRAME_RATE, "Framerate (" +fr+ ") out of bounds (1-60)");
  }
  
  // setting the sensor mappings
  else if (theOscMessage.checkAddrPattern(SET_SENSOR_MAPPINGS)==true) 
    {
    if (showSketchData) Log.d(SET_SENSOR_MAPPINGS, "Mappings are: "+theOscMessage.get(0).stringValue());
    
    String[] s = split(theOscMessage.get(0).stringValue(), ",");
    int min =-1;
    int max =-1;
    int thresh =-1;
    int mode =-1;
    if (s.length==4)
      {
      try {
        min     = Integer.parseInt(s[0]);
        max     = Integer.parseInt(s[1]);
        thresh  = Integer.parseInt(s[2]);
        mode    = Integer.parseInt(s[3]);
        }
      catch (Exception e) {if (showSketchData) Log.d(SET_SENSOR_MAPPINGS, "Failed to get a valid int for the mappings");}
      }
    else 
      if (showSketchData) Log.d(SET_SENSOR_MAPPINGS, "Too few data for mappings: "+theOscMessage.get(0).stringValue());
    
    if ((min>=0   && min<max)     && // range for min
        (max>min  && max<=255)    && // range for max
        (thresh>0 && thresh<=255) && // range for thresh
        (mode>=0  && mode<=7))       // range for mode (normal to log)
        {
        sensorMin       = min; 
        sensorMax       = max;
        sensorThreshold = thresh;
        sensorMode      = mode;
        tImage.configThreshold(sensorMin, sensorMax, sensorThreshold, sensorMode);
        if (showSketchData) Log.d(SET_SENSOR_MAPPINGS, "Mappings set.");  
        }
    else 
      if (showSketchData) Log.d(SET_SENSOR_MAPPINGS, "Mappings settings out of bounds.");
    }
  
}  


/*
 * Look for command line arg specifying ip of partner for OSC messages
 */
void initOSC(PSurface surface)
{
  String inString = surface.getActivity().getIntent().getStringExtra(PARAM_IP_ADDRESS);
  if (inString == null)
    inString = "-"; // no ip address, so don't try to send messages
  else
  {
    /* 
     * Start oscP5, listening for incoming messages at port WATCH_PORT
     * and set receiver to be ip address in the parameter and HOST_PORT 
     */
    oscP5   = new OscP5(this, WATCH_PORT);           
    remoteLoc = new NetAddress(inString, HOST_PORT); 
    
    /*
     * Setup basic connection properties
     */
    oscOn   = true;             // we're looking for OSC packets 
    oscRecd = false;            // we have not received a start packet. 
    oscStreamData = true;       // by default, we will stream the data.
    oscSentTime =-OSC_WAIT_TIME;// we have not yet checked for a packet
    checkOSC();                 // Send first test packet to look for a receiver
  }
}



/*
 * if we received an ip in the command line, try to connect to a receiver periodically
 */
void checkOSC()
{
  if (oscOn && !oscRecd && millis()-oscSentTime>=OSC_WAIT_TIME)
  {
    oscSentTime = millis(); // we sent a test packet at this time
    OscMessage msg = new OscMessage(SEARCH_HOST);
    msg.add(getIPAddress(true));
    oscP5.send(msg, remoteLoc); // send the test packet
  }
}


/*
 * General loop to deal with OSC. If we know we are connected to a receiver, send data 
 * If not connected, send a packet to check for a connection from time to time.  
 */
void sendOSC()
{ 
  if (oscRecd)
  {
    if (oscStreamData)
      {
      OscMessage msg = new OscMessage(DATA_PACKET);
      msg.add(touchImageData);
      msg.add(gridSizeX);
      msg.add(gridSizeY);
      oscP5.send(msg, remoteLoc); // send a hello packet - at this point should be connected.
      }
  }
  else 
    checkOSC();
}