package kr.ac.unist.interactions.touchimagemoments;

public class MomentsData
  {
  public double x = 0, y = 0;           	   //Variables to store the centroid location.
  public double theta = 0.00;                  //Variable to store the orientation specified by the moments
  public double l1 = 0, l2 = 0;                //Variables to store the Length and Breadth of the rectangle specified by the moments - these are the eigenvalues
  public double ecc;                           //Variable to store the eccentricity
  
  MomentsData(){x=0;};
  }