/*
 * Various system and UI utilities to get the app to function. 
 */

//-------------------------------------------------------------------------------------

// Not included in this code base, but invovling xml changes, FYI:
// In order to disable leftswipe to dismiss, this line is required:
// <item name="android:windowSwipeToDismiss">false</item>
// Add it to the file <PROCESSING_PATH>/Processing/modes/AndroidMode/templates/StylesFragment.xml.tmpl

//-------------------------------------------------------------------------------------


/*
 * Includes and code to keep the screen always on. Call in setup
 */
import android.app.Activity;
import android.view.View;
import android.view.WindowManager;

void keepScreenOn() {
    surface.getActivity().runOnUiThread(new Runnable() {
      public void run() {
        surface.getActivity().getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
    });
}

//-------------------------------------------------------------------------------------

/*
 * Includes and code to get Wifi IP address. 
 * Android + OSX version is below
 * from : http://stackoverflow.com/questions/6064510/how-to-get-ip-address-of-the-device
 * works on my (single) osx install. Give two address on my (single) android test device
 * Get IP address from first non-localhost interface
 * @param ipv4  true=return ipv4, false=return ipv6
 * @return  address or empty string
 */
import java.net.NetworkInterface; 
import java.net.InetAddress;
import java.util.*;        // for collections - we shuffle the faces for randomisation
public static String getIPAddress(boolean useIPv4) 
{
  String totalAddresses = ""; 
  try {
    List<NetworkInterface> interfaces = Collections.list(NetworkInterface.getNetworkInterfaces());
    for (NetworkInterface intf : interfaces) {
      List<InetAddress> addrs = Collections.list(intf.getInetAddresses());
      for (InetAddress addr : addrs) {
        if (!addr.isLoopbackAddress()) {
          String sAddr = addr.getHostAddress();
          //boolean isIPv4 = InetAddressUtils.isIPv4Address(sAddr);
          boolean isIPv4 = sAddr.indexOf(':')<0;

          if (useIPv4) {
            // "mnet" is typically used as part of the mobile network adaptor not wifi. CHECK THIS ON YOUR DEVICE!
            if (isIPv4 && intf.getDisplayName().indexOf("mnet")==-1) 
              {
              if (totalAddresses.length()>0)
                totalAddresses += ", "; 
              totalAddresses += sAddr;// + "-" + intf.getDisplayName(); //return sAddr;
              }
          } else {
            if (!isIPv4) {
              int delim = sAddr.indexOf('%'); // drop ip6 zone suffix
              return delim<0 ? sAddr.toUpperCase() : sAddr.substring(0, delim).toUpperCase();
            }
          }
        }
      }
    }
  } 
  catch (Exception ex) {
  } // for now eat exceptions
  return totalAddresses;//"";
}  

//-------------------------------------------------------------------------------------

/* 
 * Inlcude and code to get the device battery level %
 */
import android.os.BatteryManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

IntentFilter batteryFilter;
float        batteryPercent;
long         batteryCheckTime; 

// call once, in setup
float initBattery() 
  {
  batteryFilter     = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
  batteryCheckTime  = millis() - 60001; 
  batteryPercent    = -1;
  return checkBattery();
  }

// call to get battery level
float checkBattery()
  {
  long now = millis(); 
  if (now-batteryCheckTime>60000) // only check once per minute...
    {
    Intent batteryStatus = surface.getContext().registerReceiver(null, batteryFilter);
    int level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
    int scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
    batteryPercent = (float)level / (float)scale;
    batteryCheckTime = now; 
    } 
  return batteryPercent;
  }