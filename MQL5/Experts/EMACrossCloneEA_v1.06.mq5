//+------------------------------------------------------------------+
//|                                          EMACrossCloneEA.mq5     |
//|  EA "bam theo tin hieu" cua EMACrossClone.mq5 -- CHI BAO TU VIET  |
//|  (xem header EMACrossClone.mq5 de biet ro logic/muc do giong ban  |
//|  goc "MIK EMA Cross"). Kien truc giong het EMACrossFollower.mq5   |
//|  (ban cu, doc chi bao ben thu 3 qua iCustom()), NHUNG gio goi     |
//|  toi CHINH indicator cua minh -- nen KHONG CON rui ro sai kieu    |
//|  tham so / DLL / "Invalid period" nhu truoc nua (minh viet ca 2   |
//|  ben nen luon dam bao khop nhau tuyet doi).                       |
//|                                                                    |
//|  KIEN TRUC (giu nguyen tinh than da chot voi bro 2026-09-19):     |
//|   - Chi dung mui ten Buy/Sell cua EMACrossClone lam TRIGGER        |
//|     HUONG. Risk management (SL/TP/lot) la CUA RIENG EA nay.        |
//|   - 1 lenh tai 1 thoi diem (khong pyramid/DCA).                    |
//|   - Tin hieu nguoc chieu khi dang co lenh mo -> dong lenh cu roi   |
//|     mo lenh moi (reverse), theo InpReverseOnOppositeSignal.        |
//|   - Buffer Exit (rieng, tach khoi Buy/Sell) -> dong lenh dang mo   |
//|     bat ke huong, neu InpCloseOnExitSignal=true.                   |
//|   - SL/TP tinh theo boi so ATR RIENG cua EA (InpAtrPeriodEA), doc  |
//|     lap voi ATR noi bo cua EMACrossClone (InpATRPeriod).           |
//|                                                                    |
//|  CHECKLIST da trace bang tay truoc khi giao (theo quy trinh        |
//|  mql5-ea-logic-review cua du an nay):                              |
//|   1) Per-tick vs per-bar: OnTick() co gate theo g_LastBarTime ->   |
//|      OpenPosition()/dong lenh chi co the fire TOI DA 1 lan/nen,   |
//|      du gia nhay qua lai nhieu lan trong cung 1 nen (spread noise).|
//|   2) Directional correctness: SL/TP dung cong thuc CO DAU rieng    |
//|      cho BUY (- ATR cho SL, + ATR cho TP) va SELL (nguoc lai) --   |
//|      KHONG dung MathAbs() o dau ca.                                |
//|   3) Feature-interaction: da trace tinh huong "Exit va tin hieu    |
//|      nguoc chieu cung bao tren 1 nen" -- Exit xu ly TRUOC (dong    |
//|      lenh cu), sau do logic Buy/Sell tiep tuc binh thuong voi      |
//|      openTicket=0 -- khong bi kep giua 2 lop dong lenh chong nhau. |
//|   4) Mirror consistency: khoi xu ly Buy va khoi xu ly Sell la      |
//|      anh guong chinh xac cua nhau (da doi chieu tung dong).        |
//|   5) Khong co trinh bien dich MQL5/Strategy Tester that trong moi  |
//|      truong nay -- code nay CHUA duoc compile/backtest thuc te.    |
//|      Da tu kiem tra can bang ngoac/dau ngoac bang script rieng.    |
//|   6) De xuat: chay backtest CUC NGAN (vai ngay, khong phai vai     |
//|      nam) truoc tien de bat loi vao-lenh-lien-tuc som va re, roi   |
//|      moi chay backtest dai hon.                                    |
//+------------------------------------------------------------------+
//|  v1.01 (2026-09-19): EMACrossClone.mq5 (indicator) da tim ra va sua |
//|  xong 1 bug nghiem trong o v1.03 -- cong thuc EMA-cua-RSI bi "dau   |
//|  doc" thanh Infinity boi 1 gia tri RSI khong hop le o rat xa qua    |
//|  khu, khien buffer Sell KHONG BAO GIO co gia tri tren du lieu that  |
//|  (xem changelog EMACrossClone_v1.03.mq5 de biet chi tiet day du).   |
//|  EA nay (file rieng, KHONG chua logic RSI/EMA cua indicator) KHONG  |
//|  he bi anh huong boi bug do -- EA chi doc gia tri buffer Buy/Sell/  |
//|  Exit tu indicator, khong tu tinh RSI -- nen v1.01 KHONG doi bat ky |
//|  logic giao dich/risk nao ca. Da doi lai la:                       |
//|   - Doi mac dinh InpIndicatorFileName tu "EMACrossClone" thanh      |
//|     "EMACrossClone_v1.03" -- de tranh nham voi ban .ex5 cu (v1.00-  |
//|     v1.02) con sot lai trong thu muc Indicators\ neu bro da tung   |
//|     compile thu -- BAT BUOC kiem tra dung ten file .ex5 THAT SU bro |
//|     dat trong MetaEditor khop voi input nay truoc khi chay that.    |
//|   - Da doi chieu lai (Python script) toan bo 15 input truyen vao    |
//|     iCustom() so voi 15 input cua EMACrossClone_v1.03.mq5 -- khop   |
//|     DUNG THU TU va DUNG KIEU DU LIEU 15/15 (khong doi gi ve logic  |
//|     truyen tham so, chi xac nhan lai vi indicator vua doi version). |
//+------------------------------------------------------------------+
//|  v1.02 (2026-09-19): bro chay Strategy Tester ca thang 9 (M15) --   |
//|  KHONG co lenh nao ca, trong khi TU BRO GAN RIENG indicator len     |
//|  chart thi VAN co mui ten Buy/Sell binh thuong. Nghia la: chi bao   |
//|  van ra tin hieu, nhung EA (khoi vao lenh) lai khong "thay" hoac    |
//|  khong hanh dong duoc -- van de nam o BEN EA, khong phai chi bao.   |
//|                                                                    |
//|  Ly do CHUA THE ket luan ngay duoc (khong co Journal that de xem): |
//|   a) iCustom() trong OnInit() co the that bai (sai ten file '.ex5', |
//|      chua compile...) -> EA se Alert + INIT_FAILED va DUNG HOAN     |
//|      TOAN tu dau, khong bao gio vao OnTick() -- ket qua ben ngoai   |
//|      giong het "khong co lenh nao" nhung nguyen nhan la EA CHUA HE  |
//|      CHAY, khong lien quan gi toi tin hieu ca.                      |
//|   b) EA tao INDICATOR HANDLE RIENG cua no (voi bo tham so InpC_*    |
//|      cua chinh EA) -- neu bro sua tham so tren indicator GAN THU    |
//|      cong khac voi tham so mac dinh cua EA (InpC_*), thi 2 ben co   |
//|      the dang chay 2 bo tham so KHAC NHAU du cung 1 file .ex5.      |
//|   c) Tin hieu CO den EA nhung bi 1 lop loc/dieu kien trong          |
//|      OpenPosition() am tham chan (spread/ATR/margin) MA KHONG IN RA |
//|      LOG gi ca o 1 cho -- da phat hien 1 lo hong CU THE: kiem tra   |
//|      margin (OrderCalcMargin) truoc day return ngay khi that bai    |
//|      MA KHONG Print() gi ca -- da vA lai o v1.02.                   |
//|                                                                    |
//|  FIX v1.02: them BO DEM CHAN DOAN day du (giong tinh than da lam    |
//|  voi indicator) -- dem so lan buySignal/sellSignal/exitSignal THAT  |
//|  SU duoc EA doc duoc tu buffer (bat ke co vao lenh duoc hay khong), |
//|  va dem rieng so lan bi chan boi TUNG ly do (spread/ATR/margin/     |
//|  free-margin/pyramid/opposite-no-reverse/handle-fail). In toan bo   |
//|  bang tong ket 1 lan duy nhat trong OnDeinit() (cuoi backtest) --   |
//|  neu dbgBuySeen+dbgSellSeen=0 ca thang => chung minh EA KHONG thay  |
//|  tin hieu nao ca (nghi ngo (a) hoac (b) o tren); neu > 0 nhung van  |
//|  0 lenh => xem cot bi chan nhieu nhat de biet dung nguyen nhan (c). |
//|  Cung them Print() ngay khi OnInit() thanh cong (truoc day khong co |
//|  dong nao xac nhan EA da khoi tao xong) de bro biet chac EA co      |
//|  chay hay khong ngay tu dau backtest.                              |
//+------------------------------------------------------------------+
//|  v1.03 (2026-09-19): DA TIM RA VA SUA XONG nguyen nhan goc that su   |
//|  cua bug "0 lenh ca thang 9" -- xem chi tiet chanhelog EMACrossClone |
//|  _v1.05.mq5. Tom tat: indicator dung "input group "..."" de gom nhom |
//|  UI trong hop thoai Inputs, nhung cau lenh nay VAN chiem 1 slot rieng|
//|  trong danh sach tham so cua .ex5 -- khi EA nay goi iCustom() truyen |
//|  15 gia tri THEO VI TRI (dung chuan MQL5), moi gia tri bi lech dan   |
//|  sang nham bien ke tiep moi khi di qua 1 group, khien InpFastEMA/    |
//|  InpSlowEMA nhan gia tri rac -> OnInit() cua indicator that bai TREN  |
//|  MOI NEN, EA khong bao gio tao duoc handle -> 0 tin hieu, 0 lenh.     |
//|  Da xac nhan bang du lieu Journal [CHAN DOAN v1.04] that cua bro,     |
//|  khop 100% voi mo phong bang script. FIX nam ben indicator (v1.05 --  |
//|  bo toan bo "input group", giu nguyen 15 input that). EA nay (v1.03) |
//|  KHONG doi logic gi ca, CHI doi gia tri mac dinh cua                 |
//|  InpIndicatorFileName sang "EMACrossClone_v1.05" de tro dung ban da   |
//|  fix -- neu bro da tung doi thu cong sang ten khac trong Inputs tab,  |
//|  nho doi lai thanh "EMACrossClone_v1.05" truoc khi chay.             |
//+------------------------------------------------------------------+
//|  v1.05 (2026-09-19): CHI doi so version cho DONG BO voi indicator    |
//|  EMACrossClone_v1.05.mq5 (ca 2 file cung fix chung 1 bug goc, nen    |
//|  danh so giong nhau cho de theo doi cap doi/EA nao khop voi ban nao) |
//|  -- KHONG doi bat ky dong logic/code nao khac so voi v1.03 (v1.04 bi |
//|  bo qua, nhay thang len 1.05 de khop indicator).                     |
//+------------------------------------------------------------------+
//|  v1.06 (2026-09-19): them thong bao Telegram TRUC TIEP, 1 LOP DUY    |
//|  NHAT -- theo dung yeu cau: khong con qua nhieu tang nhu             |
//|  TelegramSignal_EA cu (khong con InpMirrorChatId/InpGroupChatId+     |
//|  Topic rieng/InpAdminUserId cho lenh dieu khien...) -- chi 1 bot      |
//|  token + 1 chat_id + 1 topic_id (tuy chon) duy nhat, bao thang vao   |
//|  dung 1 cho. Bao 2 su kien: (1) MO lenh (huong/gia/SL/TP) ngay sau   |
//|  trade.Buy()/Sell() thanh cong trong OpenPosition(); (2) DONG lenh    |
//|  (gia dong + loi/lo + ly do TP/SL/dong khac, doc qua DEAL_REASON)    |
//|  trong OnTradeTransaction() moi (ham nay chua ton tai o v1.05).      |
//|  KHONG doi bat ky dong logic giao dich/tin hieu/risk nao cua v1.05 -- |
//|  chi THEM thong bao thuan tuy, khong can Telegram (InpTgBotToken     |
//|  rong) thi EA hoat dong y het v1.05, khong anh huong gi.             |
//+------------------------------------------------------------------+
#property copyright "HaiDangVN"
#property version   "1.06"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Buffer indices cua EMACrossClone.mq5 (xem file do) -- CUA MINH,   |
//| khong phai doan mo tu Properties dialog nhu ban cu nua.            |
//+------------------------------------------------------------------+
#define CLONE_BUF_EMA_FAST 0
#define CLONE_BUF_EMA_SLOW 1
#define CLONE_BUF_BUY      2
#define CLONE_BUF_SELL     3
#define CLONE_BUF_EXIT     4

