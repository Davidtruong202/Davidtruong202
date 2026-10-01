//+------------------------------------------------------------------+
//| IDHG_Phase3_SelfTest.mq5 — Self-test PHASE 3 (Order Manager)      |
//| KHÔNG gửi lệnh: chỉ kiểm tra logic + dựng request + OrderCheck.   |
//| Luồng gửi lệnh thật được kiểm thử trên broker giả lập (host) và   |
//| cần chạy EA trên tài khoản DEMO để xác nhận với broker thật.      |
//+------------------------------------------------------------------+
#property script_show_inputs
#property description "IDHG Phase 3 self-test (không gửi lệnh)"

#include "..\..\Experts\IDHG\Tests\IDHG_TestsPhase3.mqh"

void OnStart()
  {
   IdhgRunPhase1Tests();   // hồi quy
   IdhgRunPhase2Tests();   // hồi quy
   IdhgRunPhase3Tests();
//--- Chỉ đọc: kiểm tra request dựng với symbol thật qua OrderCheck (KHÔNG OrderSend)
   T_Begin("P3.LIVE_ORDERCHECK");
   SIdhgSymbolSpec spec;
   SIdhgMarket mk;
   if(IdhgReadSymbolSpec(_Symbol, spec) && IdhgReadMarket(_Symbol, spec, mk))
     {
      SIdhgCandidate c;
      c.Reset();
      c.side = IDHG_BUY;
      c.cycleId = 1;
      c.levelId = 0;
      c.logicalPrice = mk.mid;
      c.lot = LotNormalize(spec.volMin, spec.volMin, spec.volMax, spec.volStep, 0, 0);
      MqlTradeRequest req;
      MqlTradeCheckResult chk;
      IdhgBuildOpenRequest(c, mk, spec, IDHG_DEF_MAGIC, IDHG_DEF_PREFIX, IDHG_DEF_DEVIATION, req);
      ZeroMemory(chk);
      bool ok = OrderCheck(req, chk);
      PrintFormat("  OrderCheck BUY %s lot=%s → %s retcode=%d margin=%s comment=%s", _Symbol, DoubleToString(c.lot, 2),
                  ok ? "OK" : "TỪ CHỐI", (int)chk.retcode, DoubleToString(chk.margin, 2), chk.comment);
      T_Check(StringLen(req.comment) <= IDHG_MAX_COMMENT_LEN, "Comment request ≤ 31 ký tự", req.comment);
     }
   else
      T_Check(false, "Đọc symbol/giá hiện tại");
   T_Report();
  }
//+------------------------------------------------------------------+
