//+------------------------------------------------------------------+
//|                                              StochIchiMikEA.mq5  |
//|  EA kết hợp 3 chỉ báo, CẢ 3 PHẢI ĐỒNG THUẬN mới vào lệnh:          |
//|   1) Stochastic vùng cực trị (giống StochZoneEA) -- tín hiệu       |
//|      CHÍNH, quyết định THỜI ĐIỂM và HƯỚNG ứng viên vào lệnh.        |
//|   2) Ichimoku Chikou vs Span B (giống IchimokuChikouEA) -- xác     |
//|      nhận hướng xu hướng hiện tại có đồng ý với hướng ứng viên.     |
//|   3) MIK EmaCross (EMA9 vs EMA20 trên giá + EMA9 vs WMA45 trên     |
//|      RSI14, y hệt logic gốc của MIK_EmaCross_Signal.mq5, TỰ TÍNH   |
//|      TAY lại trong EA này -- KHÔNG gọi iCustom() tới indicator đó, |
//|      tránh mọi rủi ro về buffer/shift/input-group-slot đã gặp      |
//|      trước đây trong session) -- xác nhận hướng thứ 2.             |
//|                                                                    |
//|  LOGIC KẾT HỢP:                                                    |
//|   - Stochastic %K chạm vùng SELL (mặc định 92-95) -> ứng viên      |
//|     SELL; chạm vùng BUY (mặc định 5-8) -> ứng viên BUY. Y HỆT cơ   |
//|     chế "armed" chống whipsaw của StochZoneEA (InpZoneExitBuffer). |
//|   - CHỈ THỰC SỰ vào lệnh khi CẢ Ichimoku (Chikou đang ở phía SELL/  |
//|     BUY so với Span B) VÀ MIK (EMA9/EMA20 + RSI-EMA/RSI-WMA đang ở |
//|     trạng thái SELL/BUY) đều đồng ý với hướng ứng viên. Nếu Stoch   |
//|     vẫn còn trong vùng mà chưa đủ 3/3 đồng thuận, EA tiếp tục kiểm  |
//|     tra mỗi tick cho tới khi đủ đồng thuận hoặc giá rời khỏi vùng.  |
//|                                                                    |
//|  SL/TP/trailing/hòa vốn sớm/chống whipsaw/cooldown/dashboard/       |
//|  Telegram/nút Test: TÁI SỬ DỤNG NGUYÊN VẸN toàn bộ hạ tầng đã       |
//|  kiểm chứng của StochZoneEA (không đổi logic quản lý lệnh).         |
//|                                                                    |
//|  Không có trình biên dịch MQL5 thật trong môi trường này -- code   |
//|  này CHƯA được compile/chạy thử thực tế. Đã tự kiểm tra cân bằng   |
//|  ngoặc/dấu ngoặc bằng script riêng trước khi giao.                 |
//|                                                                    |
//|  NHẬT KÝ THAY ĐỔI:                                                 |
//|   v1.00: Bản đầu tiên -- ghép Stochastic (StochZoneEA) + Ichimoku  |
//|          (IchimokuChikouEA) + MIK EmaCross (tự tính tay lại),      |
//|          yêu cầu cả 3 đồng thuận mới vào lệnh.                      |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== 1. Stochastic (dùng iStochastic gốc MT5) ==="
input int               InpStochKPeriod   = 100;           // Chu kỳ %K -- mặc định 100 (chậm, mượt), theo đúng bộ số đã backtest ở StochZoneEA
input int               InpStochDPeriod   = 3;              // Chu kỳ %D
input int               InpStochSlowing   = 3;               // Độ làm mượt (slowing)
input ENUM_MA_METHOD    InpStochMAMethod  = MODE_SMA;        // Phương pháp trung bình
input ENUM_STO_PRICE    InpStochPriceField = STO_LOWHIGH;    // Trường giá dùng để tính (Low/High hoặc Close/Close)

input group "=== 2. Vùng cực trị vào lệnh ==="
input double InpSellZoneLow  = 92.0; // Cạnh dưới vùng SELL (quá mua)
input double InpSellZoneHigh = 95.0; // Cạnh trên vùng SELL (quá mua)
input double InpBuyZoneLow   = 5.0;  // Cạnh dưới vùng BUY (quá bán)
input double InpBuyZoneHigh  = 8.0;  // Cạnh trên vùng BUY (quá bán)

enum ENUM_TP_MODE
{
   TP_MODE_STOCH_LEVEL      = 0, // [Cách A] TP1 theo mức Stochastic (mặc định gốc)
   TP_MODE_FIXED_RR         = 1, // [Cách B] TP cố định theo tỷ lệ R:R, đóng gọn 1 lần
   TP_MODE_FIXED_PRICE_LEGS = 2  // [Cách C] TP1 + TP2 theo khoảng cách giá cố định (2 chân, có trailing SL)
};

input group "=== 3. Chốt lời -- chọn 1 trong 3 cách ==="
input ENUM_TP_MODE InpTpMode    = TP_MODE_STOCH_LEVEL; // Chọn cách chốt lời (xem 3 mục input bên dưới, mỗi cách chỉ dùng đúng nhóm input của nó)
input double InpTpRRRatio       = 2.0;   // [Cách B] TP đặt cách giá vào 1 khoảng = khoảng cách SL nhân tỷ lệ này (vd 2.0 = TP 2R), đặt thẳng vào lệnh, đóng gọn 1 lần khi chạm
input double InpMinTpDistanceUSD = 1.0;  // [Cách B] Khoảng cách TP TỐI THIỂU ($ price distance) -- chỉnh lại nếu quy ước pip của broker khác. TP thực tế = MAX(2R, giá trị này). 0 = tắt, chỉ dùng đúng 2R
input double InpTp1StochLevel   = 50.0; // [Cách A] Mức Stochastic để đóng TP1 (mặc định vùng giữa)
input double InpTp1ClosePercent = 50.0; // [Cách A + Cách C] % khối lượng đóng ở TP1 (phần còn lại sẽ trailing)
input double InpTp1DistanceUSD  = 10.0; // [Cách C] TP1 cách giá vào lệnh bao nhiêu $ price distance
input double InpTp2DistanceUSD  = 20.0; // [Cách C] TP2 (mục tiêu cuối cho phần lệnh còn lại sau TP1) cách giá vào lệnh bao nhiêu $ price distance. Đặt thẳng làm TP thật ở broker cho phần còn lại, đồng thời vẫn trailing SL theo nhóm 8 -- cái nào chạm trước thì đóng theo cái đó

