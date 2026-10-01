# PHASE 3 REPORT — ORDER MANAGER

## 1. FILES CREATED / MODIFIED
- NEW `IDHG_Order.mqh` — `COrderManager` + các hàm thuần (phân loại retcode, filling, kiểm tra trước khi gửi, dựng request)
- NEW `IDHG_Engine.mqh` — `CIdhgEngine`: bộ điều phối sự kiện. Nối Grid → OrderManager → Grid/Cycle, chứa lệnh START.
- MOD `IndependentDynamicHedgeGridEA.mq5` — chỉ chuyển sự kiện (OnInit/OnTick/OnTimer/OnTradeTransaction) cho engine. Phần preflight của Phase 1 chuyển vào `CIdhgEngine::Init`, hành vi giữ nguyên (TEST 14 vẫn PASS).
- MOD `IDHG_Utils.mqh` — `CIdhgLog::Info/Warn` thành const.
- NEW `Tests/IDHG_TestsPhase3.mqh`, `Scripts/IDHG/IDHG_Phase3_SelfTest.mq5` (chỉ OrderCheck, không OrderSend)
- Host: `mql5_broker_sim.h` (broker giả lập: OrderSend/OrderCheck/OrderCalcMargin, positions, deals, history orders, transactions, reject queue, async, foreign positions), `host_tests_phase3.h`

## 2. FUNCTIONS CREATED
IdhgIsSuccessRetcode, IdhgIsTransientRetcode, IdhgReasonFromRetcode, IdhgSelectFilling, IdhgPreTradeCheck, IdhgBuildOpenRequest, IdhgBuildCloseRequest; COrderManager::{Configure, SendOpen, OnTransaction, CheckPending, ClosePosition, CloseProfitable, CloseSide, CloseAll, FindPositionForLevel, HasPendingOpen, IsClosing, OnPositionGone}; CIdhgEngine::{Init, StartCycle, RunEntries, ExecuteCandidates, ApplyEvent, EntryPermissions, OnTick, OnTimer, OnTradeTransaction, Command}.

## 3. LOGIC IMPLEMENTED
- Luồng: Grid trả candidate → Engine gọi `MarkInitialSending` (với initial) + `grid.MarkSending` → `COrderManager::SendOpen` → event → Grid/Cycle cập nhật.
- Kiểm tra trước khi gửi, theo thứ tự: chống trùng (request đang chờ / position có comment cùng Cycle+Side+Level) → quyền giao dịch (terminal, EA, tài khoản, trade mode symbol) → spread (MaxSpread theo giá, 0 = tắt) → volume (step / min / max / SYMBOL_VOLUME_LIMIT) → margin (OrderCalcMargin so với free margin) → OrderCheck.
- Request: market DEAL, BUY theo Ask / SELL theo Bid, deviation từ input, filling theo SYMBOL_FILLING_MODE, KHÔNG SL/TP, comment `DHG|Cxxx|SIDE|Lxxx|giá`.
- Chỉ coi là OPEN khi có deal IN thật (đọc từ history: DEAL_POSITION_ID, DEAL_PRICE). Nếu OrderSend DONE nhưng chưa có deal → giữ SENDING, chờ OnTradeTransaction hoặc đối soát (OnTimer: history deal theo order → trạng thái order bị huỷ → quá hạn 3× timeout chỉ báo FAILED sau khi xác nhận không có position).
- Reject: lỗi tạm thời (REQUOTE/PRICE_CHANGED/…) thử lại tối đa `MaxSendAttempts`, sau đó SKIPPED_BROKER_ERROR; lỗi không tạm thời → SKIPPED ngay, lưu lý do + retcode. Không bao giờ tính vào ĐÃ RẢI.
- Đóng lệnh: mỗi ticket chỉ có 1 lệnh đóng đang chờ; OrderSend DONE chưa có nghĩa là đã đóng — chỉ CLOSED khi có deal OUT. Hết timeout mà position vẫn còn thì cho phép gửi lại. Không đụng lệnh tay / EA khác / symbol khác.

## 4. REQUIREMENTS VERIFIED
II (BUY theo Ask, SELL theo Bid), V ("ĐÃ RẢI" chỉ tăng khi broker xác nhận), XX (chống trùng initial + level, kể cả khi OnTick chạy nhiều lần lúc đang chờ), XXI, XXII, XXIII, I.17/18, TEST 15, TEST 2 (thực thi).

## 5. SELF-TEST RESULTS
| Bộ test | Kết quả |
|---|---|
| P3.RETCODE / PRETRADE / REQUEST (thuần, chạy cả trong MT5) | PASS |
| P3.HOST.START (initial BUY+SELL, Ref, Ask/Bid, chống START trùng) | PASS |
| P3.HOST.GAP execution (BUY + SELL, gần → xa) | PASS |
| P3.HOST.SPREAD/MARGIN/REJECT — TEST 15 | PASS |
| P3.HOST.TRANSIENT RETRY (giới hạn lần thử) | PASS |
| P3.HOST.ASYNC CONFIRM / DUPLICATE / mất transaction / broker huỷ | PASS |
| P3.HOST.CLOSE (đóng trùng, xác nhận deal OUT, không đụng lệnh ngoài) | PASS |
| P3.HOST.SIDE OFF | PASS |
| Hồi quy Phase 1 + 2 | PASS |
| **Tổng host** | **PASS=281 FAIL=0** |

## 6. COMPILE RESULT
- MetaEditor: **COMPILE NOT VERIFIED — MetaEditor unavailable**.
- Host harness: lint PASS, clang `-Werror` (gồm cảnh báo chuyển kiểu) PASS, g++ + ASan/UBSan PASS.

## 7. KNOWN ISSUES
- Broker giả lập không phải broker thật. Các trường hợp như requote thật, partial fill, hay comment bị broker ghi đè cần được kiểm tra thêm trên tài khoản DEMO.
- Partial fill (DONE_PARTIAL): deal IN đầu tiên được dùng để xác nhận, với volume thực tế lấy từ deal. Chưa có test riêng cho trường hợp này.
- Gửi lệnh trong `ExecuteCandidates` là tuần tự: khi gap lớn với OPEN_ALL_CROSSED sẽ có nhiều lệnh gửi trong cùng một tick (đúng đặc tả).

## 8. REMAINING WORK
Phase 4 → 10.

## 9. NEXT PHASE
PHASE 4 — POSITION + CYCLE + RECOVERY.
