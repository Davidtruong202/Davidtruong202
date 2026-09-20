//+------------------------------------------------------------------+
//|                                            IchimokuChikouEA.mq5  |
//|  EA tự động vào lệnh theo chiến lược "Ichimoku Chikou Span Cross  |
//|  đa khung giờ" (video "The Easiest and Most Effective Ichimoku    |
//|  Strategy" - @TechnicalAnalysisInstitute) -- TỰ VIẾT từ đầu,      |
//|  KHÔNG dùng file .ex5 đóng gói nào, KHÔNG gọi iCustom() tới bên   |
//|  thứ 3. Chỉ dùng 2 đường của Ichimoku: Lagging Span (Chikou) và   |
//|  Span B (Senkou Span B) -- KHÔNG cần Tenkan/Kijun/Span A.         |
//|                                                                    |
//|  LOGIC (đúng ý hệt video, xem tóm tắt cuối file):                  |
//|   1) Vào lệnh (2 bước, khung 15 phút + khung 1 giờ):                |
//|      - Bước 1 (khung vào lệnh, vd M15): Lagging Span cắt LÊN trên   |
//|        Span B -> Buy; cắt XUỐNG -> Sell.                            |
//|      - Bước 2 (khung xác nhận, vd H1): giá phải đang ở phía thuận   |
//|        lợi so với Span B của khung đó (trên Span B cho Buy, dưới    |
//|        cho Sell), VÀ khoảng cách từ giá đến Span B phải đủ lớn      |
//|        (lọc theo bội số ATR của khung xác nhận).                    |
//|   2) SL: đặt tại mức thấp nhất trong 2 đáy tương đối gần nhất       |
//|      (Buy) / cao nhất trong 2 đỉnh tương đối gần nhất (Sell) --     |
//|      "đáy/đỉnh tương đối" = nến fractal (thấp/cao hơn N nến bên     |
//|      trái VÀ N nến bên phải).                                       |
//|   3) KHÔNG CÓ TP CỐ ĐỊNH -- chỉ thoát lệnh khi Lagging Span cắt     |
//|      NGƯỢC LẠI qua Span B (đúng ý hệt điều kiện vào lệnh, đảo       |
//|      chiều) -- giữ lệnh xuyên suốt dù giá đi ngang bao lâu.         |
//|   4) CỘNG LỆNH (pyramiding, phần mở rộng trong video -- ngoài phần  |
//|      tóm tắt cuối video nhưng vẫn được video trình bày và người     |
//|      dùng yêu cầu làm giống): trong lúc đang giữ lệnh, nếu giá tiếp |
//|      tục tạo đỉnh (Long) / đáy (Short) tương đối MỚI cực đoan hơn   |
//|      mọi mốc đã dùng trước đó, EA mở thêm 1 đơn vị lệnh CÙNG HƯỚNG  |
//|      (tối đa InpMaxPyramidUnits đơn vị/nhóm), mỗi đơn vị có SL       |
//|      riêng tính lại tại đúng thời điểm cộng lệnh. Cả nhóm lệnh      |
//|      (lệnh gốc + các lệnh cộng thêm, cùng Symbol+Magic) thoát CHUNG  |
//|      một lượt khi có tín hiệu Chikou/Span B đảo chiều.               |
//|                                                                    |
//|  GHI CHÚ KỸ THUẬT QUAN TRỌNG VỀ CÁCH TÍNH "Chikou cắt Span B":     |
//|  Đây là điểm dễ sai NHẤT khi code Ichimoku trong MQL5, vì cả 2      |
//|  đường đều bị "dịch chuyển" khi vẽ lên chart (Span B dịch TỚI       |
//|  TƯƠNG LAI InpKijunPeriod nến, Chikou dịch VỀ QUÁ KHỨ                |
//|  InpKijunPeriod nến). EA này KHÔNG dùng buffer có sẵn của           |
//|  iIchimoku() (để tránh nhầm lẫn về quy ước dịch chuyển nội bộ của    |
//|  MT5) -- mà TỰ TÍNH TAY mọi thứ từ giá gốc (High/Low/Close), suy    |
//|  luận lại đúng nghĩa toán học của Chikou/Span B từ đầu:             |
//|                                                                    |
//|   - RawSpanB(k) = (Highest(High, N2, k) + Lowest(Low, N2, k)) / 2  |
//|     (N2 = InpSenkouBPeriod, k = số nến lùi về quá khứ, k=0=nến     |
//|     hiện tại). Đây là giá trị "gốc", CHƯA dịch chuyển gì cả.        |
//|   - Span B VẼ trên chart tại vị trí "k nến trước" = RawSpanB tính   |
//|     từ dữ liệu "k+N1 nến trước" (N1=InpKijunPeriod), vì Span B bị   |
//|     đẩy TỚI TƯƠNG LAI N1 nến so với lúc tính.                       |
//|   - Chikou VẼ trên chart tại vị trí "k nến trước" = giá đóng của    |
//|     nến "(k-N1) nến trước" (= CLOSE[k-N1]), vì Chikou bị đẩy VỀ      |
//|     QUÁ KHỨ N1 nến so với lúc tính (giá hôm nay được vẽ lùi N1 nến).|
//|   - Tín hiệu "hôm nay" (nhìn Chikou của HÔM NAY xem nó đang ở đâu   |
//|     trên chart) tương đương xét tại vị trí "N1 nến trước" (vì đó    |
//|     là nơi Chikou của hôm nay được vẽ tới): Chikou tại đó =         |
//|     CLOSE[N1-N1] = CLOSE[0] (đúng, giá hôm nay). Span B tại vị trí  |
//|     đó = RawSpanB(N1+N1) = RawSpanB(2*N1).                          |
//|   => KẾT LUẬN: tín hiệu "Chikou cắt Span B hôm nay" = so sánh       |
//|      CLOSE[0] (giá đóng hôm nay) với RawSpanB(2*InpKijunPeriod)     |
//|      (Span B tính từ dữ liệu 2*N1 nến trước). Đây CHÍNH XÁC là      |
//|      định nghĩa Ichimoku gốc -- đã tự suy luận lại 2 lần độc lập    |
//|      để xác nhận, KHÔNG phải đoán mò.                               |
//|                                                                    |
//|  Không có trình biên dịch MQL5 thật trong môi trường này -- code   |
//|  này CHƯA được compile/chạy thử thực tế. Đã tự kiểm tra cân bằng   |
//|  ngoặc/dấu ngoặc bằng script riêng trước khi giao.                 |
//|                                                                    |
//|  NHẬT KÝ THAY ĐỔI:                                                 |
//|   v1.00: Bản đầu tiên -- vào/thoát lệnh theo Chikou/Span B 2 khung, |
//|          SL theo fractal, không TP cố định.                        |
//|   v1.01: (1) Thêm tính năng CỘNG LỆNH (pyramiding) đúng ý mở rộng   |
//|          trong video; (2) viết lại toàn bộ chú thích + input bằng   |
//|          tiếng Việt có dấu đầy đủ.                                  |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.01"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== 1. Ichimoku (chỉ dùng Chikou + Span B) ==="
input int InpKijunPeriod   = 26; // Số nến dịch chuyển (N1) -- bội số Kijun mặc định của Ichimoku chuẩn
input int InpSenkouBPeriod = 52; // Chu kỳ tính Span B (N2) -- mặc định của Ichimoku chuẩn

