//+------------------------------------------------------------------+
//| IndependentDynamicHedgeGridEA.mq5                                |
//| Independent Dynamic Hedge Grid — XAUUSD — MT5 (HEDGING only)     |
//| Toàn bộ logic nằm trong các module IDHG_*.mqh; file này chỉ      |
//| chuyển sự kiện MT5 tới CIdhgEngine.                              |
//+------------------------------------------------------------------+
#property copyright   "IDHG"
#property version     "1.00"
#property description "Independent Dynamic Hedge Grid (BUY/SELL độc lập). Chỉ chạy trên tài khoản HEDGING."

#include "IDHG_Inputs.mqh"
#include "IDHG_Engine.mqh"

CIdhgEngine g_engine;

int OnInit()
  {
   SIdhgConfig cfg;
   IdhgConfigFromInputs(cfg);
   string err;
   int rc = g_engine.Init(_Symbol, cfg, err);
   if(rc != INIT_SUCCEEDED)
     {
      Print("[IDHG][CẢNH BÁO] ", err);
      return rc;
     }
   if(StringFind(_Symbol, "XAU") < 0)
      g_engine.m_log.Warn("Symbol " + _Symbol + " không phải XAUUSD — EA được thiết kế cho XAUUSD");
   g_engine.m_log.Info("Khởi động " + _Symbol + " magic=" + IntegerToString(InpMagicNumber) + " | " + g_engine.m_config.Summary());
   EventSetTimer(InpTimerSeconds);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTick()
  {
   g_engine.OnTick();
  }

void OnTimer()
  {
   g_engine.OnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   g_engine.OnTradeTransaction(trans);
  }
//+------------------------------------------------------------------+
