//+------------------------------------------------------------------+
//|                                                 StochZoneEA.mq5  |
//|  EA giao dịch theo chiến lược "Stochastic vùng cực trị" do người  |
//|  dùng mô tả trực tiếp: "vào lệnh ngay khi giá chạm vùng 95-92 /   |
//|  05-08" -- KHÔNG dùng file .ex5 đóng gói nào, dùng thẳng          |
//|  iStochastic() gốc của MT5 (không phải indicator custom).         |
//|                                                                    |
//|  LOGIC:                                                            |
//|   1) Vào lệnh NGAY LẬP TỨC (không đợi đóng nến, phản ứng theo      |
//|      thời gian thực từng tick) khi đường Stochastic %K chạm vào    |
//|      1 trong 2 vùng cực trị:                                       |
//|      - Chạm vùng TRÊN [InpSellZoneLow, InpSellZoneHigh] (mặc định  |
//|        92-95) -> vào lệnh SELL (quá mua, kỳ vọng đảo chiều xuống). |
//|      - Chạm vùng DƯỚI [InpBuyZoneLow, InpBuyZoneHigh] (mặc định    |
//|        5-8) -> vào lệnh BUY (quá bán, kỳ vọng đảo chiều lên).      |
//|      Chỉ vào lệnh mới khi giá VỪA CHẠM vào vùng (cạnh vào), không  |
//|      vào lệnh liên tục nếu Stoch cứ nằm yên trong vùng nhiều tick. |
//|   2) SL: đặt tại đáy/đỉnh tương đối gần nhất (nến fractal, giống   |
//|      cách làm đã kiểm chứng ở IchimokuChikouEA) -- theo đúng yêu   |
//|      cầu "SL đặt phải chuẩn", không đặt bừa theo ATR đơn thuần.    |
//|   3) THOÁT LỆNH 2 giai đoạn (theo đúng mô tả "TP thì về 50 TP1 còn |
//|      lại trailing stop tới vùng buy dưới"):                        |
//|      - TP1: khi Stochastic quay về mức giữa (mặc định 50), đóng    |
//|        MỘT PHẦN khối lượng lệnh (mặc định 50%) để chốt lời trước,  |
//|        đồng thời dời SL phần còn lại về breakeven (hòa vốn).       |
//|      - Phần còn lại: sau khi hòa vốn, TRAILING SL theo ATR bám     |
//|        theo giá, tiếp tục giữ lệnh cho tới khi Stochastic chạm     |
//|        vùng cực trị ĐỐI LẬP (vd lệnh Sell thì đóng hẳn khi Stoch   |
//|        chạm vùng Buy phía dưới) hoặc bị trailing SL quét.          |
//|                                                                    |
//|  GHI CHÚ: Stochastic được đọc tại NẾN ĐANG CHẠY (shift=0), có thể  |
//|  thay đổi giá trị liên tục cho tới khi nến đóng -- đây là CHỦ Ý,   |
//|  đúng yêu cầu "vào lệnh ngay khi giá chạm", không phải lỗi repaint.|
//|                                                                    |
//|  Không có trình biên dịch MQL5 thật trong môi trường này -- code   |
//|  này CHƯA được compile/chạy thử thực tế. Đã tự kiểm tra cân bằng   |
//|  ngoặc/dấu ngoặc bằng script riêng trước khi giao.                 |
//|                                                                    |
//|  NHẬT KÝ THAY ĐỔI:                                                 |
//|   v1.00: Bản đầu tiên, InpStochKPeriod mặc định = 5 (Stochastic    |
//|          nhanh, chuẩn 5-3-3).                                       |
//|   v1.01: Đổi InpStochKPeriod mặc định 5 -> 100 (giữ D=3, Slowing=3) |
//|          theo đúng bộ số người dùng đã backtest thực tế trên       |
//|          XAUUSDr M15 (~5 tháng) cho kết quả rất tốt: Net Profit    |
//|          +14.911 (10.000 vốn ban đầu), Profit Factor 1.44, tỷ lệ   |
//|          thắng 57.92%. Stochastic chu kỳ 100 là bản "chậm", đo vị  |
//|          trí giá trong 100 nến gần nhất -- mượt hơn hẳn 5-3-3 mặc  |
//|          định cũ, ít bị nhiễu/whipsaw trong thị trường đi ngang.   |
//|          LƯU Ý: kết quả trên mới test ở chế độ "OHLC on M1" của    |
//|          Strategy Tester -- nên kiểm chứng lại bằng "Every tick    |
//|          based on real ticks" trước khi tin tưởng hoàn toàn, vì    |
//|          chiến lược phản ứng theo tick nên rất nhạy với độ chính   |
//|          xác của mô phỏng giá.                                     |
//|   v1.02: Thêm TÙY CHỌN TP cố định theo tỷ lệ R:R (nhóm input 3a,   |
//|          InpUseFixedTpRR/InpTpRRRatio, mặc định TP=2.0R) -- đặt     |
//|          thẳng vào lệnh ở broker, đóng gọn 1 lần khi chạm, THAY THẾ |
//|          cho TP1 theo mức Stochastic khi bật (không dùng đồng thời  |
//|          cả 2 cách). Vùng đối lập (nhóm 9) vẫn hoạt động song song  |
//|          như 1 lớp thoát an toàn bổ sung ở cả 2 chế độ.             |
//|   v1.03: Đổi InpRiskPercent mặc định 3.0 -> 2.0 theo yêu cầu chạy   |
//|          thận trọng hơn khi bắt đầu test thật (cent/live).          |
//|   v1.04: Thêm InpMinTpDistanceUSD (mục 3a) -- khi dùng TP cố định   |
//|          theo R:R, TP thực tế = MAX(2R, mức tối thiểu này), theo    |
//|          đúng yêu cầu "TP tối thiểu 100 pip hoặc 2R". Mặc định 1.0  |
//|          ($ price distance, ~100 pip nếu gold báo giá 2 chữ số      |
//|          thập phân) -- chỉnh lại nếu quy ước pip của broker khác.   |
//|   v1.05: Thêm CÁCH TÍNH SL THỨ 2 (mục 4a, InpUseRangeSl mặc định    |
//|          TẮT): SL = đỉnh/đáy của InpSlRangeBars cây nến gần nhất    |
//|          TRƯỚC nến vào lệnh (mặc định 100, trùng chu kỳ Stochastic) |
//|          -- nằm ngay mép vùng giá mà Stochastic đang đo, thay vì    |
//|          tìm swing point nhỏ lẻ gần nhất như cách fractal cũ (4b,   |
//|          vẫn là mặc định gốc).                                      |
//|   v1.06: Thêm InpSlBufferUSD -- đệm SL CỐ ĐỊNH ($ price distance,   |
//|          "vài giá"), không phụ thuộc ATR, mặc định 0.3. Đổi         |
//|          InpSlBufferAtr mặc định 0.1 -> 0 (tắt) vì trên khung nhỏ   |
//|          (M5) đệm theo ATR hay đẩy SL xa hơn cần thiết. 2 kiểu đệm  |
//|          cộng dồn nếu cả 2 cùng bật.                                |
//|   v1.07: Thêm CÁCH CHỐT LỜI THỨ 3 (InpTpMode = TP_MODE_FIXED_PRICE  |
//|          _LEGS): TP1 đóng 1 phần khi giá đi được InpTp1DistanceUSD  |
//|          (mặc định 10.0 ~ 100 pip), dời SL phần còn lại về hòa vốn, |
//|          rồi trailing tới TP2 (đặt thật ở broker, InpTp2DistanceUSD |
//|          mặc định 20.0 ~ 200 pip) -- cái nào chạm trước (trailing   |
//|          SL hay TP2) thì đóng theo cái đó. InpUseFixedTpRR (bool)   |
//|          cũ đổi thành InpTpMode (enum 3 lựa chọn: STOCH_LEVEL /     |
//|          FIXED_RR / FIXED_PRICE_LEGS). InpUseRiskPercent đã mặc     |
//|          định BẬT từ trước -- risk luôn tính theo % Balance của     |
//|          tài khoản (kể cả tài khoản cent, vì ACCOUNT_BALANCE tự lấy |
//|          đúng đơn vị tiền của tài khoản đang chạy).                 |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.07"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== 1. Stochastic (dùng iStochastic gốc MT5) ==="
input int               InpStochKPeriod   = 100;           // Chu kỳ %K -- mặc định 100 (chậm, mượt) theo đúng bộ số đã backtest cho kết quả tốt; Stochastic chuẩn nhanh là 5
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
input double InpMinTpDistanceUSD = 1.0;  // [Cách B] Khoảng cách TP TỐI THIỂU ($ price distance) -- vd 1.0 ~ 100 pip (gold báo giá 2 chữ số thập phân, 1 pip=0.01$, chỉnh lại nếu broker bạn quy ước khác). TP thực tế = MAX(2R, giá trị này). 0 = tắt, chỉ dùng đúng 2R
input double InpTp1StochLevel   = 50.0; // [Cách A] Mức Stochastic để đóng TP1 (mặc định vùng giữa)
input double InpTp1ClosePercent = 50.0; // [Cách A + Cách C] % khối lượng đóng ở TP1 (phần còn lại sẽ trailing)
input double InpTp1DistanceUSD  = 10.0; // [Cách C] TP1 cách giá vào lệnh bao nhiêu $ price distance -- vd 10.0 ~ 100 pip nếu 1 pip=0.1$ (chỉnh lại theo đúng quy ước broker bạn)
input double InpTp2DistanceUSD  = 20.0; // [Cách C] TP2 (mục tiêu cuối cho phần lệnh còn lại sau TP1) cách giá vào lệnh bao nhiêu $ price distance -- vd 20.0 ~ 200 pip. Đặt thẳng làm TP thật ở broker cho phần còn lại, đồng thời vẫn trailing SL theo nhóm 8 -- cái nào chạm trước thì đóng theo cái đó

