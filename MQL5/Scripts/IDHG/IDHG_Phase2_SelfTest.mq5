//+------------------------------------------------------------------+
//| IDHG_Phase2_SelfTest.mq5 — Self-test PHASE 2                      |
//| Script CHỈ ĐỌC: không gửi lệnh.                                   |
//+------------------------------------------------------------------+
#property script_show_inputs
#property description "IDHG Phase 2 self-test (không gửi lệnh)"

#include "..\..\Experts\IDHG\Tests\IDHG_TestsPhase2.mqh"

void OnStart()
  {
   IdhgRunPhase1Tests();   // hồi quy
   IdhgRunPhase2Tests();
   T_Report();
  }
//+------------------------------------------------------------------+