//+------------------------------------------------------------------+
//| INPUTS -- mirror 1:1 input cua EMACrossClone.mq5, DUNG THU TU     |
//| (truyen positional vao iCustom()) -- vi ca 2 ben la code cua minh, |
//| khop nhau tuyet doi, khong con phai doan kieu du lieu nhu ban cu.  |
//+------------------------------------------------------------------+
input group "=== EMACrossClone - 1. EMA Cross ==="
input int    InpC_FastEMA = 9;     // Chu ky EMA nhanh
input int    InpC_SlowEMA = 20;    // Chu ky EMA cham

input group "=== EMACrossClone - 2. Loc RSI ==="
input bool   InpC_UseRSIFilter = true;
input int    InpC_RSIPeriod    = 14;
input int    InpC_RSIFastMA    = 9;
input int    InpC_RSISlowMA    = 45;

input group "=== EMACrossClone - 3. Loc ATR (cua indicator) ==="
input int    InpC_ATRPeriod = 14;
input double InpC_MinATR    = 0.0;

input group "=== EMACrossClone - 4. Khung gio giao dich ==="
input bool   InpC_OnlyHourWindow = false;
input int    InpC_FromHour       = 7;
input int    InpC_ToHour         = 22;

input group "=== EMACrossClone - 5. Thoi diem xac nhan tin hieu ==="
input bool   InpC_ConfirmClose = true;
input int    InpC_BarsWait     = 0;

