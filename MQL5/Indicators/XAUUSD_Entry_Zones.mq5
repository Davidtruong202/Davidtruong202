//+------------------------------------------------------------------+
//|                                    XAUUSD_Entry_Zones.mq5         |
//|  Non-trading indicator: marks BUY/SELL entry zones (Order Block  |
//|  + Fair Value Gap, same displacement logic as the ICT EA in this |
//|  repo) as rectangles on the chart, and can push a Telegram alert |
//|  when a fresh zone forms and again when price returns to react   |
//|  inside it. Works on whatever symbol/timeframe you attach it to  |
//|  (e.g. XAUUSD H1). See README.md for setup instructions.         |
//+------------------------------------------------------------------+
#property copyright "Custom Indicator"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//====================================================================
// Inputs
//====================================================================
input group "=== Displacement detection ==="
input int    InpATRPeriod     = 14;
input double InpDispATR       = 1.5;   // min candle range vs ATR to count as displacement
input double InpDispBody      = 0.6;   // min body/range ratio for a displacement candle
input double InpFVGMinATR     = 0.2;   // min FVG gap size vs ATR
input bool   InpOBRequireFVG  = true;  // only draw an Order Block when it has a paired FVG
input bool   InpOBUseWick     = false; // Order Block box = wick range instead of candle body
input int    InpHistoryBars   = 500;   // bars scanned once at load to draw existing zones

input group "=== Drawing ==="
input bool   InpShowOB       = true;
input bool   InpShowFVG      = true;
input int    InpMaxZones     = 25;      // oldest zones beyond this are dropped
input int    InpExtendBars   = 60;      // extend each box this many bars to the right of "now"
input color  InpColorBuyOB   = clrLime;
input color  InpColorSellOB  = clrRed;
input color  InpColorBuyFVG  = C'0,90,0';
input color  InpColorSellFVG = C'90,0,0';

input group "=== Telegram alert ==="
input bool   InpEnableTelegram    = false;  // requires api.telegram.org whitelisted (see README)
input string InpTelegramToken     = "";     // BotFather bot token
input string InpTelegramChatID    = "";     // numeric chat id (from getUpdates)
input bool   InpAlertOnZoneFormed = true;   // notify when a fresh zone appears
input bool   InpAlertOnZoneTouch  = true;   // notify when price first re-enters a fresh zone
input bool   InpTelegramTestOnInit= true;   // send one test message on load to confirm setup

//====================================================================
// Types
//====================================================================
enum ENUM_ZONE_TYPE  { ZONE_OB_BULL, ZONE_OB_BEAR, ZONE_FVG_BULL, ZONE_FVG_BEAR };
enum ENUM_ZONE_STATE { ZONE_FRESH, ZONE_MITIGATED, ZONE_VOID };

struct Zone
{
   ENUM_ZONE_TYPE  type;
   double          top;
   double          bottom;
   ENUM_ZONE_STATE state;
   datetime        formed;
   string          objName;
   bool            notifiedFormed;
   bool            notifiedTouch;
};

Zone     zones[];
int      atrHandle    = INVALID_HANDLE;
datetime g_lastBarTime = 0;

//====================================================================
// Telegram helpers
//====================================================================
string CharToStr(ushort code)
{
   uchar arr[1];
   arr[0] = (uchar)code;
   return CharArrayToString(arr, 0, 1);
}

// ASCII-safe URL encoder. Keep alert text in plain ASCII (no dấu) -
// MQL5 works with UTF-16 code units here, not UTF-8 bytes, so percent-
// encoding accented Vietnamese correctly would need extra UTF-8 packing.
string UrlEncode(string text)
{
   string result = "";
   int len = StringLen(text);
   for(int i=0; i<len; i++)
   {
      ushort ch = StringGetCharacter(text, i);
      if((ch>='A'&&ch<='Z')||(ch>='a'&&ch<='z')||(ch>='0'&&ch<='9')||ch=='-'||ch=='_'||ch=='.'||ch=='~')
         result += CharToStr(ch);
      else if(ch==' ')
         result += "+";
      else
         result += StringFormat("%%%02X", ch);
   }
   return result;
}

void SendTelegram(string text)
{
   if(!InpEnableTelegram) return;
   if(InpTelegramToken=="" || InpTelegramChatID=="")
   {
      Print("[Telegram] Token or Chat ID missing, skipping alert.");
      return;
   }

   string url = "https://api.telegram.org/bot"+InpTelegramToken+"/sendMessage?chat_id="+InpTelegramChatID+"&text="+UrlEncode(text);
   char   data[];
   char   result[];
   string resultHeaders;
   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, data, result, resultHeaders);
   if(res==-1)
      PrintFormat("[Telegram] WebRequest failed, err=%d. In MT5: Tools > Options > Expert Advisors > 'Allow WebRequest for listed URL' and add https://api.telegram.org", GetLastError());
   else if(res!=200)
      PrintFormat("[Telegram] HTTP %d: %s", res, CharArrayToString(result));
}

