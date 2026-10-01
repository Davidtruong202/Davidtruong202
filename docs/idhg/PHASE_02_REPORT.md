# PHASE 2 REPORT — GRID ENGINE

## 1. FILES CREATED / MODIFIED
- NEW `MQL5/Experts/IDHG/IDHG_Grid.mqh` — `CGridSide` (một phía), `CGridEngine` (2 phía độc lập + config ACTIVE)
- NEW `MQL5/Experts/IDHG/Tests/IDHG_TestsPhase2.mqh`, `MQL5/Scripts/IDHG/IDHG_Phase2_SelfTest.mq5`
- MOD `Tests/IDHG_TestsAll.mqh` (thêm hồi quy Phase 2), `tools/mql5_host/mql5_shim.h` (mảng động dùng deque — tránh vector<bool>)
- Phase 1 không đổi.

## 2. FUNCTIONS CREATED
IdhgGridDistance, IdhgGridLotRaw, IdhgLevelCrossed; CGridSide::{Init, Evaluate, InitialCandidate, PeekNext, MarkSending, MarkOpen, MarkClosed, MarkSkipped, MarkFailed, RevertSending, RestoreLevel, RestoreNextLevel, InitForRestore, CountStatus, CountOpenedEvents, CountClosedEvents, TheoreticalLevels, CountReason, FindByTicket}; CGridEngine::{StartCycle, ApplyConfig, InitialCandidates, Evaluate, …wrapper theo phía…}.

## 3. LOGIC IMPLEMENTED
- Level 0 = ReferencePrice (initial). BUY level i = level(i-1) + d(i); SELL level i = level(i-1) − d(i). Giá normalize theo tick size.
- d(i): FIXED = Base; MULTIPLIER = Base·Mult^(i−1); ADDITIVE = Base + Step·(i−1); kẹp trong [Min, Max] (0 = tắt); nhỏ hơn tick size thì lấy tick size.
- Crossed: BUY khi Mid ≥ level, SELL khi Mid ≤ level. Mid cùng hệ quy chiếu với ReferencePrice.
- Gap (vượt >1 level trong 1 lần đánh giá): OPEN_ALL_CROSSED (gần → xa) / OPEN_LATEST_ONLY (các level còn lại SKIPPED_GAP_MODE) / SKIP_CROSSED (tất cả SKIPPED_GAP_MODE). Vượt đúng 1 level là bước bình thường ở mọi mode.
- Bị chặn vào lệnh (PAUSE/STOP_GRID/side OFF/risk…): level bị vượt → SKIPPED kèm lý do, không backfill.
- Lot = BaseLot·LotMult^i (mặc định 1.0); normalize xuống theo step, kẹp Min/MaxLot.
- Level đã tạo cố định giá/khoảng/lot. Config mới (APPLY) chỉ áp dụng cho level tương lai.
- Reopen (mặc định tắt): chỉ áp dụng cho level CLOSED, cần giá quay về rồi vượt lại; SKIPPED không bao giờ backfill.
- Grid Engine không gọi OrderSend; chỉ trả `SIdhgCandidate[]` (Side, CycleID, LevelID, LogicalPrice, Distance, Lot, Direction, Status, Reason).

## 4. REQUIREMENTS VERIFIED
III, IV, V (status), VI, VII, XXIII, TEST 1, TEST 2, TEST 3, TEST 7 (mức grid: SKIPPED_MAX_ORDERS không retry), TEST 15 (mức grid: reject không tính ĐÃ RẢI), TEST 16.

## 5. SELF-TEST RESULTS
| Bộ test | Kết quả |
|---|---|
| P2.DISTANCE — TEST 3 | PASS |
| P2.TEST1 BUY/SELL levels | PASS |
| P2.TEST2 GAP (3 mode, cả BUY và SELL) | PASS |
| P2.BLOCK / TEST 7 mức grid | PASS |
| P2.LOT | PASS |
| P2.TEST16 APPLY GRID CHANGES | PASS |
| P2.LEVEL_STATE (chống trùng, idempotent, reject/retry/skip) | PASS |
| P2.REOPEN | PASS |
| P2.INDEPENDENCE (+ giới hạn vòng lặp) | PASS |
| Hồi quy Phase 1 | PASS |
| **Tổng host** | **PASS=192 FAIL=0** |

## 6. COMPILE RESULT
- MetaEditor: **COMPILE NOT VERIFIED — MetaEditor unavailable**.
- Host harness: lint MQL5 PASS, clang `-Werror -Wfloat-conversion -Wshorten-64-to-32` PASS, g++ + ASan/UBSan PASS.

## 7. KNOWN ISSUES
- Crossed dùng giá Mid (đặc tả không nói rõ BUY dùng Ask hay Bid để kích hoạt). Lựa chọn này nhất quán với ReferencePrice = Mid.
- "Gap" được định nghĩa là vượt nhiều hơn 1 level trong một lần đánh giá giá.

## 8. REMAINING WORK
Phase 3 → 10.

## 9. NEXT PHASE
PHASE 3 — ORDER MANAGER.
