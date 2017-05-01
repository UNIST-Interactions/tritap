/*
 * UI (such as it is) code
 */
 
 
/*
 * Imports and base class
 */
import controlP5.*;
ControlP5 cp5;


/*
 * Init, place and configure all the widgets
 */
void initUI()
  {  
  textSize(14);                // set text size  
  cp5 = new ControlP5(this);   // init object  
  
  // size/spacing params
  int s = 15;
  int w = 70;
  int g = 30;
  
  cp5.addButton("Start_App")
     .setPosition(s, height-190)
     .setSize(w,20)
     ;  
     
  cp5.addButton("Stop_App")
     .setPosition(s, height-155)
     .setSize(w,20)
     ;    
    
  cp5.addButton("Toggle_Debug")
     .setPosition(s+w+g, height-190)
     .setSize(w,20)
     ;  
     
  cp5.addButton("Get_Debug")
     .setPosition(s+w+g, height-155)
     .setSize(w,20)
     ;     
     
  cp5.addButton("Toggle_Data")
     .setPosition(s+w*2+g*2, height-190)
     .setSize(w,20)
     ;           
     
  cp5.addButton("Toggle_Raw")
     .setPosition(s+w*2+g*2, height-155)
     .setSize(w,20)
     ;           
     
  cp5.addButton("Set_Frame_Rate")
     .setPosition(s+w*3+g*3,height-190)
     .setSize(w,20)
     ;
     
  cp5.addTextfield("Frame_Rate")
     .setPosition(s+w*3+g*3,height-155)
     .setSize(w,20)
     .setFont(createFont("arial",14))
     .setAutoClear(false)
     .setInputFilter(ControlP5.INTEGER)
     .setText("15")
     .getCaptionLabel().setVisible(false)
     ;   
     
    // lower bound for sensor data - 0 includes all
    cp5.addTextfield("Min")
     .setPosition(s+w*0+g*0,height-90)
     .setSize(w,20)
     .setFont(createFont("arial",14))
     .setAutoClear(false)
     .setInputFilter(ControlP5.INTEGER)
     .setText(((Integer)sensorMin).toString())
     ;
     
    // upper bound for sensor data - cap it here 
    cp5.addTextfield("Max")
     .setPosition(s+w*1+g*1,height-90)
     .setSize(w,20)
     .setFont(createFont("arial",14))
     .setAutoClear(false)
     .setInputFilter(ControlP5.INTEGER)
     .setText(((Integer)sensorMax).toString())
     ;
     
    // lower includes more data 
    cp5.addTextfield("Thresh")
     .setPosition(s+w*2+g*2,height-90)
     .setSize(w,20)
     .setFont(createFont("arial",14))
     .setAutoClear(false)
     .setInputFilter(ControlP5.INTEGER)
     .setText(((Integer)sensorThreshold).toString())
     ;
    
    // can be 0-7
    cp5.addTextfield("Mode")
     .setPosition(s+w*3+g*3,height-90)
     .setSize(w,20)
     .setFont(createFont("arial",14))
     .setAutoClear(false)
     .setInputFilter(ControlP5.INTEGER)
     .setText(((Integer)sensorMode).toString())
     ;
     
   cp5.addButton("Set_Mappings")
     .setPosition(width/2-w/2, height-35)
     .setSize(w,20)
     ;         
  }
  

/*
 * event functions
 */
public void Toggle_Debug(int theValue) {
  println("Toggling debug mode");
  if (remoteLoc!=null)
    {
    OscMessage msg = new OscMessage(TOGGLE_DEBUG);
    oscP5.send(msg, remoteLoc);
    }
}

public void Get_Debug(int theValue) {
  println("Requesting debug info");
  if (remoteLoc!=null)
    {
    OscMessage msg = new OscMessage(REQUEST_DEBUG);
    oscP5.send(msg, remoteLoc);
    }
}

public void Toggle_Data(int theValue) {
  println("Toggle Data Streaming");
  if (remoteLoc!=null)
    {
    OscMessage msg = new OscMessage(TOGGLE_DATA_STREAMING);
    oscP5.send(msg, remoteLoc);
    }
}

public void Toggle_Raw(int theValue) {
  println("Toggle raw touch img reporting");
  if (remoteLoc!=null)
    {
    OscMessage msg = new OscMessage(TOGGLE_RAW_DATA);
    oscP5.send(msg, remoteLoc);
    }
}
  
public void Set_Mappings(int theValue) {
  if (remoteLoc!=null)
    {
    OscMessage msg = new OscMessage(SET_SENSOR_MAPPINGS);
    String s = cp5.get(Textfield.class,"Min").getText() + "," +
               cp5.get(Textfield.class,"Max").getText() + "," +
               cp5.get(Textfield.class,"Thresh").getText() + "," +
               cp5.get(Textfield.class,"Mode").getText();
    msg.add(s);
    println("Setting Mappings as " + s);
    oscP5.send(msg, remoteLoc);
    }
}

public void Set_Frame_Rate(int theValue) {
  println("Setting frame rate");
  if (remoteLoc!=null)
    {
    OscMessage msg = new OscMessage(SET_FRAME_RATE);
    msg.add(cp5.get(Textfield.class,"Frame_Rate").getText());
    oscP5.send(msg, remoteLoc);
    }
}
  
public void Start_App(int theValue) {
  println("Start watch app");
  String ip = getIPAddress(true);
  
  String arg = "am start -a android.intent.action.VIEW -n " + WatchAppName + "/.MainActivity" + " -e" + " ip " + ip;
  try {new ProcessBuilder(adbPath, "shell", arg).start();}
  catch (IOException E) {println("Die on app start");}
}
    
public void Stop_App(int theValue) {
  println("Stopping watch app");
  remoteLoc = null;
  
  String arg = "am force-stop " + WatchAppName;
  try {new ProcessBuilder(adbPath, "shell", arg).start();}
  catch (IOException E) {println("Die on app stop");}   
}


    