input group "=== 2. Xác nhận đa khung giờ (bước 2) ==="
input bool             InpUseH1Filter      = true;        // Bật/tắt bước xác nhận khung giờ lớn hơn
input ENUM_TIMEFRAMES  InpConfirmTimeframe = PERIOD_H1;    // Khung xác nhận (video dùng H1 khi EA chạy trên M15)
input int              InpConfirmAtrPeriod = 14;           // Chu kỳ ATR của khung xác nhận, dùng để đo "khoảng cách đủ lớn"
input double            InpConfirmMinDistAtr = 0.3;         // Khoảng cách tối thiểu từ giá đến Span B (khung xác nhận), bội số ATR. 0 = chỉ cần đúng phía, không xét khoảng cách

input group "=== 3. Stop Loss theo đáy/đỉnh tương đối (fractal) ==="
input int InpFractalBars     = 2;   // Số nến 2 bên (trái/phải) phải cao/thấp hơn để tính là 1 đáy/đỉnh tương đối
input int InpMaxSwingSearch  = 300; // Số nến tối đa lùi về quá khứ để tìm đủ 2 đáy/đỉnh tương đối gần nhất
input double InpSlBufferAtr  = 0.1; // Đệm thêm 1 khoảng nhỏ (bội số ATR khung vào lệnh) ra ngoài đáy/đỉnh, tránh SL bị chạm do râu nến (0 = không đệm)

input group "=== 4. Quản lý lệnh ==="
input bool   InpOnePositionOnly = true;    // Chặn tín hiệu vào lệnh MỚI (theo cắt Chikou/Span B) nếu đã có lệnh đang mở -- không ảnh hưởng tính năng cộng lệnh (pyramiding) ở nhóm 9, vì cộng lệnh dùng cơ chế trigger riêng
input double InpMaxSpreadUSD    = 0.0;     // Bỏ qua vào lệnh mới nếu spread > giá trị này ($ price distance). 0 = tắt
input ulong  InpMagic           = 20260920;
input double InpSlippageUSD     = 0.30;

input group "=== 5. Khối lượng lệnh theo % RISK ==="
input bool   InpUseRiskPercent = true;  // true: tự tính lot theo % Balance (khuyến nghị); false: dùng InpLotSize cố định
input double InpRiskPercent    = 3.0;   // % Balance chấp nhận mất nếu dính đúng SL
input double InpLotSize        = 0.01;  // Lot cố định, dùng khi InpUseRiskPercent=false hoặc khi thiếu dữ liệu để tính risk%
input double InpMaxLotCap      = 1.0;   // Chặn lot tối đa (an toàn)

input group "=== 6. Tự động DỪNG VÀO LỆNH MỚI khi lỗ quá ngưỡng trong ngày ==="
input bool   InpUseDailyLossLimit = true;  // Bật/tắt tính năng tự dừng vào lệnh khi lỗ quá ngưỡng trong ngày
input double InpMaxDailyLossUSD   = 15.0;  // Ngưỡng lỗ tối đa trong ngày (đơn vị tiền tài khoản), vượt ngưỡng sẽ tạm dừng vào lệnh mới