input group "=== 4. Stop Loss -- chọn 1 trong 2 cách ==="
input bool   InpUseRangeSl     = false; // true: SL = đỉnh/đáy của N cây nến gần nhất TRƯỚC nến vào lệnh (mục 4a); false: SL theo đáy/đỉnh tương đối fractal (mục 4b, mặc định gốc)
input int    InpSlRangeBars    = 100;   // [4a] Chỉ dùng khi InpUseRangeSl=true -- số cây nến lùi về quá khứ để tìm đỉnh/đáy làm SL
input int    InpFractalBars    = 2;     // [4b] Chỉ dùng khi InpUseRangeSl=false -- số nến 2 bên (trái/phải) phải cao/thấp hơn để tính là 1 đáy/đỉnh tương đối
input int    InpMaxSwingSearch = 300;   // [4b] Chỉ dùng khi InpUseRangeSl=false -- số nến tối đa lùi về quá khứ để tìm đáy/đỉnh tương đối gần nhất
input double InpSlBufferAtr    = 0.0;   // Dùng chung cho cả 2 cách -- đệm thêm ra ngoài đáy/đỉnh theo bội số ATR (tùy chọn, mặc định TẮT). 0 = tắt
input double InpSlBufferUSD    = 0.3;   // Dùng chung cho cả 2 cách -- đệm thêm CỐ ĐỊNH ($ price distance, không phụ thuộc ATR) ra ngoài đáy/đỉnh. Cộng dồn với InpSlBufferAtr nếu cả 2 cùng bật. 0 = tắt

input group "=== 5. Quản lý lệnh ==="
input ulong  InpMagic        = 20260922;
input double InpSlippageUSD  = 0.30;
input double InpMaxSpreadUSD = 0.0; // Bỏ qua vào lệnh mới nếu spread > giá trị này ($ price distance). 0 = tắt

input group "=== 6. Khối lượng lệnh theo % RISK ==="
input bool   InpUseRiskPercent = true;  // true: tự tính lot theo % Balance (khuyến nghị); false: dùng InpLotSize cố định
input double InpRiskPercent    = 2.0;   // % Balance chấp nhận mất nếu dính đúng SL
input double InpLotSize        = 0.01;  // Lot cố định, dùng khi InpUseRiskPercent=false hoặc khi thiếu dữ liệu để tính risk%
input double InpMaxLotCap      = 1.0;   // Chặn lot tối đa (an toàn)

input group "=== 7. Tự động DỪNG VÀO LỆNH MỚI khi lỗ quá ngưỡng trong ngày ==="
input bool   InpUseDailyLossLimit = true;
input double InpMaxDailyLossUSD   = 15.0;

input group "=== 8. Hòa vốn SỚM (trước khi chạm TP1) khi lời đạt 1 mức nhất định ==="
input bool   InpUseEarlyBreakeven  = true; // Bật/tắt dời SL về giá vào lệnh NGAY khi lời đủ, không cần đợi TP1
input double InpEarlyBreakevenSlMult = 1.0; // Lời tối thiểu = khoảng cách SL nhân hệ số này (mặc định 1.0 = tỷ lệ 1:1) thì dời SL về hòa vốn

input group "=== 8b. Trailing SL sau khi chốt TP1 (bảo toàn phần lệnh còn lại) ==="
input bool   InpMoveToBreakevenOnTp1 = true; // Dời SL phần lệnh còn lại về hòa vốn ngay khi TP1 đóng xong
input bool   InpUseTrailingAfterTp1  = true; // Bật/tắt trailing SL cho phần lệnh còn lại sau khi đã hòa vốn
input double InpTrailStartAtr        = 0.5;  // Lãi nổi tối thiểu thêm (bội số ATR) tính từ lúc hòa vốn để bắt đầu siết SL
input double InpTrailDistanceAtr     = 0.75; // Khoảng cách giữ giữa SL mới và giá hiện tại (bội số ATR)
input double InpTrailStepAtr         = 0.1;  // Bước tối thiểu (bội số ATR) để dời SL 1 lần, tránh sửa SL liên tục

input group "=== 9. Thoát hẳn phần lệnh còn lại khi Stoch chạm vùng đối lập ==="
input bool InpUseOppositeZoneExit = true; // vd lệnh Sell (vào ở vùng trên) sẽ đóng hẳn khi Stoch rơi xuống chạm vùng Buy phía dưới, và ngược lại

input group "=== 10. Telegram - thông báo trực tiếp, 1 lớp duy nhất ==="
input string InpTgBotToken = ""; // Token của Bot Telegram -- để trống "" nếu không dùng Telegram
input long   InpTgChatId   = 0;  // ID của group/chat nhận thông báo -- để 0 nếu không dùng Telegram
input int    InpTgTopicId  = 0;  // ID của Topic (nếu group có bật Forum Topics) -- để 0 nếu không dùng Topic

input group "=== 11. Bảng trạng thái + nút Test trên chart ==="
input bool InpShowDashboard   = true; // Hiện/ẩn bảng trạng thái (dashboard) ở góc trái chart
input bool InpShowTestButtons = true; // Hiện/ẩn 3 nút Test (Test TG / Test BUY / Test SELL) trên chart

input group "=== 12. Chống whipsaw (giá dập dình ngay mép vùng) ==="
input double InpZoneExitBuffer          = 5.0;  // Stochastic phải rời XA vùng hơn giá trị này thì tín hiệu mới được "nạp lại" cho lần chạm kế tiếp
input bool   InpUseCooldownAfterLoss    = true;  // Bật/tắt tạm khóa vào lệnh mới (cả 2 hướng) sau khi 1 lệnh vừa đóng LỖ
input int    InpCooldownMinutesAfterLoss = 15;   // Số phút khóa vào lệnh mới sau khi vừa thua 1 lệnh

input group "=== 13. Xác nhận bằng Ichimoku (Chikou vs Span B, đúng công thức IchimokuChikouEA) ==="
input bool InpUseIchimokuConfirm = true; // Bật/tắt yêu cầu Ichimoku đồng thuận hướng trước khi vào lệnh
input int  InpIchiKijunPeriod    = 26;   // Số nến dịch chuyển (N1) -- bội số Kijun chuẩn
input int  InpIchiSenkouBPeriod  = 52;   // Chu kỳ tính Span B (N2) -- mặc định chuẩn

input group "=== 14. Xác nhận bằng MIK EmaCross (tự tính tay, không iCustom) ==="
input bool InpUseMikConfirm    = true; // Bật/tắt yêu cầu MIK EmaCross đồng thuận hướng trước khi vào lệnh
input int  InpMikEma9Period    = 9;    // Chu kỳ EMA9 trên giá (Close)
input int  InpMikEma20Period   = 20;   // Chu kỳ EMA20 trên giá (Close)
input int  InpMikRsiPeriod     = 14;   // Chu kỳ RSI
input int  InpMikRsiEmaPeriod  = 9;    // Chu kỳ EMA áp lên RSI
input int  InpMikRsiWmaPeriod  = 45;   // Chu kỳ WMA áp lên RSI