input group "=== 4. Stop Loss -- chọn 1 trong 2 cách ==="
input bool   InpUseRangeSl     = false; // true: SL = đỉnh/đáy của N cây nến gần nhất TRƯỚC nến vào lệnh (mục 4a); false: SL theo đáy/đỉnh tương đối fractal (mục 4b, mặc định gốc)
input int    InpSlRangeBars    = 100;   // [4a] Chỉ dùng khi InpUseRangeSl=true -- số cây nến lùi về quá khứ (không tính nến vào lệnh) để tìm đỉnh/đáy làm SL. Mặc định 100, trùng chu kỳ Stochastic mặc định -- SL nằm ngay mép vùng mà Stochastic đang đo
input int    InpFractalBars    = 2;     // [4b] Chỉ dùng khi InpUseRangeSl=false -- số nến 2 bên (trái/phải) phải cao/thấp hơn để tính là 1 đáy/đỉnh tương đối
input int    InpMaxSwingSearch = 300;   // [4b] Chỉ dùng khi InpUseRangeSl=false -- số nến tối đa lùi về quá khứ để tìm đáy/đỉnh tương đối gần nhất
input double InpSlBufferAtr    = 0.0;   // Dùng chung cho cả 2 cách -- đệm thêm ra ngoài đáy/đỉnh theo bội số ATR (tùy chọn, mặc định TẮT vì hay đẩy SL quá xa trên khung nhỏ như M5). 0 = tắt
input double InpSlBufferUSD    = 0.3;   // Dùng chung cho cả 2 cách -- đệm thêm CỐ ĐỊNH ($ price distance, không phụ thuộc ATR) ra ngoài đáy/đỉnh, tránh SL bị chạm do râu nến. Cộng dồn với InpSlBufferAtr nếu cả 2 cùng bật. 0 = tắt

