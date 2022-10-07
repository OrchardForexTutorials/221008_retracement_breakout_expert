/*

   Reentrant Breakout.mqh
   Copyright 2022, Orchard Forex
   https://www.orchardforex.com

*/

#property copyright "Copyright 2022, Orchard Forex"
#property link "https://www.orchardforex.com"
#property version "1.00"
#property strict

//
//	Inputs
//
//
//	Range start
//
input int    InpRangeStartHours   = 0; // Range start hours (0-23)
input int    InpRangeStartMinutes = 0; // Range start minutes (0-59)

//
//	Range end
//
input int    InpRangeEndHours     = 0; // Range end hours (0-23)
input int    InpRangeEndMinutes   = 0; // Range end minutes (0-59)

//
// Close time
//
input int    InpCloseHours        = 0; // Close hours (0-23)
input int    InpCloseMinutes      = 0; // Close minutes (0-59)

//
//	The basic expert uses fixed order size
//
input double InpOrderSize         = 0.01; // Order size in lots

//
//	Trades also have a magic number and a comment
//
input int    InpMagic             = 222222;                       // Magic number
input string InpTradeComment      = "Example Reentrant Breakout"; // Trade comment

// Some global values
bool         InsideRange; // Gets set when the time is between start and end
bool         InsideClose; // Gets set when time is between end and close
bool         BreakoutHigh;
bool         BreakinHigh;
bool         BreakoutLow;
bool         BreakinLow;

int          RangeStartMinutes;
int          RangeEndMinutes;
int          CloseMinutes;

//
// The OnTick function is now the same for MT4 and MT5 in this model
//
void         OnTick() {

   // This expert places buy/sell stop orders at the end time
   // based on the price range between start-end
   // and closes everything at close time
   // unless already closed by tp or sl.
   //
   // You can get into trouble if you have very close start/end/close
   //	gaps that fall within the market close time. Watch for that.

   // static values to track the range
   static double rangeHigh = 0;
   static double rangeLow  = 0;

   // Quick check if trading is possible
   if ( !IsTradeAllowed() ) return;
   // This to check also if the market is open
   //	https://youtu.be/GejPt5odJow
   if ( !IsTradeAllowed( Symbol(), TimeCurrent() ) ) return;

   // Check if time has gone past the close time
   bool nowOutsideClose = !IsInsideTime( TimeCurrent(), RangeEndMinutes, CloseMinutes );
   if ( InsideClose && nowOutsideClose ) {
      CloseAll();
      InsideClose  = false;

      rangeHigh    = 0;
      rangeLow     = 0;

      BreakinHigh  = false;
      BreakinLow   = false;
      BreakoutHigh = false;
      BreakoutLow  = false;
   }
   InsideClose = !nowOutsideClose;

   if ( InsideClose && IsNewBar( true ) ) {
      double close  = iClose( Symbol(), Period(), 1 );
      long   spread = SymbolInfoInteger( Symbol(), SYMBOL_SPREAD ) + 50;
      double point  = SymbolInfoDouble( Symbol(), SYMBOL_POINT );
      double gap    = spread * point;

      if ( !BreakinHigh ) {
         BreakoutHigh = BreakoutHigh || ( close > rangeHigh );
         if ( BreakoutHigh && close < rangeHigh ) {
            BreakinHigh = true;
            OpenTrade( ORDER_TYPE_BUY_STOP, rangeHigh + gap, rangeLow );
         }
      }

      if ( !BreakinLow ) {
         BreakoutLow = BreakoutLow || ( close < rangeLow );
         if ( BreakoutLow && close > rangeLow ) {
            BreakinLow = true;
            OpenTrade( ORDER_TYPE_SELL_STOP, rangeLow - gap, rangeHigh );
         }
      }
   }

   // Check if time has moved outside the range
   bool nowOutsideRange = !IsInsideTime( TimeCurrent(), RangeStartMinutes, RangeEndMinutes );
   if ( InsideRange && nowOutsideRange ) {

      ShowRange( rangeHigh, rangeLow );

      InsideRange  = false;
      InsideClose  = true;

      BreakoutHigh = false;
      BreakinHigh  = false;
      BreakoutLow  = false;
      BreakinLow   = false;
   }
   InsideRange = !nowOutsideRange;

   if ( InsideRange ) {
      double ask = SymbolInfoDouble( Symbol(), SYMBOL_ASK );
      double bid = SymbolInfoDouble( Symbol(), SYMBOL_BID );
      if ( rangeHigh == 0 || ask > rangeHigh ) rangeHigh = ask;
      if ( rangeLow == 0 || bid < rangeLow ) rangeLow = bid;
   }

   //
}