//====================================================================
// Globals
//====================================================================
int    g_StochHandle = INVALID_HANDLE;
int    g_AtrHandle   = INVALID_HANDLE;
int    g_MikRsiHandle = INVALID_HANDLE;
bool   g_SellArmed = true; // true = sẵn sàng bắn tín hiệu SELL ở lần chạm vùng tiếp theo (chống whipsaw, xem nhóm input 12)
bool   g_BuyArmed  = true; // true = sẵn sàng bắn tín hiệu BUY ở lần chạm vùng tiếp theo
bool   g_Tp1Done       = false; // Đã đóng TP1 cho lệnh đang mở hiện tại chưa
bool   g_TrailingActive = false; // Đã hòa vốn và đang trailing phần lệnh còn lại
bool   g_EarlyBreakevenDone = false; // Đã dời SL về hòa vốn SỚM (trước TP1) cho lệnh đang mở hiện tại chưa

datetime g_DailyLossAlertDay = 0;
datetime g_CooldownUntil     = 0; // Khóa vào lệnh mới (cả 2 hướng) tới thời điểm này sau khi vừa thua 1 lệnh
string   g_lastSignalTxt  = "Chưa có tín hiệu nào";
datetime g_lastSignalTime = 0;

int g_DbgSellOpened = 0, g_DbgBuyOpened = 0, g_DbgTp1Hit = 0, g_DbgOppositeZoneExit = 0;
int g_DbgBlockedSpread = 0, g_DbgBlockedMargin = 0, g_DbgBlockedFreeMargin = 0;
int g_DbgBlockedDailyLoss = 0, g_DbgBlockedNoSwing = 0, g_DbgOrderSendFail = 0;
int g_DbgBlockedIchiConfirm = 0, g_DbgBlockedMikConfirm = 0;

#define DASH_PREFIX "StochIchiMikEA_Dash_"

//====================================================================
// A. Các hàm hỗ trợ thuần túy
//====================================================================
double CurrentBid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double CurrentAsk() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double CurrentSpreadPrice() { return CurrentAsk() - CurrentBid(); }

int PriceDistanceToPoints(double priceDistance)
{
   if (_Point <= 0.0) return 0;
   return (int)MathRound(priceDistance / _Point);
}

double MarginRequiredPerLot(ENUM_ORDER_TYPE type, double price)
{
   double margin = 0.0;
   if (!OrderCalcMargin(type, _Symbol, 1.0, price, margin)) return 0.0;
   return margin;
}

double NormalizeLot(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if (step <= 0) step = 0.01;
   double norm = MathRound(lot / step) * step;
   if (norm < minLot) norm = minLot;
   if (maxLot > 0 && norm > maxLot) norm = maxLot;
   return norm;
}

double CalcRiskLot(double slDistancePrice)
{
   if (slDistancePrice <= 0) return InpLotSize;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0 || tickValue <= 0) return InpLotSize;
   double valuePerPriceUnit = tickValue / tickSize;
   if (valuePerPriceUnit <= 0) return InpLotSize;
   double lot = riskAmount / (slDistancePrice * valuePerPriceUnit);
   return MathMin(NormalizeLot(lot), InpMaxLotCap);
}

//====================================================================
// B. Vị thế của EA này (theo magic+symbol) -- CHỈ 1 lệnh tại 1 thời điểm
//====================================================================
ulong GetOpenPosition(long &outType)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      outType = PositionGetInteger(POSITION_TYPE);
      return ticket;
   }
   outType = -1;
   return 0;
}

//====================================================================
// C. Telegram - thông báo trực tiếp 1 lớp duy nhất (POST + HTML)
//====================================================================
string UrlEncode(const string text)
{
   uchar bytes[];
   int n = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   string result = "";
   for (int i = 0; i < n; i++)
   {
      uchar b = bytes[i];
      if (b == 0) break;
      if ((b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9') ||
          b == '-' || b == '_' || b == '.' || b == '~')
         result += CharToString(b);
      else
         result += StringFormat("%%%02X", b);
   }
   return result;
}

bool TelegramSendMessage(const string text)
{
   if (StringLen(InpTgBotToken) == 0 || InpTgChatId == 0) return false;

   string url = "https://api.telegram.org/bot" + InpTgBotToken + "/sendMessage";
   string body = "chat_id=" + IntegerToString(InpTgChatId) + "&parse_mode=HTML&text=" + UrlEncode(text);
   if (InpTgTopicId > 0)
      body += "&message_thread_id=" + IntegerToString(InpTgTopicId);

   char   post[];
   char   resultData[];
   string resultHeaders;
   StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   int postLen = ArraySize(post);
   if (postLen > 0) ArrayResize(post, postLen - 1);

   ResetLastError();
   int res = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded\r\n", 5000, post, resultData, resultHeaders);
   if (res == -1)
   {
      Print("StochIchiMikEA: gửi Telegram thất bại, lỗi ", GetLastError(),
            " -- kiểm tra đã whitelist https://api.telegram.org trong Tools->Options->Expert Advisors chưa");
      return false;
   }
   return true;
}

//====================================================================
// D. Lãi/lỗ trong ngày theo USD (circuit breaker) -- tính lại TỪ ĐẦU mỗi
// lần gọi, tự động reset khi sang ngày mới.
//====================================================================
double CalcDayProfitUSD()
{
   double total = 0.0;
   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);
   dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
   datetime dayStart = StructToTime(dtNow);
   datetime now = TimeCurrent();

   if (HistorySelect(dayStart, now + 86400))
   {
      int totalDeals = HistoryDealsTotal();
      for (int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if (ticket == 0) continue;
         if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagic) continue;
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
         total += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                  HistoryDealGetDouble(ticket, DEAL_SWAP) +
                  HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

//====================================================================
// E. Đáy/đỉnh tương đối kiểu fractal (2 bên đều thấp/cao hơn) -- dùng
// tìm SL, giống cách làm đã kiểm chứng ở IchimokuChikouEA/StochZoneEA.
//====================================================================
bool IsSwingLow(const double &lowArr[], int idx, int fractalBars, int n)
{
   if (idx - fractalBars < 0 || idx + fractalBars >= n) return false;
   for (int j = 1; j <= fractalBars; j++)
   {
      if (lowArr[idx - j] < lowArr[idx]) return false;
      if (lowArr[idx + j] < lowArr[idx]) return false;
   }
   return true;
}

bool IsSwingHigh(const double &highArr[], int idx, int fractalBars, int n)
{
   if (idx - fractalBars < 0 || idx + fractalBars >= n) return false;
   for (int j = 1; j <= fractalBars; j++)
   {
      if (highArr[idx - j] > highArr[idx]) return false;
      if (highArr[idx + j] > highArr[idx]) return false;
   }
   return true;
}

double FindBuySlFromSwingLows(const double &lowArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit; idx++)
      if (IsSwingLow(lowArr, idx, fractalBars, n)) return lowArr[idx];
   return 0.0;
}

double FindSellSlFromSwingHighs(const double &highArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit; idx++)
      if (IsSwingHigh(highArr, idx, fractalBars, n)) return highArr[idx];
   return 0.0;
}

