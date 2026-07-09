//+------------------------------------------------------------------+
//|                                                   SessionFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"
#include "..\Core\Session.mqh"

//+------------------------------------------------------------------+
//| Session Filter Rule                                             |
//+------------------------------------------------------------------+
// Validates that current time is within trading session
// Only trades during London, NY, or overlap sessions
//+------------------------------------------------------------------+

class CSessionFilter : public IRule
{
private:
   bool m_AllowLondon;
   bool m_AllowNY;
   bool m_AllowOverlap;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CSessionFilter(bool allowLondon = true, bool allowNY = true, bool allowOverlap = true)
   {
      this.m_AllowLondon = allowLondon;
      this.m_AllowNY = allowNY;
      this.m_AllowOverlap = allowOverlap;
   }
   
   //+------------------------------------------------------------------+
   //| Check if session rule passed                                   |
   //+------------------------------------------------------------------+
   bool Check()
   {
      int currentSession = g_TradeContext.Session;
      bool sessionActive = g_TradeContext.SessionActive;
      
      if (!sessionActive)
         return false;
      
      // Check if session is allowed
      bool allowed = false;
      
      if (this.m_AllowLondon && currentSession == 1)  // LONDON
         allowed = true;
      else if (this.m_AllowNY && currentSession == 2)  // NY
         allowed = true;
      else if (this.m_AllowOverlap && currentSession == 3)  // OVERLAP
         allowed = true;
      
      return allowed;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "SessionFilter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return 5.0;  // 5 points in confidence score
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      int currentSession = g_TradeContext.Session;
      bool sessionActive = g_TradeContext.SessionActive;
      
      if (!sessionActive)
         return "Outside trading hours - FAILED";
      
      string sessionName = "";
      switch (currentSession)
      {
         case 1: sessionName = "London"; break;
         case 2: sessionName = "New York"; break;
         case 3: sessionName = "Overlap"; break;
         default: sessionName = "Unknown";
      }
      
      if (sessionName == "Unknown")
         return "Invalid session - FAILED";
      
      return sessionName + " session active - PASSED";
   }
};

//+------------------------------------------------------------------+
//| Helper function to create session filter                        |
//+------------------------------------------------------------------+
CSessionFilter CreateSessionFilter(bool allowLondon = true, bool allowNY = true, bool allowOverlap = true)
{
   return CSessionFilter(allowLondon, allowNY, allowOverlap);
}
//+------------------------------------------------------------------+
