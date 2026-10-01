//+------------------------------------------------------------------+
//| IDHG_TestsPhase3.mqh — Self-test PHASE 3 (Order Manager, thuần)  |
//| Không gửi lệnh: kiểm tra phân loại retcode, filling, kiểm tra    |
//| trước khi gửi, dựng request mở/đóng.                             |
//+------------------------------------------------------------------+
#ifndef IDHG_TESTS_PHASE3_MQH
#define IDHG_TESTS_PHASE3_MQH

#include "IDHG_TestsPhase2.mqh"
#include "..\IDHG_Order.mqh"

void T3_Market(SIdhgMarket &mk, const double bid, const double ask)
  {
   mk.Reset();
   mk.bid = bid;
   mk.ask = ask;
   mk.mid = (bid + ask) / 2.0;
   mk.spread = ask - bid;
   mk.valid = true;
  }

void T3_Candidate(SIdhgCandidate &c, const ENUM_IDHG_SIDE side, const int level, const double price, const double lot)
  {
   c.Reset();
   c.side = side;
   c.cycleId = 3;
   c.levelId = level;
   c.logicalPrice = price;
   c.distance = 10;
   c.lot = lot;
   c.direction = IdhgSideDir(side);
   c.status = IDHG_LVL_CROSSED;
   c.isInitial = (level == 0);
  }

void IdhgTestPhase3_Retcode(void)
  {
   T_Begin("P3.RETCODE");
   T_Check(IdhgIsSuccessRetcode(TRADE_RETCODE_DONE) && IdhgIsSuccessRetcode(TRADE_RETCODE_PLACED), "DONE/PLACED = thành công");
   T_Check(!IdhgIsSuccessRetcode(TRADE_RETCODE_REJECT), "REJECT ≠ thành công");
   T_Check(IdhgIsTransientRetcode(TRADE_RETCODE_REQUOTE) && IdhgIsTransientRetcode(TRADE_RETCODE_PRICE_CHANGED) &&
           IdhgIsTransientRetcode(TRADE_RETCODE_TIMEOUT), "REQUOTE/PRICE_CHANGED/TIMEOUT = tạm thời");
   T_Check(!IdhgIsTransientRetcode(TRADE_RETCODE_NO_MONEY) && !IdhgIsTransientRetcode(TRADE_RETCODE_REJECT),
           "NO_MONEY/REJECT không retry");
   T_Check(IdhgReasonFromRetcode(TRADE_RETCODE_NO_MONEY) == IDHG_R_SKIPPED_MARGIN, "NO_MONEY → SKIPPED_MARGIN");
   T_Check(IdhgReasonFromRetcode(TRADE_RETCODE_REJECT) == IDHG_R_SKIPPED_BROKER_ERROR, "REJECT → SKIPPED_BROKER_ERROR");
   T_Check(IdhgReasonFromRetcode(TRADE_RETCODE_MARKET_CLOSED) == IDHG_R_SKIPPED_BROKER_ERROR, "MARKET_CLOSED → SKIPPED_BROKER_ERROR");
   T_Check(IdhgReasonFromRetcode(TRADE_RETCODE_TRADE_DISABLED) == IDHG_R_SKIPPED_TRADE_DISABLED, "TRADE_DISABLED → SKIPPED_TRADE_DISABLED");
   T_Check(IdhgSelectFilling(SYMBOL_FILLING_FOK | SYMBOL_FILLING_IOC) == ORDER_FILLING_FOK, "Filling: FOK ưu tiên");
   T_Check(IdhgSelectFilling(SYMBOL_FILLING_IOC) == ORDER_FILLING_IOC, "Filling: IOC");
   T_Check(IdhgSelectFilling(0) == ORDER_FILLING_RETURN, "Filling: RETURN");
  }