input group "=== 5. Quản lý lệnh ==="
input ulong  InpMagic        = 20260921;
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

input group "=== 8. Trailing SL sau khi chốt TP1 (bảo toàn phần lệnh còn lại) ==="
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

//====================================================================
// Globals
//====================================================================
int    g_StochHandle = INVALID_HANDLE;
int    g_AtrHandle   = INVALID_HANDLE;
int    g_LastZoneState = 0;     // 0=ngoài 2 vùng, 1=đang trong vùng Sell, -1=đang trong vùng Buy -- dùng để phát hiện "vừa chạm" (cạnh vào)
bool   g_Tp1Done       = false; // Đã đóng TP1 cho lệnh đang mở hiện tại chưa
bool   g_TrailingActive = false; // Đã hòa vốn và đang trailing phần lệnh còn lại

datetime g_DailyLossAlertDay = 0;
string   g_lastSignalTxt  = "Chưa có tín hiệu nào";
datetime g_lastSignalTime = 0;

int g_DbgSellOpened = 0, g_DbgBuyOpened = 0, g_DbgTp1Hit = 0, g_DbgOppositeZoneExit = 0;
int g_DbgBlockedSpread = 0, g_DbgBlockedMargin = 0, g_DbgBlockedFreeMargin = 0;
int g_DbgBlockedDailyLoss = 0, g_DbgBlockedNoSwing = 0, g_DbgOrderSendFail = 0;

