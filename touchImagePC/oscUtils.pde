import oscP5.*;
import netP5.*;
  
OscP5 oscP5;
NetAddress remoteLoc = null;

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



/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) 
  {
  if(theOscMessage.checkAddrPattern(SEARCH_HOST)==true)
    {
    println("IP address received! " + theOscMessage.get(0).stringValue());
    String[] s = split(theOscMessage.get(0).stringValue(), ",");
    remoteLoc = new NetAddress(s[0], WATCH_PORT); // use first address...
    OscMessage msg = new OscMessage(FOUND_HOST);
    oscP5.send(msg, remoteLoc); // send handshake.
    }
  else if (theOscMessage.checkAddrPattern(SEND_DEBUG)==true)
    {
    println(theOscMessage.addrPattern());
    println(theOscMessage.get(0).stringValue());
    String[] part = split(theOscMessage.get(0).stringValue(), ",");
    if (part.length>=5)
      debugStatus = "Rate: " + part[0] + ", " + 
                    "Fail: " + part[1] + ", " +
                    "Time: " + part[2] + ", " +
                    "Wait: " + part[3] + ", " +
                    "Power: "+ part[4]; 
    }
  else if (theOscMessage.checkAddrPattern(ACK_HOST)==true)
    println("Ack rec'd. Connected to watch!");
  else if (theOscMessage.checkAddrPattern(DATA_PACKET)==true)
    touchImageData = theOscMessage.get(0).stringValue();
  }