string ZoneTypeName(ENUM_ZONE_TYPE t)
{
   switch(t)
   {
      case ZONE_OB_BULL:  return "Order Block BUY";
      case ZONE_OB_BEAR:  return "Order Block SELL";
      case ZONE_FVG_BULL: return "FVG BUY";
      case ZONE_FVG_BEAR: return "FVG SELL";
   }
   return "Zone";
}

bool IsBullZone(ENUM_ZONE_TYPE t) { return (t==ZONE_OB_BULL || t==ZONE_FVG_BULL); }

//====================================================================
// Drawing
//====================================================================
color ZoneColor(ENUM_ZONE_TYPE t)
{
   switch(t)
   {
      case ZONE_OB_BULL:  return InpColorBuyOB;
      case ZONE_OB_BEAR:  return InpColorSellOB;
      case ZONE_FVG_BULL: return InpColorBuyFVG;
      case ZONE_FVG_BEAR: return InpColorSellFVG;
   }
   return clrGray;
}

void DrawZoneObject(int idx)
{
   string name = zones[idx].objName;
   datetime t2 = TimeCurrent() + (long)InpExtendBars*PeriodSeconds(_Period);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, zones[idx].formed, zones[idx].top, t2, zones[idx].bottom);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ZoneColor(zones[idx].type));
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_STYLE, IsBullZone(zones[idx].type)?STYLE_SOLID:STYLE_SOLID);
   }
   else
   {
      ObjectMove(0, name, 1, t2, zones[idx].bottom);
      ObjectSetInteger(0, name, OBJPROP_STYLE, zones[idx].state==ZONE_MITIGATED?STYLE_DOT:STYLE_SOLID);
   }
}

void RemoveZoneObject(int idx)
{
   ObjectDelete(0, zones[idx].objName);
}

void TrimZones()
{
   while(ArraySize(zones) > InpMaxZones)
   {
      RemoveZoneObject(0);
      ArrayRemove(zones, 0, 1);
   }
}

//====================================================================
// Zone creation
//====================================================================
void AddZone(ENUM_ZONE_TYPE type, double top, double bottom, datetime formed, bool notify)
{
   string name = StringFormat("ICTZone_%s_%I64d", EnumToString(type), (long)formed);
   if(ObjectFind(0, name) >= 0) return; // already drawn (re-init / backfill overlap)

   int n = ArraySize(zones);
   ArrayResize(zones, n+1);
   zones[n].type    = type;
   zones[n].top     = MathMax(top, bottom);
   zones[n].bottom  = MathMin(top, bottom);
   zones[n].state   = ZONE_FRESH;
   zones[n].formed  = formed;
   zones[n].objName = name;
   zones[n].notifiedFormed = false;
   zones[n].notifiedTouch  = false;

   DrawZoneObject(n);
   TrimZones();

   if(notify && InpAlertOnZoneFormed)
   {
      int idx = ArraySize(zones)-1; // TrimZones may have shifted indices; find by name to be safe
      for(int i=0; i<ArraySize(zones); i++)
         if(zones[i].objName==name) { idx=i; break; }
      if(idx>=0 && !zones[idx].notifiedFormed)
      {
         SendTelegram(StringFormat("%s %s\nNew %s zone: %.2f - %.2f\nTime: %s",
            _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
            ZoneTypeName(type), zones[idx].bottom, zones[idx].top,
            TimeToString(formed, TIME_DATE|TIME_MINUTES)));
         zones[idx].notifiedFormed = true;
      }
   }
}

//====================================================================
// Core detection, generalized on "base" = shift of the closed bar being
// evaluated (base=1 means "the bar that just closed", same convention
// as the ICT EA in this repo, just generalized to any shift for backfill).
//====================================================================
double GetATRAtShift(int shift)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(atrHandle, 0, shift, 1, buf) < 1) return 0;
   return buf[0];
}

