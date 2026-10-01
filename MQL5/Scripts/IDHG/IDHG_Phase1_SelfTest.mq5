//+------------------------------------------------------------------+
//| IDHG_Phase1_SelfTest.mq5 — Self-test PHASE 1                      |
//| Script CHỈ ĐỌC: không gửi lệnh.                                   |
//+------------------------------------------------------------------+
#property script_show_inputs
#property description "IDHG Phase 1 self-test (không gửi lệnh)"

#include "..\..\Experts\IDHG\Tests\IDHG_TestsPhase1.mqh"

void OnStart()
  {
   IdhgRunPhase1Tests();
//--- Kiểm tra đọc dữ liệu thật của terminal hiện tại (chỉ đọc)
   T_Begin("P1.LIVE_TERMINAL");
   long mm = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   Print("  Tài khoản margin mode = ", mm, IdhgIsHedgingMode(mm) ? " (HEDGING)" : " (KHÔNG HEDGING → EA sẽ INIT_FAILED)");
   SIdhgSymbolSpec spec;
   bool ok = IdhgReadSymbolSpec(_Symbol, spec);
   string err;
   IdhgCheckSymbolSpec(spec, err);
   T_Check(ok, "Đọc thông số symbol " + _Symbol, err);
   PrintFormat("  digits=%d tick=%s tickValue=%s contract=%s vol[min=%s max=%s step=%s] hedged=%s",
               spec.digits, DoubleToString(spec.tickSize, 5), DoubleToString(spec.tickValue, 5),
               DoubleToString(spec.contractSize, 2), DoubleToString(spec.volMin, 2), DoubleToString(spec.volMax, 2),
               DoubleToString(spec.volStep, 2), DoubleToString(spec.marginHedged, 2));
   T_Report();
  }
//+------------------------------------------------------------------+
