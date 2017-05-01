/*
 * Simple watch face that also shows the remaining battery level
 * Compiled using Processing 3.2.3 and Android Mode 4.0 beta 3  
 */
 
import android.os.BatteryManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

IntentFilter ifilter;

PFont sml;
PFont lrg;

float batteryPct;
long last; 


void setup() {
  fullScreen();
  frameRate(1);
  sml = createFont("Roboto", 24);
  lrg = createFont("Roboto", 96);
  textFont(lrg);
  textAlign(CENTER, CENTER);
  fill(255);
  
  ifilter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
  last = millis() - 60000; 
  batteryPct = 0;
}

void draw() {
  background(0);
  
  //if (!ambientMode) 
  { 
    long now = millis(); 
    if (now-last>60000)
      {
      Intent batteryStatus = surface.getContext().registerReceiver(null, ifilter);
      int level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
      int scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
      batteryPct = level / (float)scale;
      last = now; 
      }
    
    textFont(sml);
    text((int)(batteryPct*100.0), width-30, 20);
    textFont(lrg);
      
    if (hour()<10)
      text("0"+hour(), width/2, height/3);
    else
      text(hour(), width/2, height/3);
    if (minute()<10)
      text("0"+minute(), width/2, height/3*2);
    else
      text(minute(), width/2, height/3*2);
  }
}