double CalcSlForDirection(int direction) // 1=Buy (dò đáy làm SL), -1=Sell (dò đỉnh làm SL)
{
   double slPrice = 0.0;

   if (InpUseRangeSl)
   {
      if (direction == 1)
      {
         double lowArr[];
         if (CopyLow(_Symbol, PERIOD_CURRENT, 1, InpSlRangeBars, lowArr) >= InpSlRangeBars)
         {
            int idx = ArrayMinimum(lowArr, 0, WHOLE_ARRAY);
            slPrice = lowArr[idx];
         }
      }
      else
      {
         double highArr[];
         if (CopyHigh(_Symbol, PERIOD_CURRENT, 1, InpSlRangeBars, highArr) >= InpSlRangeBars)
         {
            int idx = ArrayMaximum(highArr, 0, WHOLE_ARRAY);
            slPrice = highArr[idx];
         }
      }
   }
   else
   {
      int needSwing = InpFractalBars + InpMaxSwingSearch + 5;
      int startIdx  = InpFractalBars + 1;

      if (direction == 1)
      {
         double lowArr[];
         ArraySetAsSeries(lowArr, true);
         if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwing, lowArr) >= needSwing)
            slPrice = FindBuySlFromSwingLows(lowArr, ArraySize(lowArr), InpFractalBars, startIdx, InpMaxSwingSearch);
      }
      else
      {
         double highArr[];
         ArraySetAsSeries(highArr, true);
         if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwing, highArr) >= needSwing)
            slPrice = FindSellSlFromSwingHighs(highArr, ArraySize(highArr), InpFractalBars, startIdx, InpMaxSwingSearch);
      }
   }

   if (slPrice > 0)
   {
      double buf = 0.0;
      if (InpSlBufferAtr > 0 && g_AtrHandle != INVALID_HANDLE)
      {
         double atrArr[];
         if (CopyBuffer(g_AtrHandle, 0, 1, 1, atrArr) >= 1)
            buf += InpSlBufferAtr * atrArr[0];
      }
      buf += InpSlBufferUSD;
      if (buf > 0)
         slPrice = (direction == 1) ? (slPrice - buf) : (slPrice + buf);
   }
   return slPrice;
}

//====================================================================
// E2. Xác nhận Ichimoku (Chikou vs Span B) -- đúng công thức đã kiểm
// chứng ở IchimokuChikouEA. RawSpanB(k) = giá trị GỐC (chưa dịch
// chuyển) của Span B tại "k nến trước". Tín hiệu "hôm nay" = so sánh
// CLOSE[1] (nến vừa đóng) với RawSpanB(1 + 2*InpIchiKijunPeriod).
//====================================================================
bool ComputeRawSpanB(int k, double &outValue)
{
   double highArr[], lowArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   int need = k + InpIchiSenkouBPeriod + 2;
   if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, need, highArr) < need) return false;
   if (CopyLow(_Symbol, PERIOD_CURRENT, 0, need, lowArr) < need) return false;

   double hi = highArr[k], lo = lowArr[k];
   for (int j = k + 1; j < k + InpIchiSenkouBPeriod; j++)
   {
      if (highArr[j] > hi) hi = highArr[j];
      if (lowArr[j] < lo) lo = lowArr[j];
   }
   outValue = (hi + lo) / 2.0;
   return true;
}

// Trả về true và outState=1 (Buy)/-1 (Sell) nếu tính được; false nếu thiếu dữ liệu.
bool ComputeIchimokuState(int &outState)
{
   outState = 0;
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   int needClose = 1 + InpIchiKijunPeriod + 5;
   if (CopyClose(_Symbol, PERIOD_CURRENT, 0, needClose, closeArr) < needClose) return false;

   double spanBNow;
   if (!ComputeRawSpanB(1 + 2 * InpIchiKijunPeriod, spanBNow)) return false;

   double closeNow = closeArr[1]; // nến vừa đóng, tránh repaint trên nến đang chạy
   outState = (closeNow > spanBNow) ? 1 : (closeNow < spanBNow) ? -1 : 0;
   return true;
}

//====================================================================
// E3. Xác nhận MIK EmaCross -- TỰ TÍNH TAY lại đúng công thức gốc của
// MIK_EmaCross_Signal.mq5 (EMA9/EMA20 trên Close, EMA9/WMA45 trên
// RSI14), KHÔNG gọi iCustom() tới indicator đó. Tính lại TỪ ĐẦU mỗi
// lần gọi (giống pattern CalcDayProfitUSD), chỉ lấy trạng thái nến
// cuối cùng, không cần vẽ arrow/lịch sử như indicator gốc.
//====================================================================
bool ComputeMikState(int &outState)
{
   outState = 0;
   if (InpMikRsiPeriod <= 0 || InpMikRsiWmaPeriod <= 0) return false;
   if (g_MikRsiHandle == INVALID_HANDLE) return false;

   int need = InpMikRsiPeriod + InpMikRsiWmaPeriod + InpMikEma20Period + 50;

   double closeArr[];
   ArraySetAsSeries(closeArr, false); // chronological: index 0 = cũ nhất, index cuối = mới nhất
   if (CopyClose(_Symbol, PERIOD_CURRENT, 0, need, closeArr) < need) return false;

   double rsiRaw[];
   ArraySetAsSeries(rsiRaw, false);
   if (CopyBuffer(g_MikRsiHandle, 0, 0, need, rsiRaw) < need) return false;

   int n = ArraySize(closeArr);
   if (n < InpMikRsiWmaPeriod) return false;

   double kEma9   = 2.0 / (InpMikEma9Period   + 1.0);
   double kEma20  = 2.0 / (InpMikEma20Period  + 1.0);
   double kRsiEma = 2.0 / (InpMikRsiEmaPeriod + 1.0);

   double ema9 = closeArr[0], ema20 = closeArr[0], rsiEma = rsiRaw[0];
   for (int i = 1; i < n; i++)
   {
      ema9   = closeArr[i] * kEma9  + ema9  * (1.0 - kEma9);
      ema20  = closeArr[i] * kEma20 + ema20 * (1.0 - kEma20);
      rsiEma = rsiRaw[i]   * kRsiEma + rsiEma * (1.0 - kRsiEma);
   }

   int    wn    = InpMikRsiWmaPeriod;
   double sumW  = 0, sumWX = 0;
   for (int k = 0; k < wn; k++)
   {
      double w = (wn - k);
      sumWX += w * rsiRaw[n - 1 - k];
      sumW  += w;
   }
   double rsiWma = sumWX / sumW;

   bool priceBuy  = ema9 > ema20;
   bool priceSell = ema9 < ema20;
   bool rsiBuy    = rsiEma > rsiWma;
   bool rsiSell   = rsiEma < rsiWma;

   if (priceBuy  && rsiBuy)  outState = 1;
   else if (priceSell && rsiSell) outState = -1;
   else outState = 0;
   return true;
}