void IdhgTestPhase3_PreTrade(void)
  {
   T_Begin("P3.PRETRADE");
   SIdhgSymbolSpec spec;
   IdhgTestSpec(spec);
   SIdhgMarket mk;
   T3_Market(mk, 5000.00, 5000.20);
   SIdhgAccountSnap acc;
   acc.Reset();
   acc.valid = true;
   acc.freeMargin = 1000;
   SIdhgCandidate c;
   T3_Candidate(c, IDHG_BUY, 1, 5010, 0.01);
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 50, 1.0, 0) == IDHG_R_NONE, "Hợp lệ");
   T3_Market(mk, 5000.00, 5001.50);
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 50, 1.0, 0) == IDHG_R_SKIPPED_SPREAD, "Spread 1.5 > MaxSpread 1.0 → SKIPPED_SPREAD");
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 50, 0.0, 0) == IDHG_R_NONE, "MaxSpread = 0 → không giới hạn");
   T3_Market(mk, 5000.00, 5000.20);
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 1500, 1.0, 0) == IDHG_R_SKIPPED_MARGIN, "Margin cần > free → SKIPPED_MARGIN");
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, -1, 1.0, 0) == IDHG_R_NONE, "Không tính được margin → để OrderCheck quyết định");
   c.lot = 0.015;
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 50, 1.0, 0) == IDHG_R_SKIPPED_VOLUME, "Lot sai step → SKIPPED_VOLUME");
   c.lot = 0.01;
   spec.volLimit = 0.5;
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 50, 1.0, 0.5) == IDHG_R_SKIPPED_VOLUME, "Vượt SYMBOL_VOLUME_LIMIT → SKIPPED_VOLUME");
   spec.volLimit = 0;
   c.reason = IDHG_R_SKIPPED_VOLUME;
   T_Check(IdhgPreTradeCheck(c, mk, spec, acc, 50, 1.0, 0) == IDHG_R_SKIPPED_VOLUME, "Candidate đã có lý do → giữ lý do");
  }

void IdhgTestPhase3_Request(void)
  {
   T_Begin("P3.REQUEST");
   SIdhgSymbolSpec spec;
   IdhgTestSpec(spec);
   spec.fillingMode = SYMBOL_FILLING_IOC;
   SIdhgMarket mk;
   T3_Market(mk, 5000.00, 5000.20);
   SIdhgCandidate c;
   T3_Candidate(c, IDHG_BUY, 0, 5000.10, 0.02);
   MqlTradeRequest r;
   IdhgBuildOpenRequest(c, mk, spec, 777, "DHG", 25, r);
   T_Check(r.action == TRADE_ACTION_DEAL && r.type == ORDER_TYPE_BUY, "BUY market");
   T_Near(r.price, 5000.20, 1e-9, "BUY mở theo ASK");
   T_Check(r.magic == 777 && r.deviation == 25 && IdhgEQ(r.volume, 0.02), "Magic / Deviation / Volume");
   T_Check(r.sl == 0.0 && r.tp == 0.0, "Không SL/TP phía broker");
   T_Check(r.type_filling == ORDER_FILLING_IOC, "Filling theo symbol");
   T_EqStr(r.comment, "DHG|C003|BUY|L000|5000.10", "Comment theo CycleID/Side/Level/giá logic");
   T3_Candidate(c, IDHG_SELL, 2, 4980.00, 0.01);
   IdhgBuildOpenRequest(c, mk, spec, 777, "DHG", 25, r);
   T_Check(r.type == ORDER_TYPE_SELL && IdhgEQ(r.price, 5000.00), "SELL mở theo BID");
   IdhgBuildCloseRequest(12345, IDHG_BUY, 0.03, mk, spec, 777, 25, "DHG|X|BTP", r);
   T_Check(r.type == ORDER_TYPE_SELL && r.position == 12345 && IdhgEQ(r.price, 5000.00) && IdhgEQ(r.volume, 0.03),
           "Đóng BUY = SELL theo BID, đúng position + volume");
   IdhgBuildCloseRequest(12346, IDHG_SELL, 0.01, mk, spec, 777, 25, "DHG|X|BTP", r);
   T_Check(r.type == ORDER_TYPE_BUY && IdhgEQ(r.price, 5000.20), "Đóng SELL = BUY theo ASK");
  }

void IdhgRunPhase3Tests(void)
  {
   IdhgTestPhase3_Retcode();
   IdhgTestPhase3_PreTrade();
   IdhgTestPhase3_Request();
  }

#endif