input group "=== 7. Telegram - thông báo trực tiếp, 1 lớp duy nhất ==="
input string InpTgBotToken = ""; // Token của Bot Telegram -- để trống "" nếu không dùng Telegram
input long   InpTgChatId   = 0;  // ID của group/chat nhận thông báo -- để 0 nếu không dùng Telegram
input int    InpTgTopicId  = 0;  // ID của Topic (nếu group có bật Forum Topics) -- để 0 nếu không dùng Topic

input group "=== 8. Bảng trạng thái + nút Test trên chart ==="
input bool InpShowDashboard   = true; // Hiện/ẩn bảng trạng thái (dashboard) ở góc trái chart
input bool InpShowTestButtons = true; // Hiện/ẩn 3 nút Test (Test TG / Test BUY / Test SELL) trên chart

input group "=== 9. Cộng lệnh (Pyramiding) khi giá tạo đỉnh/đáy tương đối MỚI cực đoan hơn ==="
input bool InpUsePyramiding   = true; // Bật/tắt tính năng cộng lệnh khi đang giữ lệnh và giá tạo đỉnh/đáy tương đối mới có lợi hơn mọi mốc trước đó (đúng ý phần mở rộng trong video)
input int  InpMaxPyramidUnits = 3;    // Số đơn vị lệnh tối đa cho 1 nhóm lệnh (tính cả lệnh gốc + các lệnh cộng thêm)

//====================================================================
// Globals
//====================================================================
datetime g_LastBarTime = 0;
int      g_AtrHandleEntry   = INVALID_HANDLE; // ATR trên khung vào lệnh (dùng cho InpSlBufferAtr)
int      g_AtrHandleConfirm = INVALID_HANDLE; // ATR trên khung xác nhận (dùng cho InpConfirmMinDistAtr)

int g_DbgBarsProcessed = 0;
int g_DbgCrossUp = 0, g_DbgCrossDown = 0;
int g_DbgBuyOpened = 0, g_DbgSellOpened = 0;
int g_DbgBlockedH1Filter = 0, g_DbgBlockedSpread = 0, g_DbgBlockedMargin = 0, g_DbgBlockedFreeMargin = 0;
int g_DbgBlockedDupSignal = 0, g_DbgBlockedDailyLoss = 0, g_DbgOrderSendFail = 0, g_DbgBlockedNoSwing = 0;
int g_DbgPyramidAdded = 0;

datetime g_DailyLossAlertDay = 0;

string g_lastSignalTxt = "Chưa có tín hiệu nào";
datetime g_lastSignalBarTime = 0;

// --- Trạng thái nhóm lệnh đang cộng (pyramiding) -- reset về 0 khi cả nhóm đóng hết ---
int    g_PyramidDir       = 0;   // Hướng nhóm lệnh đang giữ: 0=không có nhóm nào, 1=Long, -1=Short
int    g_PyramidUnits     = 0;   // Số đơn vị lệnh đã mở trong nhóm hiện tại (tính cả lệnh gốc)
double g_PyramidExtremeRef = 0.0; // Mức đỉnh/đáy tương đối cực đoan nhất đã dùng làm mốc cộng lệnh gần nhất

#define DASH_PREFIX "IchiEA_Dash_"

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
// B. Vị thế của EA này (theo magic+symbol)
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

void CloseAllPositions()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      trade.PositionClose(ticket);
   }
}

//====================================================================
// C. Telegram - thông báo trực tiếp 1 lớp duy nhất (POST + HTML, giống
// pattern đã kiểm chứng trong EMACrossCloneEA)
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
      Print("IchimokuChikouEA: gửi Telegram thất bại, lỗi ", GetLastError(),
            " -- kiểm tra đã whitelist https://api.telegram.org trong Tools->Options->Expert Advisors chưa");
      return false;
   }
   return true;
}

//====================================================================
// D. Lãi/lỗ trong ngày theo USD (circuit breaker) -- tính lại TỪ ĐẦU mỗi
// lần gọi, tự động reset khi sang ngày mới, giống pattern EMACrossCloneEA.
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
// E. Tính RawSpanB(k) -- giá trị GỐC (chưa dịch chuyển gì) của Span B,
// dùng dữ liệu High/Low của khung 'timeframe' bất kỳ. k = số nến lùi về
// quá khứ tính từ nến vừa đóng của khung đó (0 = nến vừa đóng).
// Xem ghi chú toán học đầy đủ ở đầu file trước khi đổi bất kỳ dòng nào.
//====================================================================
bool ComputeRawSpanB(string symbol, ENUM_TIMEFRAMES timeframe, int senkouBPeriod, int k, double &outValue)
{
   double highArr[], lowArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   int need = k + senkouBPeriod + 2;
   if (CopyHigh(symbol, timeframe, 0, need, highArr) < need) return false;
   if (CopyLow(symbol, timeframe, 0, need, lowArr) < need) return false;

   double hi = highArr[k], lo = lowArr[k];
   for (int j = k + 1; j < k + senkouBPeriod; j++)
   {
      if (highArr[j] > hi) hi = highArr[j];
      if (lowArr[j] < lo) lo = lowArr[j];
   }
   outValue = (hi + lo) / 2.0;
   return true;
}

