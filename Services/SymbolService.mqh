//+------------------------------------------------------------------+
//|                                                   SymbolService.mqh |
//|                        XAU SMC Scalper Pro - Services Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <stderror.mqh>

//+------------------------------------------------------------------+
//| Symbol Service Interface                                        |
//+------------------------------------------------------------------+
class ISymbolService
{
public:
   virtual double GetSymbolSpread() = 0;
   virtual double GetSymbolPoint() = 0;
   virtual double GetSymbolTickSize() = 0;
   virtual double GetSymbolTickValue() = 0;
   virtual double GetSymbolMarginRequired(double lotSize) = 0;
   virtual double GetSymbolSwapLong() = 0;
   virtual double GetSymbolSwapShort() = 0;
   virtual bool IsSymbolValid() = 0;
   virtual bool IsSymbolTradeAllowed() = 0;
   virtual int GetSymbolDigits() = 0;
   virtual double NormalizePrice(double price) = 0;
   virtual double NormalizeLot(double lotSize) = 0;
   virtual double GetMinLot() = 0;
   virtual double GetMaxLot() = 0;
   virtual double GetLotStep() = 0;
   
   virtual ~ISymbolService() {}
};

//+------------------------------------------------------------------+
//| Default Symbol Service Implementation                           |
//+------------------------------------------------------------------+
class CDefaultSymbolService : public ISymbolService
{
private:
   string m_Symbol;
   double m_Point;
   double m_TickSize;
   double m_TickValue;
   int m_Digits;
   double m_MinLot;
   double m_MaxLot;
   double m_LotStep;
   bool m_IsValid;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CDefaultSymbolService(string symbol = "")
   {
      this.m_Symbol = (symbol == "") ? _Symbol : symbol;
      this.m_Point = 0.0;
      this.m_TickSize = 0.0;
      this.m_TickValue = 0.0;
      this.m_Digits = 0;
      this.m_MinLot = 0.01;
      this.m_MaxLot = 100.0;
      this.m_LotStep = 0.01;
      this.m_IsValid = false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize symbol service                                      |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // Get symbol info
      if (!SymbolInfo(this.m_Symbol))
         return false;
      
      this.m_IsValid = true;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol info                                                |
   //+------------------------------------------------------------------+
   bool SymbolInfo(string symbol)
   {
      // Point
      this.m_Point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if (this.m_Point <= 0)
         return false;
      
      // Digits
      this.m_Digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if (this.m_Digits <= 0)
         return false;
      
      // Tick size
      this.m_TickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if (this.m_TickSize <= 0)
         this.m_TickSize = this.m_Point;
      
      // Tick value
      this.m_TickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if (this.m_TickValue <= 0)
         this.m_TickValue = this.m_Point;
      
      // Lot sizes
      this.m_MinLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      this.m_MaxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      this.m_LotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get current spread                                             |
   //+------------------------------------------------------------------+
   double GetSymbolSpread()
   {
      return SymbolInfoDouble(this.m_Symbol, SYMBOL_SPREAD);
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol point                                               |
   //+------------------------------------------------------------------+
   double GetSymbolPoint()
   {
      return this.m_Point;
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol tick size                                           |
   //+------------------------------------------------------------------+
   double GetSymbolTickSize()
   {
      return this.m_TickSize;
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol tick value                                          |
   //+------------------------------------------------------------------+
   double GetSymbolTickValue()
   {
      return this.m_TickValue;
   }
   
   //+------------------------------------------------------------------+
   //| Get margin required for position                              |
   //+------------------------------------------------------------------+
   double GetSymbolMarginRequired(double lotSize)
   {
      return SymbolInfoDouble(this.m_Symbol, SYMBOL_MARGIN_REQUIRED) * lotSize;
   }
   
   //+------------------------------------------------------------------+
   //| Get swap long                                                  |
   //+------------------------------------------------------------------+
   double GetSymbolSwapLong()
   {
      return SymbolInfoDouble(this.m_Symbol, SYMBOL_SWAP_LONG);
   }
   
   //+------------------------------------------------------------------+
   //| Get swap short                                                 |
   //+------------------------------------------------------------------+
   double GetSymbolSwapShort()
   {
      return SymbolInfoDouble(this.m_Symbol, SYMBOL_SWAP_SHORT);
   }
   
   //+------------------------------------------------------------------+
   //| Check if symbol is valid                                       |
   //+------------------------------------------------------------------+
   bool IsSymbolValid()
   {
      return this.m_IsValid;
   }
   
   //+------------------------------------------------------------------+
   //| Check if symbol trade allowed                                  |
   //+------------------------------------------------------------------+
   bool IsSymbolTradeAllowed()
   {
      if (!this.m_IsValid)
         return false;
      
      long flags = SymbolInfoInteger(this.m_Symbol, SYMBOL_TRADE_CALC_MODE);
      return (flags != SYMBOL_TRADE_MODE_DISABLED);
   }
   
   //+------------------------------------------------------------------+
   //| Get symbol digits                                              |
   //+------------------------------------------------------------------+
   int GetSymbolDigits()
   {
      return this.m_Digits;
   }
   
   //+------------------------------------------------------------------+
   //| Normalize price to symbol digits                              |
   //+------------------------------------------------------------------+
   double NormalizePrice(double price)
   {
      return MathRound(price / this.m_Point) * this.m_Point;
   }
   
   //+------------------------------------------------------------------+
   //| Normalize lot size to symbol requirements                     |
   //+------------------------------------------------------------------+
   double NormalizeLot(double lotSize)
   {
      // Round to lot step
      double normalized = MathRound(lotSize / this.m_LotStep) * this.m_LotStep;
      
      // Clamp to min/max
      normalized = MathMax(this.m_MinLot, MathMin(this.m_MaxLot, normalized));
      
      return normalized;
   }
   
   //+------------------------------------------------------------------+
   //| Get minimum lot size                                           |
   //+------------------------------------------------------------------+
   double GetMinLot()
   {
      return this.m_MinLot;
   }
   
   //+------------------------------------------------------------------+
   //| Get maximum lot size                                           |
   //+------------------------------------------------------------------+
   double GetMaxLot()
   {
      return this.m_MaxLot;
   }
   
   //+------------------------------------------------------------------+
   //| Get lot step                                                   |
   //+------------------------------------------------------------------+
   double GetLotStep()
   {
      return this.m_LotStep;
   }
};

//+------------------------------------------------------------------+
//| Global Symbol Service Instance                                  |
//+------------------------------------------------------------------+
CDefaultSymbolService g_SymbolService;

//+------------------------------------------------------------------+
//| Initialize symbol service                                       |
//+------------------------------------------------------------------+
bool InitializeSymbolService()
{
   return g_SymbolService.Initialize();
}

//+------------------------------------------------------------------+
//| Get spread (wrapper)                                            |
//+------------------------------------------------------------------+
double GetSymbolSpread()
{
   return g_SymbolService.GetSymbolSpread();
}

//+------------------------------------------------------------------+
//| Get point (wrapper)                                             |
//+------------------------------------------------------------------+
double GetSymbolPoint()
{
   return g_SymbolService.GetSymbolPoint();
}

//+------------------------------------------------------------------+
//| Get tick size (wrapper)                                         |
//+------------------------------------------------------------------+
double GetSymbolTickSize()
{
   return g_SymbolService.GetSymbolTickSize();
}

//+------------------------------------------------------------------+
//| Get tick value (wrapper)                                        |
//+------------------------------------------------------------------+
double GetSymbolTickValue()
{
   return g_SymbolService.GetSymbolTickValue();
}

//+------------------------------------------------------------------+
//| Get margin required (wrapper)                                   |
//+------------------------------------------------------------------+
double GetSymbolMarginRequired(double lotSize)
{
   return g_SymbolService.GetSymbolMarginRequired(lotSize);
}

//+------------------------------------------------------------------+
//| Check if symbol valid (wrapper)                                |
//+------------------------------------------------------------------+
bool IsSymbolValid()
{
   return g_SymbolService.IsSymbolValid();
}

//+------------------------------------------------------------------+
//| Check if trade allowed (wrapper)                               |
//+------------------------------------------------------------------+
bool IsSymbolTradeAllowed()
{
   return g_SymbolService.IsSymbolTradeAllowed();
}

//+------------------------------------------------------------------+
//| Normalize lot (wrapper)                                         |
//+------------------------------------------------------------------+
double NormalizeLot(double lotSize)
{
   return g_SymbolService.NormalizeLot(lotSize);
}
//+------------------------------------------------------------------+