//
//	Check that input parameters are in range and make some basic conversions
//
bool CheckInput() {

   if ( ( InpRangeStartHours < 0 || InpRangeStartHours > 23 ) || ( InpRangeStartMinutes < 0 || InpRangeStartMinutes > 59 ) || ( InpRangeEndHours < 0 || InpRangeEndHours > 23 ) ||
        ( InpRangeEndMinutes < 0 || InpRangeEndMinutes > 59 ) || ( InpCloseHours < 0 || InpCloseHours > 23 ) || ( InpCloseMinutes < 0 || InpCloseMinutes > 59 ) )
      return false;

   RangeStartMinutes = InpRangeStartHours * 60 + InpRangeStartMinutes;
   RangeEndMinutes   = InpRangeEndHours * 60 + InpRangeEndMinutes;
   CloseMinutes      = InpCloseHours * 60 + InpCloseMinutes;

   if ( RangeStartMinutes == RangeEndMinutes ) return false;
   if ( RangeEndMinutes == CloseMinutes ) return false;

   return true;
}

//
//	IsInsideTime, is a supplied date time (reduced to time of day)
//		between specified start and end times
//	This copes with start and end spanning midnight, eg start = 23:00 and end = 01:00
//		but remember that this also spans a weekend so 00:30 Monday morning
//		and 23:30 Friday could be in the same range.
//
bool IsInsideTime( datetime now, int startMinutes, int endMinutes ) {

   MqlDateTime time;
   TimeToStruct( now, time );
   int nowMinutes = time.hour * 60 + time.min; // Currently ignoring seconds after the minute
   return ( ( startMinutes <= nowMinutes && nowMinutes < endMinutes ) || ( ( startMinutes > endMinutes ) && ( nowMinutes < endMinutes || nowMinutes >= startMinutes ) ) );
}
//
//	Pips, points conversion
//
double PipSize() { return ( PipSize( Symbol() ) ); }
double PipSize( string symbol ) {
   double point  = SymbolInfoDouble( symbol, SYMBOL_POINT );
   int    digits = ( int )SymbolInfoInteger( symbol, SYMBOL_DIGITS );
   return ( ( ( digits % 2 ) == 1 ) ? point * 10 : point );
}

double PipsToDouble( double pips ) { return ( pips * PipSize( Symbol() ) ); }
double PipsToDouble( double pips, string symbol ) { return ( pips * PipSize( symbol ) ); }

bool   IsNewBar( bool first_call = false ) {

   static bool result = false;
   if ( !first_call ) return ( result );

   static datetime previous_time = 0;
   datetime        current_time  = iTime( Symbol(), Period(), 0 );
   result                        = false;
   if ( previous_time != current_time ) {
      previous_time = current_time;
      result        = true;
   }
   return ( result );
}
void ShowRange( double hi, double lo ) {

   ShowRangeLine( "hi", OBJ_HLINE, hi );
   ShowRangeLine( "lo", OBJ_HLINE, lo );
   ShowRangeLine( "now", OBJ_VLINE, lo );
}

void ShowRangeLine( string name, ENUM_OBJECT type, double value ) {

   ObjectDelete( 0, name );
   ObjectCreate( 0, name, type, 0, iTime( Symbol(), Period(), 1 ), value );
   ObjectSetInteger( 0, name, OBJPROP_COLOR, clrWhite );
   ObjectSetInteger( 0, name, OBJPROP_STYLE, STYLE_DOT );
}
