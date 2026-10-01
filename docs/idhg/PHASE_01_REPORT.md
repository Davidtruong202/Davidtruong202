# PHASE 1 REPORT — CORE ARCHITECTURE

## 1. FILES CREATED / MODIFIED
- `MQL5/Experts/IDHG/IDHG_Types.mqh` — enum + struct dùng chung (side, distance/gap mode, level status, reason, state, emergency, capacity, command; SymbolSpec, AccountSnap, Market, Level, Candidate, Position, Deal, CommentInfo)
- `MQL5/Experts/IDHG/IDHG_Utils.mqh` — PriceNormalize, TickSizeNormalize, LotNormalize, GetNetPL, GetSpread, comment build/parse, margin ước tính hedged, broker checks, log có giới hạn, đọc symbol/account/market thật
- `MQL5/Experts/IDHG/IDHG_Config.mqh` — các struct cấu hình + `CConfig` (Load / Validate / SetPending / ApplyPending / DiscardPending / Summary)
- `MQL5/Experts/IDHG/IDHG_Inputs.mqh` — toàn bộ input (nhóm theo module) + `IdhgConfigFromInputs`
- `MQL5/Experts/IDHG/IDHG_State.mqh` — `CState` (máy trạng thái + AllowNewEntries/AllowProfitLogic/AllowRiskLogic)
- `MQL5/Experts/IDHG/IDHG_Cycle.mqh` — `CCycleManager` (CycleID, ReferencePrice=Mid, MarkInitialSending/ConfirmInitial/FailInitial, RESET LOGIC)
- `MQL5/Experts/IDHG/IndependentDynamicHedgeGridEA.mq5` — khung EA: kiểm tra HEDGING, symbol, cấu hình. KHÔNG gửi lệnh.
- `MQL5/Experts/IDHG/Tests/IDHG_TestFramework.mqh`, `IDHG_TestsPhase1.mqh`, `IDHG_TestsAll.mqh`
- `MQL5/Scripts/IDHG/IDHG_Phase1_SelfTest.mq5` — script self-test chạy trong MT5 (chỉ đọc)
- `tools/mql5_host/*` — host harness (lint MQL5 → transpile → clang/g++ → chạy test)

## 2. FUNCTIONS CREATED
PriceNormalize, TickSizeNormalize, LotNormalize, GetNetPL, GetSpread, IdhgIsHedgingMode, IdhgBuildComment, IdhgParseComment, IdhgEstimateHedgedMargin, IdhgCheckSymbolSpec, IdhgReadSymbolSpec, IdhgReadAccount, IdhgReadMarket, IdhgTradePermitted, IdhgValidate{Grid,Profit,Risk,Capacity,General}, IdhgGridConfigEquals, CConfig::{Load,Validate,SetPending,ApplyPending,DiscardPending,Summary}, CState::{Start,Pause,Resume,StopGrid,ResumeGrid,EndCycle,ResetLogic,Restore}, CCycleManager::{CanStart,Begin,Restore,CanResetLogic,ResetLogic,MarkInitialSending,ConfirmInitial,FailInitial}, CIdhgLog.

## 3. LOGIC IMPLEMENTED
- Bảng cờ trạng thái đúng mục XXVIII: RUNNING T/T/T, PAUSED F/F/T, STOP_GRID F/T/T, IDLE và CYCLE_ENDED F/T/T.
- ReferencePrice = (Ask+Bid)/2, normalize theo tick size + digits; lưu thêm Ask và Bid tham chiếu.
- CycleID không bao giờ dùng lại (tiếp nối sau ID lớn nhất đã thấy trong lịch sử).
- Initial BUY/SELL chống trùng (đang SENDING hoặc đã CONFIRMED → không gửi lại); FAILED thì cho thử lại.
- Comment `DHG|C001|BUY|L005|5010.00` (≤31 ký tự; nếu dài hơn thì bỏ phần giá). Parse nghiêm ngặt, không đoán. Giá bị cắt → giữ ID, không dùng giá.
- Lot: làm tròn XUỐNG theo step, kẹp trong [max(VolMin, MinLot), min(VolMax, MaxLot)].
- Thông số grid chỉ đổi qua pending → APPLY.

## 4. REQUIREMENTS VERIFIED
I.15/16 (normalize), I.19 + TEST 14 (NETTING → INIT_FAILED), II (Reference), V (comment/ID), VII (LotMultiplier mặc định 1.0), XI (cycle/reset), XX (chống trùng initial), XXVII (pending config), XXVIII (state machine), XIV (EmergencyAction mặc định STOP_NEW_ENTRIES).

## 5. SELF-TEST RESULTS
| Bộ test | Kết quả |
|---|---|
| P1.HEDGING (3) | PASS |
| P1.SYMBOL (4) | PASS |
| P1.UTILS (16) | PASS |
| P1.COMMENT (15) | PASS |
| P1.CONFIG (14) | PASS |
| P1.PENDING_CONFIG (13) | PASS |
| P1.STATE_MACHINE (22) | PASS |
| P1.CYCLE (19) | PASS |
| P1.HOST.ONINIT — TEST 14 (6) | PASS |
| **Tổng** | **PASS=109 FAIL=0** |

Đã kiểm chứng harness bắt lỗi thật: cố ý sửa sai một assert → FAIL=1; cố ý truyền struct theo giá trị → MQL5 LINT FAIL.

## 6. COMPILE RESULT
- **MetaEditor (MQL5): COMPILE NOT VERIFIED — MetaEditor unavailable** (các host download của MetaQuotes bị network policy chặn).
- Host harness: lint MQL5 PASS; `clang++ -Wall -Wextra -Werror -Wfloat-conversion -Wshorten-64-to-32` PASS; `g++ -Werror` + ASan/UBSan build PASS; chạy PASS.

## 7. KNOWN ISSUES
- Chưa compile bằng MetaEditor thật. Harness bắt được phần lớn lỗi kiểu và các điểm không tương thích MQL5 đã biết, nhưng KHÔNG thay thế được MetaEditor.
- Comment lệnh phụ thuộc broker: có broker ghi đè comment → recovery sẽ báo RECOVERY WARNING (Phase 4).

## 8. REMAINING WORK
Phase 2 → 10.

## 9. NEXT PHASE
PHASE 2 — GRID ENGINE.
