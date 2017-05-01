/*
 * Get a wifi ip address. Harder than it sounds. 
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
  