//====================================================================
// F. Dashboard (OBJ_LABEL + khung nền) và nút Test.
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateTestButton(string name, string text, int x, int y, int w, int h, color bg)
{
   if (ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

void CreateDashboard()
{
   string keys[] = {"Title", "Stoch", "Confirm", "LastSignal", "Position", "DayPL", "Status"};
   int x = 10, y = 16, dy = 16;
   int panelW = 360, panelH = ArraySize(keys) * dy + 14;

   if (InpShowDashboard)
   {
      string bgName = DASH_PREFIX + "BG";
      if (ObjectFind(0, bgName) < 0)
         ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 6);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 8);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelW);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelH);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

      for (int i = 0; i < ArraySize(keys); i++)
      {
         string name = DASH_PREFIX + keys[i];
         if (ObjectFind(0, name) < 0)
            ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + i * dy);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrSilver);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, name, OBJPROP_TEXT, "...");
      }
   }

   if (InpShowTestButtons)
   {
      int by = InpShowDashboard ? ((y - 8) + panelH + 6) : y;
      int bw = 90, bh = 22, gap = 6;
      CreateTestButton(DASH_PREFIX + "BtnTestTg",   "Test TG",   x, by, bw, bh, clrDarkSlateGray);
      CreateTestButton(DASH_PREFIX + "BtnTestBuy",  "Test BUY",  x + (bw + gap), by, bw, bh, clrDarkGreen);
      CreateTestButton(DASH_PREFIX + "BtnTestSell", "Test SELL", x + 2 * (bw + gap), by, bw, bh, clrMaroon);
   }
}

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); }