#define DASH_PREFIX "StochZoneEA_Dash_"

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
      Print("StochZoneEA: gửi Telegram thất bại, lỗi ", GetLastError(),
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
// tìm SL, giống cách làm đã kiểm chứng ở IchimokuChikouEA.
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
      // [4a] SL = đỉnh/đáy của InpSlRangeBars cây nến gần nhất TRƯỚC nến vào lệnh (shift=1, không
      // tính nến hiện tại) -- nằm ngay mép vùng mà Stochastic InpStochKPeriod nến đang đo.
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
      // [4b] SL theo đáy/đỉnh tương đối kiểu fractal (mặc định gốc)
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
      buf += InpSlBufferUSD; // đệm cố định "vài giá", không phụ thuộc ATR
      if (buf > 0)
         slPrice = (direction == 1) ? (slPrice - buf) : (slPrice + buf);
   }
   return slPrice;
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
   string keys[] = {"Title", "Stoch", "LastSignal", "Position", "DayPL", "Status"};
   int x = 10, y = 16, dy = 16;
   int panelW = 340, panelH = ArraySize(keys) * dy + 14;

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
// G. Mở lệnh (1 lệnh duy nhất) -- SL theo swing low/high, KHÔNG CÓ TP
// đặt sẵn ở broker (TP1 quản lý bằng code vì mốc TP1 tính theo GIÁ TRỊ
// Stochastic chứ không phải theo giá, không thể đặt thẳng vào lệnh).
//====================================================================
bool OpenPosition(ENUM_ORDER_TYPE type, double slPrice, bool isTest)
{
   if (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0)
   {
      double dayProfitUSD = CalcDayProfitUSD();
      if (dayProfitUSD <= -MathAbs(InpMaxDailyLossUSD))
      {
         Print("StochZoneEA: đã lỗ ", DoubleToString(dayProfitUSD, 2), " ", AccountInfoString(ACCOUNT_CURRENCY),
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
      Print("StochZoneEA: spread vượt InpMaxSpreadUSD, bỏ qua vào lệnh");
      g_DbgBlockedSpread++;
      return false;
   }

   double price = (type == ORDER_TYPE_BUY) ? CurrentAsk() : CurrentBid();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (slPrice <= 0)
   {
      Print("StochZoneEA: không tìm được đáy/đỉnh tương đối để đặt SL, bỏ qua vào lệnh");
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
         tpDistance = InpMinTpDistanceUSD; // TP thực tế = MAX(2R, mức tối thiểu) -- theo đúng yêu cầu "TP tối thiểu 100 pip hoặc 2R"
      tp = (type == ORDER_TYPE_BUY) ? (price + tpDistance) : (price - tpDistance);
      tp = NormalizeDouble(tp, digits);
   }
   else if (InpTpMode == TP_MODE_FIXED_PRICE_LEGS && InpTp2DistanceUSD > 0)
   {
      // Đặt thẳng TP2 làm TP thật ở broker ngay từ đầu -- TP1 (đóng 1 phần) được quản lý
      // bằng code trong ManageOpenPosition() vì cần giữ lại phần lệnh còn lại để trailing tới TP2.
      tp = (type == ORDER_TYPE_BUY) ? (price + InpTp2DistanceUSD) : (price - InpTp2DistanceUSD);
      tp = NormalizeDouble(tp, digits);
   }

   double lotToUse = InpUseRiskPercent ? CalcRiskLot(slDistance) : InpLotSize;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = MarginRequiredPerLot(type, price);
   if (marginReq <= 0)
   {
      Print("StochZoneEA: OrderCalcMargin() thất bại, bỏ qua vào lệnh");
      g_DbgBlockedMargin++;
      return false;
   }
   if (lotToUse * marginReq > freeMargin)
   {
      Print("StochZoneEA: không đủ margin cho lệnh lot=", DoubleToString(lotToUse, 2));
      g_DbgBlockedFreeMargin++;
      return false;
   }

   string tag = isTest ? ((type == ORDER_TYPE_BUY) ? "StochZone TEST BUY" : "StochZone TEST SELL")
                        : ((type == ORDER_TYPE_BUY) ? "StochZone BUY" : "StochZone SELL");

   bool ok;
   if (type == ORDER_TYPE_BUY)
      ok = trade.Buy(lotToUse, _Symbol, price, sl, tp, tag); // tp=0 nếu dùng TP1 theo Stochastic (quản lý bằng code); tp>0 nếu dùng TP cố định theo R:R
   else
      ok = trade.Sell(lotToUse, _Symbol, price, sl, tp, tag);

   if (!ok)
   {
      Print("StochZoneEA: mở lệnh thất bại, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      g_DbgOrderSendFail++;
      return false;
   }

   g_Tp1Done = false;
   g_TrailingActive = false;

   string tpLogTxt = (tp > 0) ? (" TP=" + DoubleToString(tp, digits)) : " (TP1 quản lý bằng code)";
   Print("StochZoneEA: ", (isTest ? "[TEST] " : ""), "mở lệnh ", EnumToString(type),
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
   TelegramSendMessage(StringFormat("%s%s <b>MỞ LỆNH %s</b> — %s\n\n📍 Giá vào: <b>%.2f</b>\n🛑 SL: %.2f (đáy/đỉnh tương đối gần nhất)\n%s\n💰 Lot: %.2f%s",
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
      Print("StochZoneEA: đã siết SL trailing cho ticket #", ticket, " -> SL mới=", DoubleToString(newSl, digits));
}

//====================================================================
// I. Quản lý lệnh đang mở mỗi tick: TP1 theo mức Stochastic, thoát hẳn
// khi chạm vùng đối lập, và trailing SL sau khi hòa vốn.
//====================================================================
void ManageOpenPosition(double stochNow)
{
   long posType = -1;
   ulong ticket = GetOpenPosition(posType);
   if (ticket == 0) return;
   if (!PositionSelectByTicket(ticket)) return;

   // --- Thoát HẲN khi Stoch chạm vùng đối lập (mục tiêu cuối cùng) ---
   if (InpUseOppositeZoneExit)
   {
      bool hitOpposite = (posType == POSITION_TYPE_SELL && stochNow <= InpBuyZoneHigh) ||
                          (posType == POSITION_TYPE_BUY  && stochNow >= InpSellZoneLow);
      if (hitOpposite)
      {
         Print("StochZoneEA: Stoch chạm vùng đối lập - đóng hẳn phần lệnh còn lại");
         trade.PositionClose(ticket);
         g_DbgOppositeZoneExit++;
         return;
      }
   }

   // --- TP1: đóng 1 phần (theo mức Stochastic HOẶC theo khoảng cách giá, tùy InpTpMode),
   // rồi dời SL phần còn lại về hòa vốn. (BỎ QUA hoàn toàn khối này ở Cách B (TP_MODE_FIXED_RR)
   // -- lúc đó lệnh đã có TP thật đặt sẵn ở broker (xem OpenPosition()), broker tự đóng khi
   // chạm, không cần theo dõi bằng code nữa.)
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
               Print("StochZoneEA: đã đóng TP1 -- volume=", DoubleToString(volClose, 2));
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

         TelegramSendMessage(StringFormat("🎯 <b>TP1</b> — %s\n\nStochastic đã về mức %.0f, đã chốt %.0f%% khối lượng. Phần còn lại dời SL về hòa vốn%s.",
                                            _Symbol, InpTp1StochLevel, InpTp1ClosePercent,
                                            InpUseTrailingAfterTp1 ? " và bắt đầu trailing" : ""));
      }
   }

   if (g_TrailingActive && PositionSelectByTicket(ticket))
      TrailPosition(ticket);
}

//====================================================================
// J. Báo đóng lệnh về Telegram -- chỉ báo khi lệnh ĐÃ ĐÓNG HẲN (không
// còn ticket mở nào của EA này), để tránh trùng với thông báo TP1 đã
// gửi riêng ở ManageOpenPosition().
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
   if (GetOpenPosition(stillOpenType) != 0) return; // lệnh còn mở -- day la deal TP1 (da bao rieng), khong bao lai

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

   g_Tp1Done = false;
   g_TrailingActive = false;
}

//====================================================================
// K. Cập nhật dashboard
//====================================================================
void UpdateDashboard(double stochNow)
{
   if (!InpShowDashboard) return;

   SetLabel(DASH_PREFIX + "Title", StringFormat("=== StochZoneEA (%s, %s) ===", _Symbol, EnumToString((ENUM_TIMEFRAMES)Period())), clrWhite);
   SetLabel(DASH_PREFIX + "Stoch", StringFormat("Stochastic %%K hiện tại: %.2f", stochNow), clrKhaki);

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
   SetLabel(DASH_PREFIX + "Status", paused ? "Trạng thái: TẠM DỪNG (lỗ quá ngưỡng ngày)" : "Trạng thái: Bình thường",
             paused ? clrOrange : clrLimeGreen);
}

//====================================================================
// L. Kiểm tra tín hiệu Stochastic mỗi TICK (phản ứng ngay lập tức khi
// giá vừa chạm vùng, không đợi đóng nến).
//====================================================================
void CheckStochSignal()
{
   if (g_StochHandle == INVALID_HANDLE) return;

   double stochArr[];
   if (CopyBuffer(g_StochHandle, 0, 0, 1, stochArr) < 1) return;
   double stochNow = stochArr[0];

   ManageOpenPosition(stochNow);
   UpdateDashboard(stochNow);

   int zoneNow = 0;
   if (stochNow >= InpSellZoneLow && stochNow <= InpSellZoneHigh) zoneNow = 1;
   else if (stochNow >= InpBuyZoneLow && stochNow <= InpBuyZoneHigh) zoneNow = -1;

   long posType = -1;
   ulong ticket = GetOpenPosition(posType);

   if (ticket == 0) // Chưa có lệnh -- xét tín hiệu vào lệnh mới (chỉ khi VỪA CHẠM vào vùng)
   {
      if (zoneNow == 1 && g_LastZoneState != 1)
      {
         double slPrice = CalcSlForDirection(-1);
         g_lastSignalTxt = StringFormat("SELL @ Stoch=%.2f (chạm vùng %.0f-%.0f)", stochNow, InpSellZoneLow, InpSellZoneHigh);
         g_lastSignalTime = TimeCurrent();
         if (OpenPosition(ORDER_TYPE_SELL, slPrice, false)) g_DbgSellOpened++;
      }
      else if (zoneNow == -1 && g_LastZoneState != -1)
      {
         double slPrice = CalcSlForDirection(1);
         g_lastSignalTxt = StringFormat("BUY @ Stoch=%.2f (chạm vùng %.0f-%.0f)", stochNow, InpBuyZoneLow, InpBuyZoneHigh);
         g_lastSignalTime = TimeCurrent();
         if (OpenPosition(ORDER_TYPE_BUY, slPrice, false)) g_DbgBuyOpened++;
      }
   }

   g_LastZoneState = zoneNow;
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
      Print("StochZoneEA: Vùng Sell/Buy không hợp lệ (cạnh dưới phải nhỏ hơn cạnh trên)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpFractalBars <= 0)
   {
      Print("StochZoneEA: InpFractalBars phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_StochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, InpStochMAMethod, InpStochPriceField);
   if (g_StochHandle == INVALID_HANDLE)
   {
      Print("StochZoneEA: không tạo được Stochastic handle -- EA sẽ không hoạt động");
      return INIT_FAILED;
   }

   g_AtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (g_AtrHandle == INVALID_HANDLE)
      Print("StochZoneEA: cảnh báo - không tạo được ATR handle, InpSlBufferAtr/trailing sẽ bị bỏ qua");

   g_LastZoneState = 0;

   // Khôi phục trạng thái nếu EA khởi động lại khi đang có sẵn lệnh mở -- coi như TP1 đã
   // xong (an toàn hơn là đóng nhầm 1 phần lệnh lần 2), tiếp tục trailing nếu SL hiện tại
   // đã ở breakeven hoặc tốt hơn.
   long restoreType = -1;
   ulong restoreTicket = GetOpenPosition(restoreType);
   if (restoreTicket != 0 && PositionSelectByTicket(restoreTicket))
   {
      g_Tp1Done = true;
      g_TrailingActive = InpUseTrailingAfterTp1;
      Print("StochZoneEA: phát hiện lệnh đang mở khi khởi động lại EA - coi như TP1 đã xong, tiếp tục trailing nếu bật.");
   }

   Print("StochZoneEA v1.07: OnInit THÀNH CÔNG -- EA bắt đầu chạy từ đây.");

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_StochHandle != INVALID_HANDLE) IndicatorRelease(g_StochHandle);
   if (g_AtrHandle != INVALID_HANDLE) IndicatorRelease(g_AtrHandle);
   DeleteDashboard();

   Print("StochZoneEA: [CHẨN ĐOÁN] Sell mở=", g_DbgSellOpened, " | Buy mở=", g_DbgBuyOpened,
         " | TP1 đã chốt=", g_DbgTp1Hit, " | đóng hẳn do chạm vùng đối lập=", g_DbgOppositeZoneExit);
   Print("StochZoneEA: [CHẨN ĐOÁN] Bị chặn bởi -- spread=", g_DbgBlockedSpread, " | margin=", g_DbgBlockedMargin,
         " | free margin=", g_DbgBlockedFreeMargin, " | lỗ quá ngưỡng ngày=", g_DbgBlockedDailyLoss,
         " | không tìm được đáy/đỉnh tương đối=", g_DbgBlockedNoSwing, " | gửi lệnh thất bại=", g_DbgOrderSendFail);
}

void OnTick()
{
   CheckStochSignal();
}

//====================================================================
// N. Nút Test trên chart (Test TG / Test BUY / Test SELL) -- Test BUY/SELL
// tự tìm SL theo swing low/high thật, rồi gọi đúng OpenPosition() y hệt
// đường đi của tín hiệu thật.
//====================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == DASH_PREFIX + "BtnTestTg")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      bool tgOk = TelegramSendMessage(StringFormat("🧪 <b>TIN NHẮN TEST</b> — %s\n\nXác nhận Bot Token/Chat ID/định dạng HTML đang hoạt động đúng. Không liên quan lệnh giao dịch thật nào.", _Symbol));
      Alert(tgOk ? "StochZoneEA [TEST]: Đã gửi tin nhắn test lên Telegram thành công."
                  : "StochZoneEA [TEST]: Gửi tin Telegram THẤT BẠI -- kiểm tra Bot Token/Chat ID hoặc whitelist api.telegram.org.");
   }
   else if (sparam == DASH_PREFIX + "BtnTestBuy" || sparam == DASH_PREFIX + "BtnTestSell")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ENUM_ORDER_TYPE testType = (sparam == DASH_PREFIX + "BtnTestBuy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      long existingType = -1;
      if (GetOpenPosition(existingType) != 0)
      {
         Alert("StochZoneEA [TEST]: Bỏ qua -- đã có lệnh đang mở, tránh chồng lệnh.");
         return;
      }

      double slPrice = CalcSlForDirection(testType == ORDER_TYPE_BUY ? 1 : -1);
      bool openOk = OpenPosition(testType, slPrice, true);
      Alert(openOk ? StringFormat("StochZoneEA [TEST]: Đã mở lệnh %s thành công -- xem chi tiết trong Journal.", EnumToString(testType))
                    : StringFormat("StochZoneEA [TEST]: Mở lệnh %s THẤT BẠI -- xem Journal để biết lý do.", EnumToString(testType)));
   }
}
//+------------------------------------------------------------------+
