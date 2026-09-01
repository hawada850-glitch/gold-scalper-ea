#property strict
#property version "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

// ===== الإعدادات التي تتحكم بها =====
input double RiskPercent        = 1.0;   // المخاطرة لكل صفقة %
input int    MaxPositions       = 1;     // أقصى عدد صفقات
input double MaxDailyProfit     = 5.0;   // إيقاف عند ربح 5$
input double MaxDailyLoss       = 2.0;   // إيقاف عند خسارة 2$

input bool   UseTrailing        = true;
input double TrailStartProfit   = 1.0;   // يبدأ التريلينغ عند ربح 1$
input int    TrailDistancePts   = 150;

input int FastEMA_M1            = 9;
input int SlowEMA_M1            = 21;

input int FastEMA_M5            = 20;
input int SlowEMA_M5            = 50;

input int ATRPeriod             = 14;
input double SL_ATR_Mult        = 1.2;
input double TP_RR              = 1.5;

input ulong MagicNumber         = 505050;

// ===== المؤشرات =====
int emaFastM1;
int emaSlowM1;
int emaFastM5;
int emaSlowM5;
int atrHandle;

datetime dayStart;

// --------------------------------------------------
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);

   emaFastM1 = iMA(_Symbol, PERIOD_M1, FastEMA_M1, 0,
                   MODE_EMA, PRICE_CLOSE);

   emaSlowM1 = iMA(_Symbol, PERIOD_M1, SlowEMA_M1, 0,
                   MODE_EMA, PRICE_CLOSE);

   emaFastM5 = iMA(_Symbol, PERIOD_M5, FastEMA_M5, 0,
                   MODE_EMA, PRICE_CLOSE);

   emaSlowM5 = iMA(_Symbol, PERIOD_M5, SlowEMA_M5, 0,
                   MODE_EMA, PRICE_CLOSE);

   atrHandle = iATR(_Symbol, PERIOD_M1, ATRPeriod);

   dayStart = StringToTime(
      TimeToString(TimeCurrent(), TIME_DATE)
   );

   if(emaFastM1 == INVALID_HANDLE ||
      emaSlowM1 == INVALID_HANDLE ||
      emaFastM5 == INVALID_HANDLE ||
      emaSlowM5 == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

// --------------------------------------------------
double DailyProfit()
{
   HistorySelect(dayStart, TimeCurrent());

   double result = 0;

   uint total = HistoryDealsTotal();

   for(uint i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC)
         != (long)MagicNumber)
         continue;

      result += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      result += HistoryDealGetDouble(ticket, DEAL_SWAP);
      result += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }

   return result;
}

// --------------------------------------------------
int OpenPositions()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC)
         != (long)MagicNumber)
         continue;

      count++;
   }

   return count;
}

// --------------------------------------------------
int TrendDirection()
{
   double fast[1];
   double slow[1];

   if(CopyBuffer(emaFastM5, 0, 0, 1, fast) <= 0)
      return 0;

   if(CopyBuffer(emaSlowM5, 0, 0, 1, slow) <= 0)
      return 0;

   if(fast[0] > slow[0])
      return 1;     // صاعد

   if(fast[0] < slow[0])
      return -1;    // هابط

   return 0;
}

// --------------------------------------------------
int EntrySignal()
{
   double fast[2];
   double slow[2];

   if(CopyBuffer(emaFastM1, 0, 0, 2, fast) < 2)
      return 0;

   if(CopyBuffer(emaSlowM1, 0, 0, 2, slow) < 2)
      return 0;

   // تقاطع صاعد
   if(fast[1] <= slow[1] &&
      fast[0] > slow[0])
      return 1;

   // تقاطع هابط
   if(fast[1] >= slow[1] &&
      fast[0] < slow[0])
      return -1;

   return 0;
}

// --------------------------------------------------
double CalculateLot(double stopPoints)
{
   if(stopPoints <= 0)
      return 0;

   double equity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   double riskMoney =
      equity * RiskPercent / 100.0;

   double tickValue =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_VALUE);

   double tickSize =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return 0;

   double lossPerLot =
      stopPoints * _Point /
      tickSize * tickValue;

   if(lossPerLot <= 0)
      return 0;

   double lot =
      riskMoney / lossPerLot;

   double minLot =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_VOLUME_MIN);

   double maxLot =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_VOLUME_MAX);

   double step =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_VOLUME_STEP);

   lot = MathMax(minLot,
                 MathMin(maxLot, lot));

   lot = MathFloor(lot / step) * step;

   return NormalizeDouble(lot, 2);
}

// --------------------------------------------------
void ManageTrailing()
{
   if(!UseTrailing)
      return;

   for(int i = PositionsTotal() - 1;
       i >= 0;
       i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL)
         != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC)
         != (long)MagicNumber)
         continue;

      double profit =
         PositionGetDouble(POSITION_PROFIT);

      if(profit < TrailStartProfit)
         continue;

      long type =
         PositionGetInteger(POSITION_TYPE);

      double oldSL =
         PositionGetDouble(POSITION_SL);

      double tp =
         PositionGetDouble(POSITION_TP);

      double price;

      if(type == POSITION_TYPE_BUY)
         price =
            SymbolInfoDouble(_Symbol,
                             SYMBOL_BID);
      else
         price =
            SymbolInfoDouble(_Symbol,
                             SYMBOL_ASK);

      double newSL;

      if(type == POSITION_TYPE_BUY)
      {
         newSL =
            price -
            TrailDistancePts * _Point;

         if(oldSL == 0 ||
            newSL > oldSL)
         {
            trade.PositionModify(
               ticket,
               newSL,
               tp
            );
         }
      }
      else
      {
         newSL =
            price +
            TrailDistancePts * _Point;

         if(oldSL == 0 ||
            newSL < oldSL)
         {
            trade.PositionModify(
               ticket,
               newSL,
               tp
            );
         }
      }
   }
}

// --------------------------------------------------
void OnTick()
{
   // إدارة الصفقات الحالية
   ManageTrailing();

   // حدود الربح والخسارة اليومية
   double daily = DailyProfit();

   if(daily >= MaxDailyProfit)
      return;

   if(daily <= -MaxDailyLoss)
      return;

   // عدد الصفقات
   if(OpenPositions() >= MaxPositions)
      return;

   // اتجاه M5
   int trend = TrendDirection();

   if(trend == 0)
      return;

   // إشارة M1
   int signal = EntrySignal();

   if(signal == 0)
      return;

   // لا نتداول عكس الاتجاه
   if(signal != trend)
      return;

   // ATR
   double atr[1];

   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
      return;

   double stopDistance =
      atr[0] * SL_ATR_Mult;

   double stopPoints =
      stopDistance / _Point;

   double lot =
      CalculateLot(stopPoints);

   if(lot <= 0)
      return;

   double ask =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_ASK);

   double bid =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_BID);

   if(signal == 1)
   {
      double sl =
         bid - stopDistance;

      double tp =
         bid + stopDistance * TP_RR;

      trade.Buy(
         lot,
         _Symbol,
         ask,
         sl,
         tp,
         "Gold Scalper BUY"
      );
   }

   if(signal == -1)
   {
      double sl =
         ask + stopDistance;

      double tp =
         ask - stopDistance * TP_RR;

      trade.Sell(
         lot,
         _Symbol,
         bid,
         sl,
         tp,
         "Gold Scalper SELL"
      );
   }
}