//====================================================================
// G. Mở lệnh (1 lệnh duy nhất) -- SL theo swing low/high, TP tùy chế độ.
//====================================================================
bool OpenPosition(ENUM_ORDER_TYPE type, double slPrice, bool isTest)
{
   if (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0)
   {
      double dayProfitUSD = CalcDayProfitUSD();
      if (dayProfitUSD <= -MathAbs(InpMaxDailyLossUSD))
      {
         Print("StochIchiMikEA: đã lỗ ", DoubleToString(dayProfitUSD, 2), " ", AccountInfoString(ACCOUNT_CURRENCY),
               " hôm nay, vượt ngưỡng -- TẠM DỪNG vào lệnh MỚI");
         g_DbgBlockedDailyLoss++;

         MqlDateTime dtNow;
         TimeToStruct(TimeCurrent(), dtNow);
         dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
         datetime dayStart = StructToTime(dtNow);
         if (g_DailyLossAlertDay != dayStart)
         {
            g_DailyLossAlertDay = dayStart;
            TelegramSendMessage(StringFormat("⚠️ <b>TẠM DỪNG VÀO LỆNH MỚI</b> — %s\n\nĐã lỗ <b>%.2f %s</b> hôm nay, vượt ngưỡng %.2f.",
                                               _Symbol, dayProfitUSD, AccountInfoString(ACCOUNT_CURRENCY), InpMaxDailyLossUSD));
         }
         return false;
      }
   }

   if (InpMaxSpreadUSD > 0 && CurrentSpreadPrice() > InpMaxSpreadUSD)
   {
      Print("StochIchiMikEA: spread vượt InpMaxSpreadUSD, bỏ qua vào lệnh");
      g_DbgBlockedSpread++;
      return false;
   }

   double price = (type == ORDER_TYPE_BUY) ? CurrentAsk() : CurrentBid();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (slPrice <= 0)
   {
      Print("StochIchiMikEA: không tìm được đáy/đỉnh tương đối để đặt SL, bỏ qua vào lệnh");
      g_DbgBlockedNoSwing++;
      return false;
   }
   double slDistance = MathAbs(price - slPrice);
   double sl = NormalizeDouble(slPrice, digits);

   double tp = 0.0;
   if (InpTpMode == TP_MODE_FIXED_RR && InpTpRRRatio > 0)
   {
      double tpDistance = slDistance * InpTpRRRatio;
      if (InpMinTpDistanceUSD > 0 && tpDistance < InpMinTpDistanceUSD)
         tpDistance = InpMinTpDistanceUSD;
      tp = (type == ORDER_TYPE_BUY) ? (price + tpDistance) : (price - tpDistance);
      tp = NormalizeDouble(tp, digits);
   }
   else if (InpTpMode == TP_MODE_FIXED_PRICE_LEGS && InpTp2DistanceUSD > 0)
   {
      tp = (type == ORDER_TYPE_BUY) ? (price + InpTp2DistanceUSD) : (price - InpTp2DistanceUSD);
      tp = NormalizeDouble(tp, digits);
   }

   double lotToUse = InpUseRiskPercent ? CalcRiskLot(slDistance) : InpLotSize;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = MarginRequiredPerLot(type, price);
   if (marginReq <= 0)
   {
      Print("StochIchiMikEA: OrderCalcMargin() thất bại, bỏ qua vào lệnh");
      g_DbgBlockedMargin++;
      return false;
   }
   if (lotToUse * marginReq > freeMargin)
   {
      Print("StochIchiMikEA: không đủ margin cho lệnh lot=", DoubleToString(lotToUse, 2));
      g_DbgBlockedFreeMargin++;
      return false;
   }

   string tag = isTest ? ((type == ORDER_TYPE_BUY) ? "StochIchiMik TEST BUY" : "StochIchiMik TEST SELL")
                        : ((type == ORDER_TYPE_BUY) ? "StochIchiMik BUY" : "StochIchiMik SELL");

   bool ok;
   if (type == ORDER_TYPE_BUY)
      ok = trade.Buy(lotToUse, _Symbol, price, sl, tp, tag);
   else
      ok = trade.Sell(lotToUse, _Symbol, price, sl, tp, tag);

   if (!ok)
   {
      Print("StochIchiMikEA: mở lệnh thất bại, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      g_DbgOrderSendFail++;
      return false;
   }

   g_Tp1Done = false;
   g_TrailingActive = false;
   g_EarlyBreakevenDone = false;

   string tpLogTxt = (tp > 0) ? (" TP=" + DoubleToString(tp, digits)) : " (TP1 quản lý bằng code)";
   Print("StochIchiMikEA: ", (isTest ? "[TEST] " : ""), "mở lệnh ", EnumToString(type),
         " lot=", DoubleToString(lotToUse, 2), " SL=", DoubleToString(sl, digits), tpLogTxt);

   string dirIcon = (type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string testTag = isTest ? "🧪 [TEST] " : "";
   string lotModeTxt = InpUseRiskPercent ? StringFormat(" (risk %.1f%%)", InpRiskPercent) : "";
   string tpMsgTxt;
   if (InpTpMode == TP_MODE_FIXED_RR)
      tpMsgTxt = StringFormat("🎯 TP: <b>%.2f</b> (%.1fR)", tp, InpTpRRRatio);
   else if (InpTpMode == TP_MODE_FIXED_PRICE_LEGS)
      tpMsgTxt = StringFormat("🎯 TP1: cách %.2f (đóng %.0f%%) — TP2: <b>%.2f</b> (%.2f), phần còn lại trailing", InpTp1DistanceUSD, InpTp1ClosePercent, tp, InpTp2DistanceUSD);
   else
      tpMsgTxt = StringFormat("🎯 TP1: khi Stoch về mức %.0f (đóng %.0f%%), phần còn lại trailing", InpTp1StochLevel, InpTp1ClosePercent);
   TelegramSendMessage(StringFormat("%s%s <b>MỞ LỆNH %s</b> — %s (Stoch+Ichimoku+MIK đồng thuận)\n\n📍 Giá vào: <b>%.2f</b>\n🛑 SL: %.2f\n%s\n💰 Lot: %.2f%s",
                                      testTag, dirIcon, EnumToString(type), _Symbol, price, sl,
                                      tpMsgTxt, lotToUse, lotModeTxt));
   return true;
}

//====================================================================
// H. Trailing SL cho phần lệnh còn lại sau khi đã hòa vốn (breakeven).
//====================================================================
void TrailPosition(ulong ticket)
{
   if (g_AtrHandle == INVALID_HANDLE) return;
   if (!PositionSelectByTicket(ticket)) return;

   double atrArr[];
   if (CopyBuffer(g_AtrHandle, 0, 1, 1, atrArr) < 1) return;
   double atr = atrArr[0];
   if (atr <= 0) return;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   long   posType  = PositionGetInteger(POSITION_TYPE);
   double openP    = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSl    = PositionGetDouble(POSITION_SL);
   double curTp    = PositionGetDouble(POSITION_TP);
   double curPrice = (posType == POSITION_TYPE_BUY) ? CurrentBid() : CurrentAsk();

   double favorableDist = (posType == POSITION_TYPE_BUY) ? (curPrice - openP) : (openP - curPrice);
   if (favorableDist < InpTrailStartAtr * atr) return;

   double newSl;
   if (posType == POSITION_TYPE_BUY)
   {
      newSl = curPrice - InpTrailDistanceAtr * atr;
      if (newSl <= curSl + InpTrailStepAtr * atr) return;
   }
   else
   {
      newSl = curPrice + InpTrailDistanceAtr * atr;
      if (newSl >= curSl - InpTrailStepAtr * atr) return;
   }

   newSl = NormalizeDouble(newSl, digits);
   if (trade.PositionModify(ticket, newSl, curTp))
      Print("StochIchiMikEA: đã siết SL trailing cho ticket #", ticket, " -> SL mới=", DoubleToString(newSl, digits));
}

//====================================================================
// I. Quản lý lệnh đang mở mỗi tick: hòa vốn sớm, TP1, thoát hẳn khi
// chạm vùng đối lập, và trailing SL sau khi hòa vốn.
//====================================================================
void ManageOpenPosition(double stochNow)
{
   long posType = -1;
   ulong ticket = GetOpenPosition(posType);
   if (ticket == 0) return;
   if (!PositionSelectByTicket(ticket)) return;

   if (InpUseOppositeZoneExit)
   {
      bool hitOpposite = (posType == POSITION_TYPE_SELL && stochNow <= InpBuyZoneHigh) ||
                          (posType == POSITION_TYPE_BUY  && stochNow >= InpSellZoneLow);
      if (hitOpposite)
      {
         Print("StochIchiMikEA: Stoch chạm vùng đối lập - đóng hẳn phần lệnh còn lại");
         trade.PositionClose(ticket);
         g_DbgOppositeZoneExit++;
         return;
      }
   }

   if (InpUseEarlyBreakeven && !g_Tp1Done && !g_EarlyBreakevenDone)
   {
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);
      double curPrice = (posType == POSITION_TYPE_BUY) ? CurrentBid() : CurrentAsk();
      double slDist = MathAbs(openP - curSl);
      double favorableDist = (posType == POSITION_TYPE_BUY) ? (curPrice - openP) : (openP - curPrice);

      if (slDist > 0 && favorableDist >= slDist * InpEarlyBreakevenSlMult)
      {
         if (trade.PositionModify(ticket, openP, curTp))
         {
            g_EarlyBreakevenDone = true;
            Print("StochIchiMikEA: đã dời SL về hòa vốn SỚM (trước TP1) cho ticket #", ticket);
            TelegramSendMessage(StringFormat("🔒 <b>HÒA VỐN SỚM</b> — %s\n\nĐã dời SL về giá vào lệnh (%.2f) trước khi kịp chạm TP1.", _Symbol, openP));
         }
      }
   }

   if (InpTpMode != TP_MODE_FIXED_RR && !g_Tp1Done)
   {
      bool tp1Hit = false;
      if (InpTpMode == TP_MODE_STOCH_LEVEL)
      {
         tp1Hit = (posType == POSITION_TYPE_SELL && stochNow <= InpTp1StochLevel) ||
                  (posType == POSITION_TYPE_BUY  && stochNow >= InpTp1StochLevel);
      }
      else if (InpTpMode == TP_MODE_FIXED_PRICE_LEGS)
      {
         double openP    = PositionGetDouble(POSITION_PRICE_OPEN);
         double curPrice = (posType == POSITION_TYPE_BUY) ? CurrentBid() : CurrentAsk();
         double favorableDist = (posType == POSITION_TYPE_BUY) ? (curPrice - openP) : (openP - curPrice);
         tp1Hit = (favorableDist >= InpTp1DistanceUSD);
      }

      if (tp1Hit)
      {
         double volume  = PositionGetDouble(POSITION_VOLUME);
         double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double volClose = NormalizeLot(volume * InpTp1ClosePercent / 100.0);

         if (volClose >= minLot && (volume - volClose) >= minLot)
         {
            if (trade.PositionClosePartial(ticket, volClose))
               Print("StochIchiMikEA: đã đóng TP1 -- volume=", DoubleToString(volClose, 2));
         }

         g_Tp1Done = true;
         g_DbgTp1Hit++;

         if (InpMoveToBreakevenOnTp1 && PositionSelectByTicket(ticket))
         {
            double entryP = PositionGetDouble(POSITION_PRICE_OPEN);
            double tpNow  = PositionGetDouble(POSITION_TP);
            trade.PositionModify(ticket, entryP, tpNow);
         }
         g_TrailingActive = InpUseTrailingAfterTp1;

         TelegramSendMessage(StringFormat("🎯 <b>TP1</b> — %s\n\nĐã chốt %.0f%% khối lượng. Phần còn lại dời SL về hòa vốn%s.",
                                            _Symbol, InpTp1ClosePercent,
                                            InpUseTrailingAfterTp1 ? " và bắt đầu trailing" : ""));
      }
   }

   if (g_TrailingActive && PositionSelectByTicket(ticket))
      TrailPosition(ticket);
}

//====================================================================
// J. Báo đóng lệnh về Telegram -- chỉ báo khi lệnh ĐÃ ĐÓNG HẲN.
//====================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
{
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;
   if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagic) return;
   if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

   long stillOpenType = -1;
   if (GetOpenPosition(stillOpenType) != 0) return;

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                    HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                    HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   long   dealType    = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   long   reason      = HistoryDealGetInteger(dealTicket, DEAL_REASON);
   string origDir     = (dealType == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   string reasonTxt   = (reason == DEAL_REASON_SL) ? "Dính SL" : (reason == DEAL_REASON_TP) ? "Đạt TP" : "Đóng hẳn (chạm vùng đối lập/khác)";
   string resultIcon  = (profit >= 0) ? "✅" : "❌";

   TelegramSendMessage(StringFormat("%s <b>ĐÓNG LỆNH %s</b> — %s (%s)\n\n📍 Giá đóng: %.2f\n💵 Kết quả: <b>%s%.2f %s</b>",
                                      resultIcon, origDir, _Symbol, reasonTxt, closePrice,
                                      (profit >= 0 ? "+" : ""), profit, AccountInfoString(ACCOUNT_CURRENCY)));

   if (profit < 0 && InpUseCooldownAfterLoss && InpCooldownMinutesAfterLoss > 0)
   {
      g_CooldownUntil = TimeCurrent() + InpCooldownMinutesAfterLoss * 60;
      Print("StochIchiMikEA: vừa thua 1 lệnh -- khóa vào lệnh mới tới ", TimeToString(g_CooldownUntil, TIME_DATE | TIME_MINUTES));
   }

   g_Tp1Done = false;
   g_TrailingActive = false;
   g_EarlyBreakevenDone = false;
}

//====================================================================
// K. Cập nhật dashboard
//====================================================================
void UpdateDashboard(double stochNow, int ichiState, int mikState)
{
   if (!InpShowDashboard) return;

   SetLabel(DASH_PREFIX + "Title", StringFormat("=== StochIchiMikEA (%s, %s) ===", _Symbol, EnumToString((ENUM_TIMEFRAMES)Period())), clrWhite);
   SetLabel(DASH_PREFIX + "Stoch", StringFormat("Stochastic %%K: %.2f", stochNow), clrKhaki);

   string ichiTxt = InpUseIchimokuConfirm ? (ichiState == 1 ? "BUY" : ichiState == -1 ? "SELL" : "Flat/N-A") : "TẮT";
   string mikTxt  = InpUseMikConfirm ? (mikState == 1 ? "BUY" : mikState == -1 ? "SELL" : "Flat/N-A") : "TẮT";
   SetLabel(DASH_PREFIX + "Confirm", StringFormat("Ichimoku: %s | MIK: %s", ichiTxt, mikTxt), clrKhaki);

   string lastTxt = (g_lastSignalTime == 0) ? g_lastSignalTxt
                     : StringFormat("[%s] %s", TimeToString(g_lastSignalTime, TIME_DATE | TIME_MINUTES), g_lastSignalTxt);
   SetLabel(DASH_PREFIX + "LastSignal", "Tín hiệu gần nhất: " + lastTxt, clrKhaki);

   long  posType   = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0 && PositionSelectByTicket(posTicket))
   {
      string dirTxt = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double slP   = PositionGetDouble(POSITION_SL);
      double volP  = PositionGetDouble(POSITION_VOLUME);
      string tp1Txt;
      if (InpTpMode == TP_MODE_FIXED_RR)
      {
         double tpP = PositionGetDouble(POSITION_TP);
         tp1Txt = (tpP > 0) ? StringFormat("TP %.2f", tpP) : "TP: không có";
      }
      else
      {
         tp1Txt = g_Tp1Done ? "đã chốt TP1" : "chưa chốt TP1";
      }
      string posTxt = StringFormat("Lệnh: %s @ %.2f | SL %.2f | Vol %.2f | %s", dirTxt, openP, slP, volP, tp1Txt);
      SetLabel(DASH_PREFIX + "Position", posTxt, clrKhaki);
   }
   else
   {
      SetLabel(DASH_PREFIX + "Position", "Lệnh: Không có", clrSilver);
   }

   double dayUSD = CalcDayProfitUSD();
   color  plClr  = (dayUSD >= 0) ? clrLimeGreen : clrTomato;
   SetLabel(DASH_PREFIX + "DayPL", StringFormat("Hôm nay: %s%.2f %s", (dayUSD >= 0 ? "+" : ""), dayUSD, AccountInfoString(ACCOUNT_CURRENCY)), plClr);

   bool paused = (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0 && dayUSD <= -MathAbs(InpMaxDailyLossUSD));
   bool inCooldown = (InpUseCooldownAfterLoss && TimeCurrent() < g_CooldownUntil);
   string statusTxt;
   if (paused) statusTxt = "Trạng thái: TẠM DỪNG (lỗ quá ngưỡng ngày)";
   else if (inCooldown) statusTxt = StringFormat("Trạng thái: Cooldown tới %s", TimeToString(g_CooldownUntil, TIME_MINUTES));
   else statusTxt = "Trạng thái: Bình thường";
   SetLabel(DASH_PREFIX + "Status", statusTxt, (paused || inCooldown) ? clrOrange : clrLimeGreen);
}