//====================================================================
// F. Đáy/đỉnh tương đối kiểu fractal (2 bên đều thấp/cao hơn) -- dùng
// tìm SL và làm mốc cộng lệnh. lowArr/highArr đã lấy theo kiểu series
// (idx 0 = nến mới nhất).
//====================================================================
bool IsSwingLow(const double &lowArr[], int idx, int fractalBars, int n)
{
   if (idx - fractalBars < 0 || idx + fractalBars >= n) return false;
   for (int j = 1; j <= fractalBars; j++)
   {
      if (lowArr[idx - j] < lowArr[idx]) return false; // nến gần hiện tại hơn thấp hơn -> không phải đáy tương đối
      if (lowArr[idx + j] < lowArr[idx]) return false; // nến xa hiện tại hơn thấp hơn -> không phải đáy tương đối
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

// Tìm giá SL cho lệnh BUY: thấp nhất trong 2 đáy tương đối GẦN NHẤT (lùi về quá khứ từ startIdx).
// Trả về 0 nếu không tìm thấy đủ (nên fallback dùng ATR ở nơi gọi).
double FindBuySlFromSwingLows(const double &lowArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   double found[2];
   int cnt = 0;
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit && cnt < 2; idx++)
   {
      if (IsSwingLow(lowArr, idx, fractalBars, n))
      {
         found[cnt] = lowArr[idx];
         cnt++;
      }
   }
   if (cnt == 0) return 0.0;
   if (cnt == 1) return found[0];
   return MathMin(found[0], found[1]);
}

double FindSellSlFromSwingHighs(const double &highArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   double found[2];
   int cnt = 0;
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit && cnt < 2; idx++)
   {
      if (IsSwingHigh(highArr, idx, fractalBars, n))
      {
         found[cnt] = highArr[idx];
         cnt++;
      }
   }
   if (cnt == 0) return 0.0;
   if (cnt == 1) return found[0];
   return MathMax(found[0], found[1]);
}

// Tìm đỉnh/đáy tương đối GẦN NHẤT (chỉ 1 điểm, không cần đủ 2 như hàm tìm SL
// ở trên) -- dùng làm mốc kích hoạt cộng lệnh (pyramiding), KHÔNG dùng cho SL.
double FindLatestSwingHigh(const double &highArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit; idx++)
      if (IsSwingHigh(highArr, idx, fractalBars, n)) return highArr[idx];
   return 0.0;
}

double FindLatestSwingLow(const double &lowArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit; idx++)
      if (IsSwingLow(lowArr, idx, fractalBars, n)) return lowArr[idx];
   return 0.0;
}