input group "=== EMACrossClone - 6. Ve tren chart ==="
input bool   InpC_DrawEMALines = true;
input double InpC_ArrowDistATR = 0.5;

input group "=== EA - Su dung tin hieu (mui ten lam trigger huong) ==="
input string InpIndicatorFileName        = "EMACrossClone_v1.05"; // Ten file indicator DA COMPILE trong MQL5\Indicators\ (khong ke duoi .ex5) -- PHAI khop dung ten bro dat, indicator PHAI la ban v1.05 tro len (da fix ca bug Sell lan bug "input group" lam lech vi tri tham so khi goi qua iCustom())
input bool   InpTradeOnBuySignal         = true;  // Vao lenh khi buffer Buy co gia tri (khac EMPTY_VALUE)
input bool   InpTradeOnSellSignal        = true;  // Vao lenh khi buffer Sell co gia tri
input bool   InpCloseOnExitSignal        = true;  // Dong lenh dang mo (bat ke huong) khi buffer Exit co gia tri
input bool   InpReverseOnOppositeSignal  = true;  // true = dong lenh nguoc chieu roi mo lenh moi theo tin hieu; false = bo qua tin hieu nguoc chieu khi dang co lenh mo

input group "=== EA - Risk management (DOC LAP voi logic ve/tin hieu cua indicator) ==="
input double InpLotSize        = 0.01;  // Lot co dinh moi lenh (khong DCA/martingale)
input int    InpAtrPeriodEA    = 14;    // ATR RIENG cua EA de tinh SL/TP (doc lap voi InpC_ATRPeriod cua indicator)
input double InpSLAtrMult      = 1.5;   // SL = gia mo lenh -+ ATR * he so nay
input double InpTPAtrMult      = 3.0;   // TP = gia mo lenh -+ ATR * he so nay
input double InpMaxSpreadUSD   = 0.0;   // Bo qua vao lenh moi neu spread > gia tri nay ($ price distance). 0 = tat
input int    InpMagic          = 990012;// Magic number (khac EMACrossFollower cu, tranh trung neu chay song song)
input double InpSlippageUSD    = 0.30;  // Do lech gia toi da chap nhan khi khop lenh ($ price distance)

