//+------------------------------------------------------------------+
//| IDHG_TestsAll.mqh — gom toàn bộ self-test dùng chung (hồi quy)    |
//+------------------------------------------------------------------+
#ifndef IDHG_TESTS_ALL_MQH
#define IDHG_TESTS_ALL_MQH

#include "IDHG_TestsPhase1.mqh"
#include "IDHG_TestsPhase2.mqh"

void IdhgRunAllSharedTests(void)
  {
   IdhgRunPhase1Tests();
   IdhgRunPhase2Tests();
  }

#endif