//====================================================================
// G. Dashboard (OBJ_LABEL + khung nền) và nút Test -- xem OnChartEvent().
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
   string keys[] = {"Title", "LastSignal", "Position", "DayPL", "Status"};
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
// H. Mở lệnh -- SL theo swing low/high, KHÔNG CÓ TP (thoát khi có tín
// hiệu Chikou cắt ngược lại, xử lý trong CheckSignal()). Tham số
// isPyramid chỉ dùng để đánh dấu đây là lệnh CỘNG THÊM (pyramiding) hay
// lệnh gốc, phục vụ đặt nhãn lệnh/nội dung Telegram -- không đổi logic SL/lot.
//====================================================================
bool OpenPosition(ENUM_ORDER_TYPE type, double slPrice, bool isTest, bool isPyramid = false)
{
   if (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0)
   {
      double dayProfitUSD = CalcDayProfitUSD();
      if (dayProfitUSD <= -MathAbs(InpMaxDailyLossUSD))
      {
         Print("IchimokuChikouEA: đã lỗ ", DoubleToString(dayProfitUSD, 2), " ", AccountInfoString(ACCOUNT_CURRENCY),
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
      Print("IchimokuChikouEA: spread vượt InpMaxSpreadUSD, bỏ qua vào lệnh");
      g_DbgBlockedSpread++;
      return false;
   }

   double price = (type == ORDER_TYPE_BUY) ? CurrentAsk() : CurrentBid();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (slPrice <= 0)
   {
      Print("IchimokuChikouEA: không tìm được đủ 2 đáy/đỉnh tương đối để đặt SL, bỏ qua vào lệnh");
      g_DbgBlockedNoSwing++;
      return false;
   }
   double slDistance = MathAbs(price - slPrice);
   double sl = NormalizeDouble(slPrice, digits);

   double lotToUse = InpUseRiskPercent ? CalcRiskLot(slDistance) : InpLotSize;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = MarginRequiredPerLot(type, price);
   if (marginReq <= 0)
   {
      Print("IchimokuChikouEA: OrderCalcMargin() thất bại, bỏ qua vào lệnh");
      g_DbgBlockedMargin++;
      return false;
   }
   if (lotToUse * marginReq > freeMargin)
   {
      Print("IchimokuChikouEA: không đủ margin cho lệnh lot=", DoubleToString(lotToUse, 2));
      g_DbgBlockedFreeMargin++;
      return false;
   }

   // Nhãn lệnh (POSITION_COMMENT) cố tình giữ KHÔNG dấu (ASCII thuần) để tránh rủi ro
   // encoding trên hệ thống một số sàn/broker -- chỉ nội dung Telegram mới dùng dấu đầy đủ.
   string tag;
   if (isTest)
      tag = (type == ORDER_TYPE_BUY) ? "IchiEA TEST BUY" : "IchiEA TEST SELL";
   else if (isPyramid)
      tag = (type == ORDER_TYPE_BUY) ? "IchiEA ADD BUY" : "IchiEA ADD SELL";
   else
      tag = (type == ORDER_TYPE_BUY) ? "IchiEA BUY" : "IchiEA SELL";

   bool ok;
   if (type == ORDER_TYPE_BUY)
      ok = trade.Buy(lotToUse, _Symbol, price, sl, 0, tag); // 0 = không đặt TP, đúng thiết kế chiến lược
   else
      ok = trade.Sell(lotToUse, _Symbol, price, sl, 0, tag);

   if (!ok)
   {
      Print("IchimokuChikouEA: mở lệnh thất bại, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      g_DbgOrderSendFail++;
      return false;
   }

   Print("IchimokuChikouEA: ", (isTest ? "[TEST] " : (isPyramid ? "[CỘNG LỆNH] " : "")), "mở lệnh ", EnumToString(type),
         " lot=", DoubleToString(lotToUse, 2), " SL=", DoubleToString(sl, digits), " (không có TP - thoát theo tín hiệu ngược lại)");

   string dirIcon  = (type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string groupTag = isTest ? "🧪 [TEST] " : (isPyramid ? "➕ " : "");
   string actionTxt = isPyramid ? StringFormat("CỘNG LỆNH (đơn vị %d/%d)", g_PyramidUnits + 1, InpMaxPyramidUnits) : "MỞ LỆNH";
   string lotModeTxt = InpUseRiskPercent ? StringFormat(" (risk %.1f%%)", InpRiskPercent) : "";
   TelegramSendMessage(StringFormat("%s%s <b>%s %s</b> — %s\n\n📍 Giá vào: <b>%.2f</b>\n🛑 SL: %.2f (2 đáy/đỉnh tương đối gần nhất)\n🎯 TP: Không có — thoát khi Chikou cắt ngược lại\n💰 Lot: %.2f%s",
                                      groupTag, dirIcon, actionTxt, EnumToString(type), _Symbol, price, sl, lotToUse, lotModeTxt));
   return true;
}

//====================================================================
// I. Báo đóng lệnh về Telegram
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

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                    HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                    HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   long   dealType    = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   long   reason      = HistoryDealGetInteger(dealTicket, DEAL_REASON);
   string origDir     = (dealType == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   string reasonTxt   = (reason == DEAL_REASON_SL) ? "Dính SL" : (reason == DEAL_REASON_TP) ? "Đạt TP" : "Tín hiệu ngược lại/đóng khác";
   string resultIcon  = (profit >= 0) ? "✅" : "❌";

   TelegramSendMessage(StringFormat("%s <b>ĐÓNG LỆNH %s</b> — %s (%s)\n\n📍 Giá đóng: %.2f\n💵 Kết quả: <b>%s%.2f %s</b>",
                                      resultIcon, origDir, _Symbol, reasonTxt, closePrice,
                                      (profit >= 0 ? "+" : ""), profit, AccountInfoString(ACCOUNT_CURRENCY)));

   // Cả nhóm lệnh (lệnh gốc + các lệnh cộng thêm) đóng HẾT thì reset trạng thái pyramid về 0,
   // để lần vào lệnh tiếp theo bắt đầu 1 nhóm mới từ đầu.
   long stillOpenType = -1;
   if (GetOpenPosition(stillOpenType) == 0)
   {
      g_PyramidDir = 0;
      g_PyramidUnits = 0;
      g_PyramidExtremeRef = 0.0;
   }
}

//====================================================================
// J. Cập nhật dashboard
//====================================================================
void UpdateDashboard()
{
   if (!InpShowDashboard) return;

   SetLabel(DASH_PREFIX + "Title", StringFormat("=== IchimokuChikouEA (%s, %s) ===", _Symbol, EnumToString((ENUM_TIMEFRAMES)Period())), clrWhite);

   string lastTxt = (g_lastSignalBarTime == 0) ? g_lastSignalTxt
                     : StringFormat("[%s] %s", TimeToString(g_lastSignalBarTime, TIME_DATE | TIME_MINUTES), g_lastSignalTxt);
   SetLabel(DASH_PREFIX + "LastSignal", "Tín hiệu gần nhất: " + lastTxt, clrKhaki);

   long  posType   = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0 && PositionSelectByTicket(posTicket))
   {
      string dirTxt = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double slP   = PositionGetDouble(POSITION_SL);
      string posTxt = StringFormat("Lệnh: %s @ %.2f | SL %.2f | TP: không có", dirTxt, openP, slP);
      if (g_PyramidUnits > 1) posTxt += StringFormat(" | Đơn vị: %d/%d", g_PyramidUnits, InpMaxPyramidUnits);
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
// K. Phát hiện tín hiệu Chikou/Span B mỗi lần có nến mới trên khung EA
// đang chạy (vd M15), rồi xác nhận thêm trên khung lớn hơn (vd H1).
// Ngoài ra còn kiểm tra điều kiện CỘNG LỆNH (pyramiding) mỗi nến mới khi
// đang giữ lệnh -- xem chi tiết trong khối "Kiểm tra CỘNG LỆNH" bên dưới.
//====================================================================
void CheckSignal()
{
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (barTime != 0 && barTime != g_LastBarTime);
   if (barTime != 0) g_LastBarTime = barTime;
   if (!isNewBar) return;

   g_DbgBarsProcessed++;

   // --- Bước 1: tính Chikou/Span B trên khung đang chạy (dùng CLOSE[0]=nến vừa đóng vs RawSpanB(2*N1)) ---
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   int needClose = 2 * InpKijunPeriod + InpSenkouBPeriod + 5;
   if (CopyClose(_Symbol, PERIOD_CURRENT, 0, needClose, closeArr) < needClose) return;

   // shift=1 là nến VỪA ĐÓNG (an toàn, tránh repaint trên nến đang chạy); shift=2 là nến trước đó, để xét "vừa cắt".
   double spanBNow, spanBPrev;
   if (!ComputeRawSpanB(_Symbol, PERIOD_CURRENT, InpSenkouBPeriod, 1 + 2 * InpKijunPeriod, spanBNow)) return;
   if (!ComputeRawSpanB(_Symbol, PERIOD_CURRENT, InpSenkouBPeriod, 2 + 2 * InpKijunPeriod, spanBPrev)) return;

   double closeNow  = closeArr[1];
   double closePrev = closeArr[2];

   bool crossUp   = (closePrev <= spanBPrev) && (closeNow > spanBNow);
   bool crossDown = (closePrev >= spanBPrev) && (closeNow < spanBNow);

   // --- Xử lý THOÁT lệnh trước (tín hiệu ngược lại với lệnh đang mở) -- áp dụng bất kể có vào lệnh mới hay không ---
   long posType = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0)
   {
      bool shouldExit = (posType == POSITION_TYPE_BUY && crossDown) || (posType == POSITION_TYPE_SELL && crossUp);
      if (shouldExit)
      {
         Print("IchimokuChikouEA: Chikou cắt ngược lại qua Span B - đóng lệnh đang mở (không đợi TP)");
         CloseAllPositions();
         posTicket = 0;
         posType = -1;
         g_PyramidDir = 0;
         g_PyramidUnits = 0;
         g_PyramidExtremeRef = 0.0;
      }
   }

   // --- Kiểm tra CỘNG LỆNH (pyramiding): đang giữ lệnh, giá tạo đỉnh/đáy tương đối MỚI cực đoan hơn
   // theo hướng có lợi -- áp dụng ĐỘC LẬP với tín hiệu cắt Chikou/Span B ở trên, kiểm tra mỗi nến mới. ---
   if (InpUsePyramiding && posTicket != 0 && g_PyramidDir != 0 && g_PyramidUnits < InpMaxPyramidUnits)
   {
      int needSwingP = InpFractalBars + InpMaxSwingSearch + 5;
      double newExtreme = 0.0;

      if (g_PyramidDir == 1)
      {
         double highArrP[];
         ArraySetAsSeries(highArrP, true);
         if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwingP, highArrP) >= needSwingP)
            newExtreme = FindLatestSwingHigh(highArrP, ArraySize(highArrP), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
      }
      else
      {
         double lowArrP[];
         ArraySetAsSeries(lowArrP, true);
         if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwingP, lowArrP) >= needSwingP)
            newExtreme = FindLatestSwingLow(lowArrP, ArraySize(lowArrP), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
      }

      bool isMoreExtreme = (newExtreme > 0) &&
                           ((g_PyramidDir == 1 && newExtreme > g_PyramidExtremeRef) ||
                            (g_PyramidDir == -1 && newExtreme < g_PyramidExtremeRef));

      if (isMoreExtreme)
      {
         // Tính lại SL MỚI cho đơn vị cộng thêm (dùng 2 đáy/đỉnh tương đối gần nhất, đúng y hệt lúc vào lệnh gốc)
         double pyramidSl = 0.0;
         if (g_PyramidDir == 1)
         {
            double lowArrP2[];
            ArraySetAsSeries(lowArrP2, true);
            if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwingP, lowArrP2) >= needSwingP)
               pyramidSl = FindBuySlFromSwingLows(lowArrP2, ArraySize(lowArrP2), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
         }
         else
         {
            double highArrP2[];
            ArraySetAsSeries(highArrP2, true);
            if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwingP, highArrP2) >= needSwingP)
               pyramidSl = FindSellSlFromSwingHighs(highArrP2, ArraySize(highArrP2), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
         }

         if (pyramidSl > 0 && InpSlBufferAtr > 0 && g_AtrHandleEntry != INVALID_HANDLE)
         {
            double atrEntryP[];
            if (CopyBuffer(g_AtrHandleEntry, 0, 1, 1, atrEntryP) >= 1)
            {
               double bufP = InpSlBufferAtr * atrEntryP[0];
               pyramidSl = (g_PyramidDir == 1) ? (pyramidSl - bufP) : (pyramidSl + bufP);
            }
         }

         if (OpenPosition(g_PyramidDir == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, pyramidSl, false, true))
         {
            g_PyramidExtremeRef = newExtreme;
            g_PyramidUnits++;
            g_DbgPyramidAdded++;
         }
      }
   }

   if (!crossUp && !crossDown) return;
   if (crossUp) g_DbgCrossUp++;
   if (crossDown) g_DbgCrossDown++;

   if (InpOnePositionOnly && posTicket != 0)
   {
      g_DbgBlockedDupSignal++;
      return; // vẫn còn lệnh CÙNG HƯỚNG đang mở (không bị đóng ở bước trên) -- chặn tín hiệu vào lệnh MỚI trùng lặp (cộng lệnh ở khối trên dùng cơ chế trigger riêng, không đi qua đây)
   }

   int direction = crossUp ? 1 : -1;

   // --- Bước 2: xác nhận trên khung lớn hơn (vd H1) ---
   if (InpUseH1Filter)
   {
      double confirmClose[];
      ArraySetAsSeries(confirmClose, true);
      int needConfirm = 2 * InpKijunPeriod + InpSenkouBPeriod + 5;
      if (CopyClose(_Symbol, InpConfirmTimeframe, 0, needConfirm, confirmClose) < needConfirm)
      {
         g_DbgBlockedH1Filter++;
         return;
      }
      double confirmSpanBRaw; // Span B "hiện tại" của khung xác nhận (không dịch chuyển -- chỉ cần vị trí giá so với mây B gốc tại đây, đúng ý video: "giá phải ở phía thuận lợi so với Span B")
      if (!ComputeRawSpanB(_Symbol, InpConfirmTimeframe, InpSenkouBPeriod, 1, confirmSpanBRaw))
      {
         g_DbgBlockedH1Filter++;
         return;
      }
      double confirmPrice = confirmClose[1];

      bool sideOK = (direction == 1) ? (confirmPrice > confirmSpanBRaw) : (confirmPrice < confirmSpanBRaw);
      if (!sideOK)
      {
         Print("IchimokuChikouEA: bị chặn bởi bước xác nhận khung lớn (giá không ở đúng phía Span B)");
         g_DbgBlockedH1Filter++;
         return;
      }

      if (InpConfirmMinDistAtr > 0 && g_AtrHandleConfirm != INVALID_HANDLE)
      {
         double atrConfirm[];
         if (CopyBuffer(g_AtrHandleConfirm, 0, 1, 1, atrConfirm) >= 1)
         {
            double dist = MathAbs(confirmPrice - confirmSpanBRaw);
            if (dist < InpConfirmMinDistAtr * atrConfirm[0])
            {
               Print("IchimokuChikouEA: bị chặn bởi bước xác nhận khung lớn (khoảng cách đến Span B quá gần)");
               g_DbgBlockedH1Filter++;
               return;
            }
         }
      }
   }

   // --- Tính SL theo 2 đáy/đỉnh tương đối gần nhất (fractal), trên KHUNG ĐANG CHẠY ---
   double lowArr[], highArr[];
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(highArr, true);
   int needSwing = InpFractalBars + InpMaxSwingSearch + 5;
   double slPrice = 0.0;
   if (direction == 1)
   {
      if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwing, lowArr) >= needSwing)
         slPrice = FindBuySlFromSwingLows(lowArr, ArraySize(lowArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
   }
   else
   {
      if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwing, highArr) >= needSwing)
         slPrice = FindSellSlFromSwingHighs(highArr, ArraySize(highArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
   }

   // Đệm thêm 1 khoảng nhỏ ra ngoài đáy/đỉnh (tùy chọn) để tránh SL bị chạm do "râu nến"
   if (slPrice > 0 && InpSlBufferAtr > 0 && g_AtrHandleEntry != INVALID_HANDLE)
   {
      double atrEntry[];
      if (CopyBuffer(g_AtrHandleEntry, 0, 1, 1, atrEntry) >= 1)
      {
         double buf = InpSlBufferAtr * atrEntry[0];
         slPrice = (direction == 1) ? (slPrice - buf) : (slPrice + buf);
      }
   }

   g_lastSignalTxt = StringFormat("%s @ %.2f", (direction == 1 ? "BUY" : "SELL"), closeNow);
   g_lastSignalBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);

   if (OpenPosition(direction == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, slPrice, false))
   {
      if (direction == 1) g_DbgBuyOpened++; else g_DbgSellOpened++;
      // Khởi tạo trạng thái nhóm lệnh cho tính năng cộng lệnh (pyramiding) -- mốc bắt đầu
      // là giá đóng của nến tín hiệu, mọi đỉnh/đáy tương đối MỚI vượt mốc này mới được cộng thêm.
      g_PyramidDir = direction;
      g_PyramidUnits = 1;
      g_PyramidExtremeRef = closeNow;
   }
}