//====================================================================
// L. Kiểm tra tín hiệu mỗi TICK: Stochastic chạm vùng LÀM ứng viên,
// CHỈ vào lệnh khi Ichimoku VÀ MIK đều đồng thuận hướng đó.
//====================================================================
void CheckSignal()
{
   if (g_StochHandle == INVALID_HANDLE) return;

   double stochArr[];
   if (CopyBuffer(g_StochHandle, 0, 0, 1, stochArr) < 1) return;
   double stochNow = stochArr[0];

   int ichiState = 0, mikState = 0;
   if (InpUseIchimokuConfirm) ComputeIchimokuState(ichiState);
   if (InpUseMikConfirm) ComputeMikState(mikState);

   ManageOpenPosition(stochNow);
   UpdateDashboard(stochNow, ichiState, mikState);

   int zoneNow = 0;
   if (stochNow >= InpSellZoneLow && stochNow <= InpSellZoneHigh) zoneNow = 1;
   else if (stochNow >= InpBuyZoneLow && stochNow <= InpBuyZoneHigh) zoneNow = -1;

   if (stochNow < InpSellZoneLow - InpZoneExitBuffer) g_SellArmed = true;
   if (stochNow > InpBuyZoneHigh + InpZoneExitBuffer) g_BuyArmed = true;

   long posType = -1;
   ulong ticket = GetOpenPosition(posType);

   bool inCooldown = (InpUseCooldownAfterLoss && TimeCurrent() < g_CooldownUntil);

   if (ticket == 0 && !inCooldown)
   {
      if (zoneNow == 1 && g_SellArmed)
      {
         bool ichiOk = (!InpUseIchimokuConfirm) || (ichiState == -1);
         bool mikOk  = (!InpUseMikConfirm) || (mikState == -1);
         if (!ichiOk) g_DbgBlockedIchiConfirm++;
         if (!mikOk)  g_DbgBlockedMikConfirm++;

         if (ichiOk && mikOk)
         {
            double slPrice = CalcSlForDirection(-1);
            g_lastSignalTxt = StringFormat("SELL @ Stoch=%.2f (Ichimoku+MIK đồng thuận)", stochNow);
            g_lastSignalTime = TimeCurrent();
            if (OpenPosition(ORDER_TYPE_SELL, slPrice, false)) { g_DbgSellOpened++; g_SellArmed = false; }
         }
      }
      else if (zoneNow == -1 && g_BuyArmed)
      {
         bool ichiOk = (!InpUseIchimokuConfirm) || (ichiState == 1);
         bool mikOk  = (!InpUseMikConfirm) || (mikState == 1);
         if (!ichiOk) g_DbgBlockedIchiConfirm++;
         if (!mikOk)  g_DbgBlockedMikConfirm++;

         if (ichiOk && mikOk)
         {
            double slPrice = CalcSlForDirection(1);
            g_lastSignalTxt = StringFormat("BUY @ Stoch=%.2f (Ichimoku+MIK đồng thuận)", stochNow);
            g_lastSignalTime = TimeCurrent();
            if (OpenPosition(ORDER_TYPE_BUY, slPrice, false)) { g_DbgBuyOpened++; g_BuyArmed = false; }
         }
      }
   }
}