void EvaluateBarShift(int base, bool notify)
{
   double atr = GetATRAtShift(base);
   if(atr<=0) return;

   double o1=iOpen(_Symbol,_Period,base), h1=iHigh(_Symbol,_Period,base);
   double l1=iLow(_Symbol,_Period,base),  c1=iClose(_Symbol,_Period,base);
   double range1 = h1-l1;
   double body1  = MathAbs(c1-o1);
   if(range1 < InpDispATR*atr) return;
   if(body1  < InpDispBody*range1) return;

   bool bullDisp = (c1>o1);
   datetime barTime = iTime(_Symbol,_Period,base);

   int obShift=-1;
   for(int s=2; s<=6; s++)
   {
      int actual = base + (s-1);
      double o=iOpen(_Symbol,_Period,actual), c=iClose(_Symbol,_Period,actual);
      bool bearish=(c<o);
      if(bullDisp && bearish)   { obShift=actual; break; }
      if(!bullDisp && !bearish) { obShift=actual; break; }
   }

   bool hasFVG=false; double fvgTop=0, fvgBottom=0;
   double h3=iHigh(_Symbol,_Period,base+2), l3=iLow(_Symbol,_Period,base+2);
   if(bullDisp)
   {
      if(l1>h3)
      {
         double gap=l1-h3;
         if(gap>=InpFVGMinATR*atr) { hasFVG=true; fvgBottom=h3; fvgTop=l1; }
      }
   }
   else
   {
      if(h1<l3)
      {
         double gap=l3-h1;
         if(gap>=InpFVGMinATR*atr) { hasFVG=true; fvgBottom=h1; fvgTop=l3; }
      }
   }

   if(InpShowOB && obShift>=0 && (!InpOBRequireFVG || hasFVG))
   {
      double oo=iOpen(_Symbol,_Period,obShift), oc=iClose(_Symbol,_Period,obShift);
      double oh=iHigh(_Symbol,_Period,obShift), ol=iLow(_Symbol,_Period,obShift);
      double top, bottom;
      if(InpOBUseWick) { top=oh; bottom=ol; }
      else             { top=MathMax(oo,oc); bottom=MathMin(oo,oc); }
      AddZone(bullDisp?ZONE_OB_BULL:ZONE_OB_BEAR, top, bottom, barTime, notify);
   }
   if(InpShowFVG && hasFVG)
      AddZone(bullDisp?ZONE_FVG_BULL:ZONE_FVG_BEAR, fvgTop, fvgBottom, barTime, notify);
}

//====================================================================
// Mitigation / touch tracking - runs against the bar at shift "base"
//====================================================================
void UpdateZoneStates(int base, bool notify)
{
   double h1=iHigh(_Symbol,_Period,base), l1=iLow(_Symbol,_Period,base), c1=iClose(_Symbol,_Period,base);

   for(int i=0; i<ArraySize(zones); i++)
   {
      if(zones[i].state==ZONE_VOID) continue;
      bool overlap = (l1<=zones[i].top && h1>=zones[i].bottom);
      bool bullish = IsBullZone(zones[i].type);

      if(overlap)
      {
         if(zones[i].state==ZONE_FRESH && !zones[i].notifiedTouch && notify && InpAlertOnZoneTouch)
         {
            SendTelegram(StringFormat("%s %s\nPrice re-entered %s zone %.2f - %.2f\nConsider %s, SL beyond the zone edge.",
               _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), ZoneTypeName(zones[i].type),
               zones[i].bottom, zones[i].top, bullish?"BUY":"SELL"));
            zones[i].notifiedTouch = true;
         }

         if(bullish)
         {
            if(c1>zones[i].top)        zones[i].state=ZONE_MITIGATED;
            else if(c1<zones[i].bottom) zones[i].state=ZONE_VOID;
            else                        zones[i].state=ZONE_MITIGATED;
         }
         else
         {
            if(c1<zones[i].bottom)     zones[i].state=ZONE_MITIGATED;
            else if(c1>zones[i].top)   zones[i].state=ZONE_VOID;
            else                       zones[i].state=ZONE_MITIGATED;
         }
      }

      if(zones[i].state==ZONE_VOID) RemoveZoneObject(i);
      else                          DrawZoneObject(i);
   }
}

//====================================================================
// Standard indicator handlers
//====================================================================
int OnInit()
{
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(atrHandle==INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }

   // Backfill: replay history once so existing zones show up immediately,
   // oldest to newest (base = large shift -> base = 2), without spamming Telegram.
   int bars = MathMin(InpHistoryBars, iBars(_Symbol,_Period)-10);
   for(int base=bars; base>=2; base--)
   {
      UpdateZoneStates(base, false);
      EvaluateBarShift(base, false);
   }

   g_lastBarTime = iTime(_Symbol, _Period, 0);

   if(InpEnableTelegram && InpTelegramTestOnInit)
      SendTelegram(StringFormat("%s %s indicator attached. Telegram alerts are ON.",
                   _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period)));

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int i=0; i<ArraySize(zones); i++)
      ObjectDelete(0, zones[i].objName);
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt != g_lastBarTime)
   {
      g_lastBarTime = bt;
      UpdateZoneStates(1, true);
      EvaluateBarShift(1, true);
   }
   else
   {
      // keep boxes extended to "now" between bar closes too
      for(int i=0; i<ArraySize(zones); i++)
         if(zones[i].state!=ZONE_VOID) DrawZoneObject(i);
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