input group "=== [MOI v1.06] Telegram - thong bao TRUC TIEP, 1 lop duy nhat ==="
input string InpTgBotToken = "";  // Token bot Telegram (@BotFather) - de rong = TAT thong bao, EA van giao dich binh thuong
input long   InpTgChatId   = 0;   // Chat ID nhan thong bao (channel/group/DM) - 0 = tat
input int    InpTgTopicId  = 0;   // message_thread_id neu gui vao 1 Topic cu the cua Group dang Forum (vd Topic "Signal GOLD"). 0 = gui vao topic mac dinh cua chat

//+------------------------------------------------------------------+
//| GLOBALS                                                            |
//+------------------------------------------------------------------+
CTrade   trade;
int      g_CloneHandle = INVALID_HANDLE;
int      g_AtrHandle   = INVALID_HANDLE;
int      g_Slippage    = 3;
datetime g_LastBarTime  = 0;

//--- v1.02: bo dem CHAN DOAN -- xem changelog v1.02 o dau file. Tat ca chi tang, khong reset trong
//    suot 1 lan chay EA, in tong ket 1 lan duy nhat trong OnDeinit().
int g_DbgBarsProcessed   = 0; // so nen moi da xu ly (OnTick vuot qua gate g_LastBarTime)
int g_DbgBuySeen         = 0; // so lan buySignal=true doc duoc tu buffer (bat ke sau do co vao lenh hay khong)
int g_DbgSellSeen        = 0;
int g_DbgExitSeen        = 0;
int g_DbgBuyOpened       = 0; // so lan THAT SU mo lenh Buy thanh cong
int g_DbgSellOpened      = 0;
int g_DbgBlockedSpread   = 0; // bi chan boi InpMaxSpreadUSD
int g_DbgBlockedAtrFail  = 0; // khong doc duoc ATR rieng cua EA
int g_DbgBlockedAtrZero  = 0; // ATR <= 0
int g_DbgBlockedMargin   = 0; // OrderCalcMargin that bai/tra ve 0 (v1.01 tro ve truoc: IM LANG, khong dem duoc)
int g_DbgBlockedFreeMargin = 0; // du margin tinh duoc nhung khong du free margin
int g_DbgBlockedPyramid  = 0; // tin hieu lap lai huong dang co lenh mo (khong pyramid, dung thiet ke)
int g_DbgBlockedNoReverse = 0; // tin hieu nguoc chieu nhung InpReverseOnOppositeSignal=false
int g_DbgOrderSendFail   = 0; // trade.Buy()/trade.Sell() goi duoc nhung broker/tester tra ve that bai
int g_DbgCopyBufferFail  = 0; // CopyBuffer() tu g_CloneHandle that bai (< 1 phan tu) -- truoc day IM LANG

//+------------------------------------------------------------------+
//| Market data helpers                                                |
//+------------------------------------------------------------------+
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
   if (!OrderCalcMargin(type, _Symbol, 1.0, price, margin))
      return 0.0;
   return margin;
}

