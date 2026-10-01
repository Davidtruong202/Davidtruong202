//+------------------------------------------------------------------+
//| IndependentDynamicHedgeGridEA.mq5                                |
//| Independent Dynamic Hedge Grid — XAUUSD — MT5 (HEDGING only)     |
//| PHASE 1: khung kiến trúc. KHÔNG gửi lệnh.                         |
//+------------------------------------------------------------------+
#property copyright   "IDHG"
#property version     "1.00"
#property description "Independent Dynamic Hedge Grid (BUY/SELL độc lập). Chỉ chạy trên tài khoản HEDGING."

#include "IDHG_Inputs.mqh"
#include "IDHG_State.mqh"
#include "IDHG_Cycle.mqh"

CConfig        g_config;
CState         g_state;
CCycleManager  g_cycle;
CIdhgLog       g_log;
SIdhgSymbolSpec g_spec;

//--- Kiểm tra trước khi chạy: HEDGING, symbol, cấu hình
int IdhgPreflight(string &err)
  {
   err = "";
   long marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(!IdhgIsHedgingMode(marginMode))
     {
      err = "Tài khoản KHÔNG phải HEDGING — EA từ chối khởi động";
      return INIT_FAILED;
     }
   if(!IdhgReadSymbolSpec(_Symbol, g_spec))
     {
      string e;
      IdhgCheckSymbolSpec(g_spec, e);
      err = "Thông số symbol không hợp lệ: " + e;
      return INIT_FAILED;
     }
   SIdhgConfig cfg;
   IdhgConfigFromInputs(cfg);
   if(!g_config.Load(cfg))
     {
      err = "Input không hợp lệ: " + g_config.LastError();
      return INIT_PARAMETERS_INCORRECT;
     }
   return INIT_SUCCEEDED;
  }

int OnInit()
  {
   string err;
   int rc = IdhgPreflight(err);
   if(rc != INIT_SUCCEEDED)
     {
      g_log.Warn(err);
      return rc;
     }
   if(StringFind(_Symbol, "XAU") < 0)
      g_log.Warn("Symbol " + _Symbol + " không phải XAUUSD — EA được thiết kế cho XAUUSD");
   g_log.SetThrottle(InpLogThrottleSec);
   g_log.Info("Khởi động " + _Symbol + " magic=" + IntegerToString(InpMagicNumber) + " | " + g_config.Summary());
   EventSetTimer(InpTimerSeconds);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTick()
  {
   // PHASE 1: không có logic giao dịch.
  }

void OnTimer()
  {
  }
//+------------------------------------------------------------------+