//====================================================================
// M. Vòng đời Expert
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(PriceDistanceToPoints(InpSlippageUSD) > 0 ? PriceDistanceToPoints(InpSlippageUSD) : 1);

   if (InpSellZoneLow >= InpSellZoneHigh || InpBuyZoneLow >= InpBuyZoneHigh)
   {
      Print("StochIchiMikEA: Vùng Sell/Buy không hợp lệ (cạnh dưới phải nhỏ hơn cạnh trên)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpFractalBars <= 0)
   {
      Print("StochIchiMikEA: InpFractalBars phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpIchiKijunPeriod <= 0 || InpIchiSenkouBPeriod <= 0)
   {
      Print("StochIchiMikEA: InpIchiKijunPeriod/InpIchiSenkouBPeriod phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_StochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, InpStochMAMethod, InpStochPriceField);
   if (g_StochHandle == INVALID_HANDLE)
   {
      Print("StochIchiMikEA: không tạo được Stochastic handle -- EA sẽ không hoạt động");
      return INIT_FAILED;
   }

   g_AtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (g_AtrHandle == INVALID_HANDLE)
      Print("StochIchiMikEA: cảnh báo - không tạo được ATR handle, InpSlBufferAtr/trailing sẽ bị bỏ qua");

   if (InpUseMikConfirm)
   {
      g_MikRsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpMikRsiPeriod, PRICE_CLOSE);
      if (g_MikRsiHandle == INVALID_HANDLE)
      {
         Print("StochIchiMikEA: không tạo được RSI handle cho MIK confirm -- EA sẽ không hoạt động");
         return INIT_FAILED;
      }
   }

   g_SellArmed = true;
   g_BuyArmed  = true;

   long restoreType = -1;
   ulong restoreTicket = GetOpenPosition(restoreType);
   if (restoreTicket != 0 && PositionSelectByTicket(restoreTicket))
   {
      g_Tp1Done = true;
      g_TrailingActive = InpUseTrailingAfterTp1;
      g_EarlyBreakevenDone = true;
      Print("StochIchiMikEA: phát hiện lệnh đang mở khi khởi động lại EA - coi như TP1 đã xong, tiếp tục trailing nếu bật.");
   }

   Print("StochIchiMikEA v1.00: OnInit THÀNH CÔNG -- EA bắt đầu chạy từ đây.");

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_StochHandle != INVALID_HANDLE) IndicatorRelease(g_StochHandle);
   if (g_AtrHandle != INVALID_HANDLE) IndicatorRelease(g_AtrHandle);
   if (g_MikRsiHandle != INVALID_HANDLE) IndicatorRelease(g_MikRsiHandle);
   DeleteDashboard();

   Print("StochIchiMikEA: [CHẨN ĐOÁN] Sell mở=", g_DbgSellOpened, " | Buy mở=", g_DbgBuyOpened,
         " | TP1 đã chốt=", g_DbgTp1Hit, " | đóng hẳn do chạm vùng đối lập=", g_DbgOppositeZoneExit);
   Print("StochIchiMikEA: [CHẨN ĐOÁN] Bị chặn bởi -- spread=", g_DbgBlockedSpread, " | margin=", g_DbgBlockedMargin,
         " | free margin=", g_DbgBlockedFreeMargin, " | lỗ quá ngưỡng ngày=", g_DbgBlockedDailyLoss,
         " | không tìm được đáy/đỉnh tương đối=", g_DbgBlockedNoSwing, " | gửi lệnh thất bại=", g_DbgOrderSendFail);
   Print("StochIchiMikEA: [CHẨN ĐOÁN] Bị chặn do KHÔNG đồng thuận -- Ichimoku=", g_DbgBlockedIchiConfirm,
         " | MIK=", g_DbgBlockedMikConfirm);
}

void OnTick()
{
   CheckSignal();
}

//====================================================================
// N. Nút Test trên chart (Test TG / Test BUY / Test SELL) -- Test BUY/SELL
// BỎ QUA yêu cầu đồng thuận (để test nhanh cơ chế đóng/mở lệnh), tự
// tìm SL theo swing low/high thật, gọi đúng OpenPosition().
//====================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == DASH_PREFIX + "BtnTestTg")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      bool tgOk = TelegramSendMessage(StringFormat("🧪 <b>TIN NHẮN TEST</b> — %s\n\nXác nhận Bot Token/Chat ID/định dạng HTML đang hoạt động đúng. Không liên quan lệnh giao dịch thật nào.", _Symbol));
      Alert(tgOk ? "StochIchiMikEA [TEST]: Đã gửi tin nhắn test lên Telegram thành công."
                  : "StochIchiMikEA [TEST]: Gửi tin Telegram THẤT BẠI -- kiểm tra Bot Token/Chat ID hoặc whitelist api.telegram.org.");
   }
   else if (sparam == DASH_PREFIX + "BtnTestBuy" || sparam == DASH_PREFIX + "BtnTestSell")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ENUM_ORDER_TYPE testType = (sparam == DASH_PREFIX + "BtnTestBuy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      long existingType = -1;
      if (GetOpenPosition(existingType) != 0)
      {
         Alert("StochIchiMikEA [TEST]: Bỏ qua -- đã có lệnh đang mở, tránh chồng lệnh.");
         return;
      }

      double slPrice = CalcSlForDirection(testType == ORDER_TYPE_BUY ? 1 : -1);
      bool openOk = OpenPosition(testType, slPrice, true);
      Alert(openOk ? StringFormat("StochIchiMikEA [TEST]: Đã mở lệnh %s thành công -- xem chi tiết trong Journal.", EnumToString(testType))
                    : StringFormat("StochIchiMikEA [TEST]: Mở lệnh %s THẤT BẠI -- xem Journal để biết lý do.", EnumToString(testType)));
   }
}
//+------------------------------------------------------------------+