//+------------------------------------------------------------------+
//| [MOI v1.06] Telegram - thong bao TRUC TIEP, 1 lop duy nhat (khong  |
//| mirror/group-topic-rieng/admin-DM nhu TelegramSignal_EA cu). Neu   |
//| InpTgBotToken rong hoac InpTgChatId=0 thi ham nay chi tra ve false,|
//| khong lam gi ca -- EA giao dich binh thuong, khong bi anh huong.   |
//+------------------------------------------------------------------+
string UrlEncode(const string text)
{
   uchar bytes[];
   int n = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   string result = "";
   for (int i = 0; i < n; i++)
   {
      uchar b = bytes[i];
      if (b == 0) break; // StringToCharArray ket thuc bang byte NULL
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

   string url = "https://api.telegram.org/bot" + InpTgBotToken + "/sendMessage?chat_id=" +
                IntegerToString(InpTgChatId) + "&text=" + UrlEncode(text);
   if (InpTgTopicId > 0)
      url += "&message_thread_id=" + IntegerToString(InpTgTopicId);

   char   post[];
   char   resultData[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, resultData, resultHeaders);
   if (res == -1)
   {
      Print("EMACrossCloneEA: gui Telegram that bai, loi ", GetLastError(),
            " -- kiem tra da whitelist https://api.telegram.org trong Tools->Options->Expert Advisors chua");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Slippage = PriceDistanceToPoints(InpSlippageUSD);
   if (g_Slippage <= 0) g_Slippage = 1;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(g_Slippage);

   g_CloneHandle = iCustom(_Symbol, _Period, InpIndicatorFileName,
      InpC_FastEMA, InpC_SlowEMA,
      InpC_UseRSIFilter, InpC_RSIPeriod, InpC_RSIFastMA, InpC_RSISlowMA,
      InpC_ATRPeriod, InpC_MinATR,
      InpC_OnlyHourWindow, InpC_FromHour, InpC_ToHour,
      InpC_ConfirmClose, InpC_BarsWait,
      InpC_DrawEMALines, InpC_ArrowDistATR);

   if (g_CloneHandle == INVALID_HANDLE)
   {
      Alert("EMACrossCloneEA: khong the tao handle cho indicator '", InpIndicatorFileName,
            "' -- kiem tra file da duoc compile va nam dung trong MQL5\\Indicators\\ chua. EA se khong chay.");
      return(INIT_FAILED);
   }

   g_AtrHandle = iATR(_Symbol, _Period, InpAtrPeriodEA);
   if (g_AtrHandle == INVALID_HANDLE)
   {
      Alert("EMACrossCloneEA: khong the tao handle ATR rieng cua EA.");
      return(INIT_FAILED);
   }

   g_LastBarTime = 0; // force-align vao nen moi ngay tick dau tien

   // v1.02: truoc day KHONG co dong nao xac nhan EA da khoi tao xong -- neu OnInit that bai (vi du sai
   // ten file indicator), cach duy nhat biet la thay Alert (de bo lo) hoac thay "khong co lenh nao" o
   // cuoi ma khong ro nguyen nhan. Gio in ro 1 dong ngay khi thanh cong, de bro luon xac nhan duoc EA
   // CO THAT SU chay tu dau backtest hay khong chi bang cach nhin dong dau tien trong tab Journal/Experts.
   Print("EMACrossCloneEA v", "1.05", ": OnInit THANH CONG -- indicator handle '", InpIndicatorFileName,
         "' va ATR handle rieng deu tao duoc. EA bat dau chay tu day.");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit -- v1.02: in TONG KET CHAN DOAN 1 lan duy nhat khi ket    |
//| thuc (het lich su backtest, hoac go EA khoi chart) -- xem changelog|
//| v1.02 o dau file de biet ly do them phan nay.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EMACrossCloneEA: [CHAN DOAN v1.05] Tong ket khi ket thuc -- ",
         "so nen da xu ly=", g_DbgBarsProcessed, " | ",
         "buySignal thay=", g_DbgBuySeen, " (mo lenh Buy thanh cong=", g_DbgBuyOpened, ") | ",
         "sellSignal thay=", g_DbgSellSeen, " (mo lenh Sell thanh cong=", g_DbgSellOpened, ") | ",
         "exitSignal thay=", g_DbgExitSeen);
   Print("EMACrossCloneEA: [CHAN DOAN v1.05] Chi tiet ly do BI CHAN (neu tin hieu thay > 0 nhung lenh mo=0, xem cot nao > 0 o day) -- ",
         "spread vuot nguong=", g_DbgBlockedSpread, " | ",
         "khong doc duoc ATR rieng cua EA=", g_DbgBlockedAtrFail, " | ",
         "ATR<=0=", g_DbgBlockedAtrZero, " | ",
         "OrderCalcMargin that bai/tra ve 0=", g_DbgBlockedMargin, " | ",
         "khong du free margin=", g_DbgBlockedFreeMargin, " | ",
         "trade.Buy()/Sell() goi duoc nhung broker/tester tu choi=", g_DbgOrderSendFail, " | ",
         "tin hieu lap lai huong dang co lenh (khong pyramid, dung thiet ke)=", g_DbgBlockedPyramid, " | ",
         "tin hieu nguoc chieu nhung InpReverseOnOppositeSignal=false=", g_DbgBlockedNoReverse);
   if (g_DbgBarsProcessed == 0)
      Print("EMACrossCloneEA: [CHAN DOAN v1.05] CANH BAO -- so nen da xu ly = 0! Nghia la OnTick() ",
            "chua bao gio chay qua duoc gate nen moi (g_LastBarTime) -- kiem tra lai co that su co du ",
            "lieu gia trong khoang thoi gian backtest da chon hay khong.");
   else if (g_DbgBuySeen == 0 && g_DbgSellSeen == 0)
      Print("EMACrossCloneEA: [CHAN DOAN v1.05] CANH BAO -- EA co xu ly nen (", g_DbgBarsProcessed,
            " nen) nhung KHONG BAO GIO doc duoc buySignal/sellSignal=true tu indicator -- nghia la handle ",
            "indicator RIENG cua EA (goi qua iCustom voi bo tham so InpC_*) khong thay tin hieu nao trong ",
            "khoang thoi gian nay, DU indicator gan rieng tren chart co ra mui ten. Kha nang cao: tham so ",
            "InpC_* cua EA dang KHAC voi tham so bro gan tren indicator khi test rieng, hoac indicator ",
            "InpIndicatorFileName EA dang goi la mot BAN KHAC (cu hon/loi) so voi ban bro test rieng tren chart.");

   if (g_CloneHandle != INVALID_HANDLE) IndicatorRelease(g_CloneHandle);
   if (g_AtrHandle   != INVALID_HANDLE) IndicatorRelease(g_AtrHandle);
}

//+------------------------------------------------------------------+
//| Tim lenh dang mo cua EA nay (1 lenh tai 1 thoi diem theo thiet ke)|
//| Tra ve ticket, hoac 0 neu khong co. outType nhan huong lenh.       |
//+------------------------------------------------------------------+
ulong GetOpenPosition(long &outType)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      outType = PositionGetInteger(POSITION_TYPE);
      return ticket;
   }
   outType = -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Dong 1 lenh theo ticket                                            |