//====================================================================
// L. Vòng đời Expert
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(PriceDistanceToPoints(InpSlippageUSD) > 0 ? PriceDistanceToPoints(InpSlippageUSD) : 1);

   if (InpKijunPeriod <= 0 || InpSenkouBPeriod <= 0)
   {
      Print("IchimokuChikouEA: InpKijunPeriod/InpSenkouBPeriod phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpFractalBars <= 0)
   {
      Print("IchimokuChikouEA: InpFractalBars phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_AtrHandleEntry = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (g_AtrHandleEntry == INVALID_HANDLE)
      Print("IchimokuChikouEA: cảnh báo - không tạo được ATR handle khung vào lệnh, InpSlBufferAtr sẽ bị bỏ qua");

   if (InpUseH1Filter)
   {
      g_AtrHandleConfirm = iATR(_Symbol, InpConfirmTimeframe, InpConfirmAtrPeriod);
      if (g_AtrHandleConfirm == INVALID_HANDLE)
         Print("IchimokuChikouEA: cảnh báo - không tạo được ATR handle khung xác nhận, InpConfirmMinDistAtr sẽ bị bỏ qua");
   }

   g_LastBarTime = 0;

   // Khôi phục trạng thái pyramid ở mức cơ bản nếu EA khởi động lại khi đang có sẵn lệnh mở
   // (ví dụ mất kết nối/khởi động lại MT5 giữa chừng) -- không biết chính xác đã cộng lệnh bao
   // nhiêu lần trước đó nên coi như units=1, mốc tham chiếu lấy tại giá vào lệnh đang mở.
   long restoreType = -1;
   ulong restoreTicket = GetOpenPosition(restoreType);
   if (restoreTicket != 0 && PositionSelectByTicket(restoreTicket))
   {
      g_PyramidDir = (restoreType == POSITION_TYPE_BUY) ? 1 : -1;
      g_PyramidUnits = 1;
      g_PyramidExtremeRef = PositionGetDouble(POSITION_PRICE_OPEN);
      Print("IchimokuChikouEA: phát hiện lệnh đang mở khi khởi động lại EA - khôi phục trạng thái pyramid ở mức cơ bản (units=1). Nếu trước đó đã cộng lệnh nhiều lần, số đơn vị thực tế có thể cao hơn.");
   }

   Print("IchimokuChikouEA v1.01: OnInit THÀNH CÔNG -- EA bắt đầu chạy từ đây.");

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_AtrHandleEntry != INVALID_HANDLE) IndicatorRelease(g_AtrHandleEntry);
   if (g_AtrHandleConfirm != INVALID_HANDLE) IndicatorRelease(g_AtrHandleConfirm);
   DeleteDashboard();

   Print("IchimokuChikouEA: [CHẨN ĐOÁN] Tổng kết -- nến đã xử lý=", g_DbgBarsProcessed,
         " | crossUp=", g_DbgCrossUp, " (Buy mở thành công=", g_DbgBuyOpened, ")",
         " | crossDown=", g_DbgCrossDown, " (Sell mở thành công=", g_DbgSellOpened, ")",
         " | cộng lệnh (pyramid) thành công=", g_DbgPyramidAdded);
   Print("IchimokuChikouEA: [CHẨN ĐOÁN] Bị chặn bởi -- xác nhận khung lớn=", g_DbgBlockedH1Filter,
         " | spread=", g_DbgBlockedSpread, " | margin=", g_DbgBlockedMargin, " | free margin=", g_DbgBlockedFreeMargin,
         " | tín hiệu trùng khi đã có lệnh=", g_DbgBlockedDupSignal, " | lỗ quá ngưỡng ngày=", g_DbgBlockedDailyLoss,
         " | không đủ 2 đáy/đỉnh tương đối=", g_DbgBlockedNoSwing, " | gửi lệnh thất bại=", g_DbgOrderSendFail);
}

void OnTick()
{
   UpdateDashboard();
   CheckSignal();
}

//====================================================================
// M. Nút Test trên chart (Test TG / Test BUY / Test SELL) -- Test BUY/SELL
// tự tìm SL theo swing low/high thật (không bịa số), rồi gọi đúng
// OpenPosition() y hệt đường đi của tín hiệu thật.
//====================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == DASH_PREFIX + "BtnTestTg")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      bool tgOk = TelegramSendMessage(StringFormat("🧪 <b>TIN NHẮN TEST</b> — %s\n\nXác nhận Bot Token/Chat ID/định dạng HTML đang hoạt động đúng. Không liên quan lệnh giao dịch thật nào.", _Symbol));
      Alert(tgOk ? "IchimokuChikouEA [TEST]: Đã gửi tin nhắn test lên Telegram thành công."
                  : "IchimokuChikouEA [TEST]: Gửi tin Telegram THẤT BẠI -- kiểm tra Bot Token/Chat ID hoặc whitelist api.telegram.org.");
   }
   else if (sparam == DASH_PREFIX + "BtnTestBuy" || sparam == DASH_PREFIX + "BtnTestSell")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ENUM_ORDER_TYPE testType = (sparam == DASH_PREFIX + "BtnTestBuy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      long existingType = -1;
      if (GetOpenPosition(existingType) != 0)
      {
         Alert("IchimokuChikouEA [TEST]: Bỏ qua -- đã có lệnh đang mở, tránh chồng lệnh.");
         return;
      }

      double lowArr[], highArr[];
      ArraySetAsSeries(lowArr, true);
      ArraySetAsSeries(highArr, true);
      int needSwing = InpFractalBars + InpMaxSwingSearch + 5;
      double slPrice = 0.0;
      if (testType == ORDER_TYPE_BUY)
      {
         if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwing, lowArr) >= needSwing)
            slPrice = FindBuySlFromSwingLows(lowArr, ArraySize(lowArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
      }
      else
      {
         if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwing, highArr) >= needSwing)
            slPrice = FindSellSlFromSwingHighs(highArr, ArraySize(highArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
      }

      bool openOk = OpenPosition(testType, slPrice, true);
      Alert(openOk ? StringFormat("IchimokuChikouEA [TEST]: Đã mở lệnh %s thành công -- xem chi tiết trong Journal.", EnumToString(testType))
                    : StringFormat("IchimokuChikouEA [TEST]: Mở lệnh %s THẤT BẠI -- xem Journal để biết lý do.", EnumToString(testType)));
   }
}
//+------------------------------------------------------------------+