//+------------------------------------------------------------------+
bool ClosePositionByTicket(ulong ticket)
{
   if (!trade.PositionClose(ticket, g_Slippage))
   {
      Print("EMACrossCloneEA: PositionClose Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Mo lenh moi theo huong, SL/TP tinh theo ATR rieng cua EA           |
//| v1.02: doi sang tra ve bool (thanh cong/that bai) va dem CHAN DOAN |
//| tai TUNG diem co the bi chan -- truoc day 1 so nhanh (OrderCalc-   |
//| Margin that bai) return IM LANG khong Print() gi ca, la 1 lo hong  |
//| co the khien ca thang khong co lenh nao ma khong ro ly do.         |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type)
{
   if (InpMaxSpreadUSD > 0 && CurrentSpreadPrice() > InpMaxSpreadUSD)
   {
      Print("EMACrossCloneEA: spread vuot InpMaxSpreadUSD, bo qua vao lenh nen nay");
      g_DbgBlockedSpread++;
      return false;
   }

   double atrBuf[];
   if (CopyBuffer(g_AtrHandle, 0, 1, 1, atrBuf) < 1)
   {
      Print("EMACrossCloneEA: khong doc duoc ATR rieng cua EA, bo qua vao lenh nen nay");
      g_DbgBlockedAtrFail++;
      return false;
   }
   double atr = atrBuf[0];
   if (atr <= 0)
   {
      Print("EMACrossCloneEA: ATR <= 0 (chua du du lieu?), bo qua vao lenh nen nay");
      g_DbgBlockedAtrZero++;
      return false;
   }

   double price = (type == ORDER_TYPE_BUY) ? CurrentAsk() : CurrentBid();
   double sl = 0.0, tp = 0.0;

   if (InpSLAtrMult > 0)
      sl = (type == ORDER_TYPE_BUY) ? price - atr * InpSLAtrMult : price + atr * InpSLAtrMult;
   if (InpTPAtrMult > 0)
      tp = (type == ORDER_TYPE_BUY) ? price + atr * InpTPAtrMult : price - atr * InpTPAtrMult;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = MarginRequiredPerLot(type, price);
   if (marginReq <= 0)
   {
      // v1.02 FIX: truoc day return IM LANG o day, khong Print() gi ca -- neu OrderCalcMargin() that bai
      // lien tuc (vi du do dieu kien tester/broker cu the) day co the la nguyen nhan CA THANG khong co
      // lenh nao ma khong de lai dau vet gi trong log. Gio luon bao ro + dem lai qua g_DbgBlockedMargin.
      Print("EMACrossCloneEA: OrderCalcMargin() that bai hoac tra ve 0 cho ", EnumToString(type),
            " -- bo qua vao lenh nen nay. Kiem tra ket noi broker/tester neu lap lai nhieu lan.");
      g_DbgBlockedMargin++;
      return false;
   }
   if (InpLotSize * marginReq > freeMargin)
   {
      Print("EMACrossCloneEA: khong du margin cho lenh lot=", DoubleToString(InpLotSize, 2));
      g_DbgBlockedFreeMargin++;
      return false;
   }

   bool ok;
   if (type == ORDER_TYPE_BUY)
      ok = trade.Buy(InpLotSize, _Symbol, price, sl, tp, "EMACrossCloneEA BUY");
   else
      ok = trade.Sell(InpLotSize, _Symbol, price, sl, tp, "EMACrossCloneEA SELL");

   if (!ok)
   {
      Print("EMACrossCloneEA: mo lenh that bai, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      g_DbgOrderSendFail++;
      return false;
   }

   Print("EMACrossCloneEA: mo lenh ", EnumToString(type), " lot=", DoubleToString(InpLotSize, 2),
         " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits), " (ATR=", DoubleToString(atr, _Digits), ")");

   // [MOI v1.06] Bao thang ve Telegram (1 lop duy nhat) - khong lam gi neu chua khai bao InpTgBotToken/InpTgChatId.
   string dirIcon = (type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   TelegramSendMessage(StringFormat("%s %s — Mo lenh %s\n📍 Gia: %.2f\n🛑 SL: %.2f\n🎯 TP: %.2f\n💰 Lot: %.2f",
                                      dirIcon, _Symbol, EnumToString(type), price, sl, tp, InpLotSize));
   return true;
}

//+------------------------------------------------------------------+
//| [MOI v1.06] Bat su kien DONG lenh cua CHINH EA nay (loc theo Magic +|
//| Symbol) -- bao ve Telegram gia dong + loi/lo + ly do (TP/SL/dong    |
//| khac, doc qua DEAL_REASON cua chinh deal, dang tin cay hon so sanh  |
//| gia thu cong). Ham nay KHONG ton tai o v1.05 -- moi hoan toan.      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
{
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;
   if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagic) return;
   if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return; // chi quan tam luc DONG lenh

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                    HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                    HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   long   dealType    = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   long   reason      = HistoryDealGetInteger(dealTicket, DEAL_REASON);
   string origDir     = (dealType == DEAL_TYPE_SELL) ? "BUY" : "SELL"; // deal dong nguoc huong voi lenh goc
   string reasonTxt   = (reason == DEAL_REASON_TP) ? "Dat TP" : (reason == DEAL_REASON_SL) ? "Dinh SL" : "Dong thu cong/khac";
   string resultIcon  = (profit >= 0) ? "✅" : "❌";

   TelegramSendMessage(StringFormat("%s %s — Dong lenh %s (%s)\n📍 Gia dong: %.2f\n💵 Ket qua: %.2f %s",
                                      resultIcon, _Symbol, origDir, reasonTxt, closePrice, profit, AccountInfoString(ACCOUNT_CURRENCY)));
}

//+------------------------------------------------------------------+
//| Main tick handler -- gate theo nen moi. Doc shift=1 (nen da dong)  |
//| tu indicator -- ke ca khi InpC_ConfirmClose=false ben indicator,   |
//| EA nay van chi hanh dong tren nen da dong, giu an toan toi da.     |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (barTime == 0 || barTime == g_LastBarTime)
      return;
   g_LastBarTime = barTime;
   g_DbgBarsProcessed++;

   double buyBuf[1], sellBuf[1], exitBuf[1];
   // v1.02 FIX: truoc day 3 dong nay return IM LANG neu CopyBuffer that bai -- neu handle indicator
   // cua EA co van de (vi du bi giai phong som, hoac khong du du lieu), EA se "cham" (khong lam gi ca)
   // MOI NEN, suot ca thang, ma khong 1 dong log nao giai thich tai sao. Gio luon dem + bao 1 lan.
   if (CopyBuffer(g_CloneHandle, CLONE_BUF_BUY,  1, 1, buyBuf)  < 1) { g_DbgCopyBufferFail++; if (g_DbgCopyBufferFail <= 3) Print("EMACrossCloneEA: CopyBuffer(Buy) that bai luc ", TimeToString(barTime), " -- handle indicator co van de?"); return; }
   if (CopyBuffer(g_CloneHandle, CLONE_BUF_SELL, 1, 1, sellBuf) < 1) { g_DbgCopyBufferFail++; if (g_DbgCopyBufferFail <= 3) Print("EMACrossCloneEA: CopyBuffer(Sell) that bai luc ", TimeToString(barTime), " -- handle indicator co van de?"); return; }
   if (CopyBuffer(g_CloneHandle, CLONE_BUF_EXIT, 1, 1, exitBuf) < 1) { g_DbgCopyBufferFail++; if (g_DbgCopyBufferFail <= 3) Print("EMACrossCloneEA: CopyBuffer(Exit) that bai luc ", TimeToString(barTime), " -- handle indicator co van de?"); return; }

   bool buySignal  = (buyBuf[0]  != EMPTY_VALUE && buyBuf[0]  > 0.0);
   bool sellSignal = (sellBuf[0] != EMPTY_VALUE && sellBuf[0] > 0.0);
   bool exitSignal = (exitBuf[0] != EMPTY_VALUE && exitBuf[0] > 0.0);

   if (buySignal)  g_DbgBuySeen++;
   if (sellSignal) g_DbgSellSeen++;
   if (exitSignal) g_DbgExitSeen++;

   // Phong thu: indicator la state machine 1 huong tai 1 thoi diem (crossUp/
   // crossDown loai tru nhau trong EMACrossClone.mq5) nen ve ly thuyet khong
   // the co ca Buy va Sell tren cung 1 nen -- neu xay ra (bug la?), khong
   // doan huong nao, bo qua nen do de an toan.
   if (buySignal && sellSignal)
   {
      Print("EMACrossCloneEA: CANH BAO bat thuong -- ca Buy va Sell buffer deu co gia tri tren cung 1 nen (",
            TimeToString(barTime), "), bo qua nen nay de tranh doan sai huong");
      return;
   }

   long   openType = -1;
   ulong  openTicket = GetOpenPosition(openType);

   // 1) Buffer Exit -- dong lenh dang mo, bat ke huong, truoc khi xu ly tin
   //    hieu vao lenh moi.
   if (InpCloseOnExitSignal && exitSignal && openTicket != 0)
   {
      Print("EMACrossCloneEA: buffer Exit bao hieu, dong lenh #", openTicket);
      if (ClosePositionByTicket(openTicket))
      {
         openTicket = 0;
         openType = -1;
      }
   }

   // 2) Tin hieu Buy
   if (buySignal && InpTradeOnBuySignal)
   {
      if (openTicket != 0 && openType == POSITION_TYPE_SELL)
      {
         if (InpReverseOnOppositeSignal)
         {
            Print("EMACrossCloneEA: tin hieu Buy nguoc chieu lenh Sell dang mo, dong lenh #", openTicket, " de dao chieu");
            if (ClosePositionByTicket(openTicket)) { openTicket = 0; openType = -1; }
         }
         else
         {
            Print("EMACrossCloneEA: tin hieu Buy nhung dang co lenh Sell mo va InpReverseOnOppositeSignal=false, bo qua");
            g_DbgBlockedNoReverse++;
         }
      }

      if (openTicket == 0)
      {
         if (OpenPosition(ORDER_TYPE_BUY)) g_DbgBuyOpened++;
      }
      else if (openType == POSITION_TYPE_BUY)
      {
         Print("EMACrossCloneEA: tin hieu Buy lap lai nhung dang co lenh Buy mo -- khong pyramid, bo qua (dung thiet ke)");
         g_DbgBlockedPyramid++;
      }
   }
   // 3) Tin hieu Sell (mirror logic cua Buy)
   else if (sellSignal && InpTradeOnSellSignal)
   {
      if (openTicket != 0 && openType == POSITION_TYPE_BUY)
      {
         if (InpReverseOnOppositeSignal)
         {
            Print("EMACrossCloneEA: tin hieu Sell nguoc chieu lenh Buy dang mo, dong lenh #", openTicket, " de dao chieu");
            if (ClosePositionByTicket(openTicket)) { openTicket = 0; openType = -1; }
         }
         else
         {
            Print("EMACrossCloneEA: tin hieu Sell nhung dang co lenh Buy mo va InpReverseOnOppositeSignal=false, bo qua");
            g_DbgBlockedNoReverse++;
         }
      }

      if (openTicket == 0)
      {
         if (OpenPosition(ORDER_TYPE_SELL)) g_DbgSellOpened++;
      }
      else if (openType == POSITION_TYPE_SELL)
      {
         Print("EMACrossCloneEA: tin hieu Sell lap lai nhung dang co lenh Sell mo -- khong pyramid, bo qua (dung thiet ke)");
         g_DbgBlockedPyramid++;
      }
   }
}
//+------------------------------------------------------------------+
