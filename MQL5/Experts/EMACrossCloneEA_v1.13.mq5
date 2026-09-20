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
//|  v1.07 (2026-09-19): them dong hien thi LAI/LO TRONG NGAY tinh theo  |
//|  PIP (khong phai USD/USC) tren goc chart, qua Comment() -- cap nhat   |
//|  MOI TICK, tu dong VE 0 khi sang ngay moi (server time) vi luon tinh   |
//|  lai TU DAU tu nua dem hom nay (khong luu bien dem cong don -- vua an  |
//|  toan qua restart EA, vua tu reset dung ngay khong can code rieng).    |
//|  Gom 2 phan: (1) TAT CA lenh CUA CHINH EA NAY (Symbol+Magic) DA DONG   |
//|  ke tu 00:00 hom nay, quy doi chenh lech gia mo/dong ve pip; (2) lenh  |
//|  DANG MO hien tai (neu co), tinh lai/lo CHUA THUC HIEN theo gia hien   |
//|  tai. KHONG doi bat ky logic giao dich/Telegram nao cua v1.06.        |
//+------------------------------------------------------------------+
//|  v1.08 (2026-09-19): 2 tinh nang moi theo yeu cau:                    |
//|   (1) Lot theo % RISK (InpUseRiskPercent, mac dinh BAT, InpRiskPercent |
//|       mac dinh 3.0) thay the lot co dinh InpLotSize -- tinh sao cho    |
//|       neu gia di dung khoang cach SL (ATR*InpSLAtrMult) thi mat dung   |
//|       InpRiskPercent% Balance. InpLotSize van giu lai lam gia tri du   |
//|       phong khi thieu du lieu symbol de tinh (vd tick value/size loi). |
//|   (2) Tu dong DUNG VAO LENH MOI (khong dong lenh dang mo) khi lo trong |
//|       ngay (thuc hien + chua thuc hien, tinh theo USD/USC, cua CHINH   |
//|       EA nay) vuot qua InpMaxDailyLossUSD (mac dinh 15.0) -- gui 1 tin  |
//|       Telegram DUY NHAT/ngay luc vua cham nguong (khong spam moi lan   |
//|       tin hieu bi chan sau do), tu dong "mo khoa" lai vao sang hom sau  |
//|       vi luon tinh lai tu moc 00:00 hom nay (giong CalcDayPips()).     |
//|  KHONG doi logic tin hieu/TP-SL/Telegram mo-dong lenh nao cua v1.07.  |
//+------------------------------------------------------------------+
//|  v1.09 (2026-09-19): "lam dep" 2 cho theo yeu cau -- KHONG doi logic   |
//|  giao dich/tin hieu/risk/circuit-breaker nao ca:                       |
//|   (1) Thay dong Comment() 1 dong don gian bang 1 bang trang thai       |
//|       (OBJ_LABEL, co khung nen OBJ_RECTANGLE_LABEL phia sau) o goc     |
//|       tren-trai chart -- 4 dong: tieu de, lai/lo hom nay (pip + USD,   |
//|       to mau xanh/do), lenh dang mo (huong/gia/SL/TP neu co), va       |
//|       trang thai circuit-breaker (Binh thuong / TAM DUNG).             |
//|   (2) Tin nhan Telegram doi sang parse_mode=HTML (in dam <b>) va gui   |
//|       qua POST thay vi GET (an toan hon voi HTML, tranh lap lai loi    |
//|       WebRequest 4002 tung gap voi MarketReport_EA khi ket hop         |
//|       parse_mode + payload dai qua GET) -- bo cuc lai gon, ro rang     |
//|       hon cho ca 3 loai tin (mo lenh/dong lenh/canh bao lo ngay).      |
//+------------------------------------------------------------------+
//|  v1.10 (2026-09-19): CHI doi ban quyen tu "HaiDangVN" sang         |
//|  "Gold Hunter" theo yeu cau, va cap nhat gia tri mac dinh cua       |
//|  InpIndicatorFileName sang "EMACrossClone_v1.06" (indicator cung    |
//|  doi ban quyen tuong ung) -- KHONG doi bat ky dong logic nao khac. |
//+------------------------------------------------------------------+
//|  v1.11 (2026-09-19): them 2 nut TEST tren chart (OBJ_BUTTON, ngay   |
//|  duoi bang trang thai) theo yeu cau, de kiem tra khong can cho tin  |
//|  hieu that hay cho thi truong mo cua:                               |
//|   - "Test TG": gui 1 tin Telegram mau (khong dung lenh giao dich    |
//|     that nao ca -- an toan tuyet doi, chi xac nhan Bot Token/Chat   |
//|     ID/dinh dang HTML dang hoat dong dung).                         |
//|   - "Test BUY" / "Test SELL": goi THANG OpenPosition() -- di qua    |
//|     dung TOAN BO luong that (circuit breaker lo ngay, spread, ATR,  |
//|     lot theo risk%, margin, dat lenh SL/TP, thong bao Telegram)     |
//|     nhu 1 tin hieu that, CHI KHAC la do nguoi bam nut kich hoat     |
//|     thay vi EMA cross. Gan nhan "TEST" vao comment lenh + tin       |
//|     Telegram de phan biet ro voi lenh do tin hieu that tao ra. Neu  |
//|     da co lenh dang mo (Symbol+Magic nay) thi TU CHOI, tranh chong  |
//|     lenh khi bam nham nhieu lan.                                    |
//|  Bat/tat qua InpShowTestButtons (mac dinh BAT). KHONG doi logic     |
//|  tin hieu/risk/circuit-breaker/Telegram nao cua v1.09/v1.10.        |
//+------------------------------------------------------------------+
//|  v1.12 (2026-09-19): them Alert() popup xac nhan ngay tren man hinh  |
//|  MT5 khi bam 1 trong 3 nut Test -- truoc day CHI ghi vao Journal,    |
//|  de bi bo qua khien nguoi dung tuong chua bam duoc, bam lap lai      |
//|  (khong phai loi code double-fire, chi la thieu phan hoi truc quan). |
//|  KHONG doi logic nao khac cua v1.11.                                |
//+------------------------------------------------------------------+
//|  v1.13 (2026-09-20): them CHE DO 2 TP (TP1/TP2) + doi SL ve         |
//|  breakeven -- dung y het co che da kiem chung trong TelegramSignal_EA|
//|  va EMACross_EA cua cung du an:                                     |
//|   - InpUseDualTpMode (mac dinh BAT): moi tin hieu chia lam 2 lenh    |
//|     (TP1 va TP2) cung 1 SL thay vi 1 lenh don. Khi lenh TP1 dong DO  |
//|     DAT TP (khong phai dinh SL), lenh TP2 con lai TU DONG doi SL ve  |
//|     dung gia vao lenh (breakeven) -- xau nhat chi hoa von, khong bao |
//|     gio bien 1 lan dang thang thanh thua han. Neu TP1 dinh SL (khong |
//|     phai dat TP), dong luon ca TP2 (chung 1 SL, coi nhu ca cap da    |
//|     thua).                                                          |
//|   - false = giu nguyen 1 lenh don nhu v1.12 (InpTPAtrMult lam TP).   |
//|   - Them InpTP1AtrMult (TP lenh 1, chi dung khi dual mode).          |
//|   - "Dong lenh" o cac tinh huong khac (tin hieu Exit, tin hieu nguoc  |
//|     chieu) gio dong CA HAI chan (neu dang o dual mode) thay vi chi 1  |
//|     lenh nhu truoc -- dung ham CloseAllPositions() moi thay cho      |
//|     ClosePositionByTicket(openTicket) don le.                        |
//|  KHONG doi logic tin hieu/risk%/circuit-breaker/nut Test nao cua     |
//|  v1.12.                                                              |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.13"

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
input string InpIndicatorFileName        = "EMACrossClone_v1.06"; // Ten file indicator DA COMPILE trong MQL5\Indicators\ (khong ke duoi .ex5) -- PHAI khop dung ten bro dat, indicator PHAI la ban v1.05 tro len (da fix ca bug Sell lan bug "input group" lam lech vi tri tham so khi goi qua iCustom())
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

input group "=== [MOI v1.13] Che do 2 TP (TP1/TP2) + doi SL ve breakeven ==="
input bool   InpUseDualTpMode        = true;  // true: chia moi tin hieu lam 2 lenh TP1/TP2 cung SL; false: 1 lenh don (InpTPAtrMult lam TP, giong v1.12)
input double InpTP1AtrMult           = 1.5;   // TP lenh 1 = gia mo lenh -+ ATR * he so nay (chi dung khi InpUseDualTpMode=true)
input bool   InpMoveToBreakevenOnTp1 = true;  // Khi lenh TP1 dong DO DAT TP, doi SL lenh TP2 con lai ve dung gia vao lenh

input group "=== [MOI v1.08] Khoi luong lenh theo % RISK (thay the lot co dinh) ==="
input bool   InpUseRiskPercent = true;  // true: tu tinh lot theo % Balance (khuyen nghi); false: dung InpLotSize co dinh nhu cu
input double InpRiskPercent    = 3.0;   // % Balance chap nhan mat neu dinh dung SL (moi lenh thua se mat khoang muc nay % Balance)
input double InpMaxLotCap      = 1.0;   // Chan lot toi da (an toan, phong ngua tinh sai/Balance qua lon)

input group "=== [MOI v1.08] Tu dong DUNG VAO LENH MOI khi lo qua nguong trong ngay ==="
input bool   InpUseDailyLossLimit = true;  // Bat/tat tinh nang nay (KHONG dong lenh dang mo, chi chan lenh MOI)
input double InpMaxDailyLossUSD   = 15.0;  // Dung vao lenh moi khi lo hom nay (thuc hien + chua thuc hien) vuot qua muc nay (USD/USC)

input group "=== [MOI v1.06] Telegram - thong bao TRUC TIEP, 1 lop duy nhat ==="
input string InpTgBotToken = "";  // Token bot Telegram (@BotFather) - de rong = TAT thong bao, EA van giao dich binh thuong
input long   InpTgChatId   = 0;   // Chat ID nhan thong bao (channel/group/DM) - 0 = tat
input int    InpTgTopicId  = 0;   // message_thread_id neu gui vao 1 Topic cu the cua Group dang Forum (vd Topic "Signal GOLD"). 0 = gui vao topic mac dinh cua chat

input group "=== [MOI v1.07] Hien thi lai/lo trong ngay tinh theo PIP ==="
input bool   InpShowDayPips = true;  // Bat/tat dong Comment() hien thi lai/lo hom nay theo pip tren goc chart
input double InpPipSize     = 0.1;   // 1 pip = bao nhieu don vi gia (XAUUSD 2 so le: thuong 0.1 = 10 pip/$1; doi lai neu broker/quy uoc cua ban khac)

input group "=== [MOI v1.11] Nut TEST tren chart ==="
input bool InpShowTestButtons = true; // Bat/tat 3 nut Test TG/Test BUY/Test SELL ngay duoi bang trang thai

//+------------------------------------------------------------------+
//| GLOBALS                                                            |
//+------------------------------------------------------------------+
CTrade   trade;
int      g_CloneHandle = INVALID_HANDLE;
int      g_AtrHandle   = INVALID_HANDLE;
int      g_Slippage    = 3;
datetime g_LastBarTime  = 0;

//--- [MOI v1.13] Theo doi cap lenh TP1/TP2 dang mo (chi 1 cap tai 1 thoi diem, khop voi thiet ke
//    "khong pyramid" cua EA nay) -- de biet luc nao can doi SL lenh TP2 ve breakeven.
ulong g_tp1Ticket = 0;
ulong g_tp2Ticket = 0;

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
int g_DbgBlockedDailyLoss = 0; // [MOI v1.08] bi chan boi InpMaxDailyLossUSD (da lo qua nguong trong ngay)

//--- [MOI v1.08] Ngay (00:00 server time) cua lan gan nhat da gui canh bao Telegram "lo qua nguong" -- de
//    chi gui 1 lan DUY NHAT moi ngay (khong spam moi lan tin hieu bi chan sau do), tu dong "reset" khi
//    sang ngay moi vi so sanh voi dayStart moi tinh lai moi lan.
datetime g_DailyLossAlertDay = 0;

//--- [MOI v1.09] Bang trang thai tren chart (OBJ_LABEL + khung nen OBJ_RECTANGLE_LABEL)
#define DASH_PREFIX "EMAXEA_Dash_"

//--- [MOI v1.11] true trong luc OpenPosition() dang duoc goi TU NUT TEST (khong phai tu tin hieu that) --
//    dung de gan nhan "TEST" vao comment lenh + tin Telegram, phan biet ro voi lenh that.
bool g_IsTestTrigger = false;

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

// [SUA v1.09] Doi sang POST + parse_mode=HTML (thay vi GET + text thuong) de tin nhan co the
// in dam <b>...</b> cho de doc. Dung POST (than nam trong body, khong nam tren URL) thay vi GET
// vi da tung gap loi WebRequest 4002 trong MarketReport_EA khi ket hop parse_mode voi payload dai
// qua GET -- POST an toan hon, khong bi gioi han do dai URL.
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
   if (postLen > 0) ArrayResize(post, postLen - 1); // bo byte NULL cuoi chuoi -- WebRequest khong can

   ResetLastError();
   int res = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded\r\n", 5000, post, resultData, resultHeaders);
   if (res == -1)
   {
      Print("EMACrossCloneEA: gui Telegram that bai, loi ", GetLastError(),
            " -- kiem tra da whitelist https://api.telegram.org trong Tools->Options->Expert Advisors chua");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| [MOI v1.07] Lai/lo trong ngay tinh theo PIP -- tinh lai TU DAU moi   |
//| lan goi (khong luu bien cong don) -- vua an toan qua EA restart,     |
//| vua TU DONG reset ve 0 khi sang ngay moi vi luon lay moc 00:00 HOM   |
//| NAY (server time) lam diem bat dau, khong can code reset rieng.      |
//+------------------------------------------------------------------+

//--- Tim gia MO cua 1 vi the (theo position_id) tu lich su deal -- dung khi
//    vi the DA DONG (khong the PositionSelectByTicket duoc nua). LUU Y: ham
//    nay goi HistorySelectByPosition() se GHI DE selection lich su hien tai
//    cua terminal -- KHONG duoc goi ham nay long ben trong 1 vong lap dang
//    doc HistoryDealsTotal()/HistoryDealGetTicket() cua 1 HistorySelect()
//    khac, vi se lam sai lech chi so dang doc do (xem CalcDayPips() ben duoi
//    da tach lam 2 buoc rieng bach chinh vi ly do nay).
double GetPositionOpenPrice(ulong positionId)
{
   if (!HistorySelectByPosition(positionId)) return 0.0;
   int total = HistoryDealsTotal();
   for (int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if (ticket == 0) continue;
      if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return HistoryDealGetDouble(ticket, DEAL_PRICE);
   }
   return 0.0;
}

double CalcDayPips()
{
   double totalPips = 0.0;

   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);
   dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
   datetime dayStart = StructToTime(dtNow);
   datetime now = TimeCurrent();

   //--- Buoc 1: thu thap TOAN BO lenh CUA CHINH EA NAY (Symbol+Magic) DA DONG ke tu 00:00 hom nay --
   //    CHI thu thap vao mang tam (posId/closePrice/dealType), CHUA goi GetPositionOpenPrice() o day
   //    (xem ly do trong ghi chu cua ham do o tren).
   ulong  closedPosId[];
   double closedClose[];
   long   closedType[];
   int    closedCount = 0;

   if (HistorySelect(dayStart, now + 86400))
   {
      int total = HistoryDealsTotal();
      for (int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if (ticket == 0) continue;
         if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

         ArrayResize(closedPosId, closedCount + 1);
         ArrayResize(closedClose, closedCount + 1);
         ArrayResize(closedType,  closedCount + 1);
         closedPosId[closedCount] = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         closedClose[closedCount] = HistoryDealGetDouble(ticket, DEAL_PRICE);
         closedType[closedCount]  = HistoryDealGetInteger(ticket, DEAL_TYPE);
         closedCount++;
      }
   }

   //--- Buoc 2: RIENG BIET voi vong lap tren -- voi tung lenh da dong, tra gia MO qua GetPositionOpenPrice(),
   //    roi quy doi chenh lech gia ve pip (dau + neu co loi, dau - neu lo, tuy huong lenh goc).
   for (int k = 0; k < closedCount; k++)
   {
      double openPrice = GetPositionOpenPrice(closedPosId[k]);
      if (openPrice <= 0) continue;
      // dealType = huong cua DEAL DONG lenh (nguoc voi huong lenh goc) -- DEAL_TYPE_SELL nghia la
      // dang dong 1 lenh BUY (ban ra de dong) => loi neu gia dong > gia mo; nguoc lai la dong 1 lenh SELL.
      double priceDiff = (closedType[k] == DEAL_TYPE_SELL) ? (closedClose[k] - openPrice) : (openPrice - closedClose[k]);
      totalPips += priceDiff / InpPipSize;
   }

   //--- Buoc 3: cong them lai/lo CHUA THUC HIEN cua (cac) lenh CUA CHINH EA NAY dang mo ngay luc nay ---
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      long   type      = PositionGetInteger(POSITION_TYPE);
      double priceDiff = (type == POSITION_TYPE_BUY) ? (curPrice - openPrice) : (openPrice - curPrice);
      totalPips += priceDiff / InpPipSize;
   }

   return totalPips;
}

//+------------------------------------------------------------------+
//| [MOI v1.08] Lai/lo trong ngay tinh theo USD/USC (khong phai pip) -- |
//| dung rieng cho circuit breaker InpMaxDailyLossUSD. Don gian hon     |
//| CalcDayPips() nhieu vi DEAL_PROFIT/POSITION_PROFIT da la tien te    |
//| tai khoan san, khong can tra cuu gia mo qua HistorySelectByPosition.|
//+------------------------------------------------------------------+
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
         if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
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
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }

   return total;
}

//+------------------------------------------------------------------+
//| [MOI v1.08] Khoi luong lenh theo % RISK -- copy dung y het cong    |
//| thuc da dung/kiem chung trong TelegramSignal_EA.mq5 va              |
//| EMACross_EA.mq5 cua cung du an nay.                                 |
//+------------------------------------------------------------------+
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
   if (slDistancePrice <= 0) return InpLotSize; // khong tinh duoc khoang cach SL -- an toan, dung lot co dinh du phong

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0 || tickValue <= 0) return InpLotSize; // thieu du lieu symbol -- an toan, dung lot co dinh du phong

   double valuePerPriceUnit = tickValue / tickSize; // tien (theo tien te tai khoan) cho 1 lot khi gia doi 1 don vi
   if (valuePerPriceUnit <= 0) return InpLotSize;

   double lot = riskAmount / (slDistancePrice * valuePerPriceUnit);
   return MathMin(NormalizeLot(lot), InpMaxLotCap);
}

//+------------------------------------------------------------------+
//| [MOI v1.09] Bang trang thai tren chart -- thay the dong Comment() 1  |
//| dong don gian cua v1.07/v1.08. UpdateDashboard() (dien so lieu that,  |
//| can GetOpenPosition()) dat RIENG BEN DUOI, SAU khi GetOpenPosition()   |
//| duoc khai bao (MQL5 bien dich 1 lan tu tren xuong, ham phai khai bao  |
//| TRUOC diem goi no) -- CreateDashboard()/SetLabel()/DeleteDashboard()   |
//| khong can du lieu gi ca nen dat o day, truoc OnInit(), la du.          |
//+------------------------------------------------------------------+
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

// [MOI v1.11] Tao 1 nut OBJ_BUTTON tai vi tri (x,y), kich thuoc (w,h), mau nen bg.
// STATE=false ngay khi tao de dam bao khong bao gio bi ket o trang thai "dang nhan".
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
   string keys[] = {"Title", "DayPL", "Position", "Status"};
   int x = 10, y = 16, dy = 16;
   int panelW = 300, panelH = ArraySize(keys) * dy + 14;

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

   // [MOI v1.11] 3 nut Test ngay duoi khung nen -- xem OnChartEvent() ben duoi de biet xu ly khi bam.
   if (InpShowTestButtons)
   {
      int by = (y - 8) + panelH + 6;
      int bw = 90, bh = 22, gap = 6;
      CreateTestButton(DASH_PREFIX + "BtnTestTg",   "Test TG",   x, by, bw, bh, clrDarkSlateGray);
      CreateTestButton(DASH_PREFIX + "BtnTestBuy",  "Test BUY",  x + (bw + gap), by, bw, bh, clrDarkGreen);
      CreateTestButton(DASH_PREFIX + "BtnTestSell", "Test SELL", x + 2 * (bw + gap), by, bw, bh, clrMaroon);
   }
}

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); }

// [MOI v1.13] Tim ticket vi the (cua EA nay, symbol nay) co comment chua tag cho truoc (vd "TP1"/"TP2").
// Dat TRUOC OnInit() vi OnInit() can goi ham nay de khoi phuc cap TP1/TP2 sau khi EA restart.
ulong FindPositionByComment(string tag)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (StringFind(PositionGetString(POSITION_COMMENT), tag) >= 0) return ticket;
   }
   return 0;
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

   // [MOI v1.13] EA co the tu khoi dong lai giua chung (vd doi chart period, MT5 restart) -- khoi phuc
   // lai cap ticket TP1/TP2 dang mo (neu co) de breakeven van hoat dong dung sau khi restart. Tim theo
   // chuoi con "TP1"/"TP2" trong comment -- khop ca dang thuong ("EMACrossCloneEA TP1") lan dang TEST
   // ("EMACrossCloneEA TEST TP1"), vi FindPositionByComment() dung StringFind (chua chuoi con la du).
   if (InpUseDualTpMode)
   {
      g_tp1Ticket = FindPositionByComment("TP1");
      g_tp2Ticket = FindPositionByComment("TP2");
   }

   // v1.02: truoc day KHONG co dong nao xac nhan EA da khoi tao xong -- neu OnInit that bai (vi du sai
   // ten file indicator), cach duy nhat biet la thay Alert (de bo lo) hoac thay "khong co lenh nao" o
   // cuoi ma khong ro nguyen nhan. Gio in ro 1 dong ngay khi thanh cong, de bro luon xac nhan duoc EA
   // CO THAT SU chay tu dau backtest hay khong chi bang cach nhin dong dau tien trong tab Journal/Experts.
   Print("EMACrossCloneEA v", "1.05", ": OnInit THANH CONG -- indicator handle '", InpIndicatorFileName,
         "' va ATR handle rieng deu tao duoc. EA bat dau chay tu day.");

   if (InpShowDayPips || InpShowTestButtons) CreateDashboard(); // [MOI v1.09/v1.11]

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit -- v1.02: in TONG KET CHAN DOAN 1 lan duy nhat khi ket    |
//| thuc (het lich su backtest, hoac go EA khoi chart) -- xem changelog|
//| v1.02 o dau file de biet ly do them phan nay.                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); // xoa dong Comment() cu (phong khi con sot lai tu ban truoc)
   DeleteDashboard(); // [MOI v1.09]

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
         "tin hieu nguoc chieu nhung InpReverseOnOppositeSignal=false=", g_DbgBlockedNoReverse, " | ",
         "[MOI v1.08] bi chan boi InpMaxDailyLossUSD (da lo qua nguong trong ngay)=", g_DbgBlockedDailyLoss);
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
//| [MOI v1.09] Dien so lieu that vao bang trang thai -- dat SAU        |
//| GetOpenPosition() vi can goi ham do (MQL5 khai bao truoc, goi sau). |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   SetLabel(DASH_PREFIX + "Title", StringFormat("=== EMACrossCloneEA v1.09 (%s) ===", _Symbol), clrWhite);

   double dayPips = CalcDayPips();
   double dayUSD  = CalcDayProfitUSD();
   color  plClr   = (dayUSD >= 0) ? clrLimeGreen : clrTomato;
   SetLabel(DASH_PREFIX + "DayPL", StringFormat("Hom nay: %s%.1f pip (%s%.2f %s)",
             (dayPips >= 0 ? "+" : ""), dayPips, (dayUSD >= 0 ? "+" : ""), dayUSD, AccountInfoString(ACCOUNT_CURRENCY)), plClr);

   long  posType   = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0 && PositionSelectByTicket(posTicket))
   {
      string dirTxt = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double slP   = PositionGetDouble(POSITION_SL);
      // [MOI v1.13] O dual mode, hien ca TP1 va TP2 (2 lenh) thay vi chi 1 TP cua lenh dau tien tim thay.
      if (InpUseDualTpMode && g_tp1Ticket != 0 && g_tp2Ticket != 0)
      {
         double tp1P = 0, tp2P = 0;
         if (PositionSelectByTicket(g_tp1Ticket)) tp1P = PositionGetDouble(POSITION_TP);
         if (PositionSelectByTicket(g_tp2Ticket)) tp2P = PositionGetDouble(POSITION_TP);
         SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh: %s @ %.2f | SL %.2f | TP1 %.2f | TP2 %.2f", dirTxt, openP, slP, tp1P, tp2P), clrKhaki);
      }
      else
      {
         double tpP = PositionGetDouble(POSITION_TP);
         SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh: %s @ %.2f | SL %.2f | TP %.2f", dirTxt, openP, slP, tpP), clrKhaki);
      }
   }
   else
   {
      SetLabel(DASH_PREFIX + "Position", "Lenh: Khong co", clrSilver);
   }

   bool paused = (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0 && dayUSD <= -MathAbs(InpMaxDailyLossUSD));
   SetLabel(DASH_PREFIX + "Status", paused ? "Trang thai: TAM DUNG (lo qua nguong ngay)" : "Trang thai: Binh thuong",
             paused ? clrOrange : clrLimeGreen);
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
//| [MOI v1.13] Dong TAT CA lenh cua CHINH EA nay (Symbol+Magic) -- dung |
//| thay cho ClosePositionByTicket(1 ticket don) o cac tinh huong "dong  |
//| lenh dang mo" (tin hieu Exit, tin hieu nguoc chieu) -- vi o che do   |
//| InpUseDualTpMode co the co 2 lenh (TP1+TP2) cung luc, ca 2 deu can   |
//| dong, khong chi 1.                                                   |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      trade.PositionClose(ticket, g_Slippage);
   }
   g_tp1Ticket = 0;
   g_tp2Ticket = 0;
}

// [MOI v1.13] Khi lenh TP1 dong DO DAT TP, doi SL lenh TP2 con lai ve dung gia vao lenh (breakeven).
void MoveToBreakeven(ulong ticket)
{
   if (!PositionSelectByTicket(ticket)) return;
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSl = PositionGetDouble(POSITION_SL);
   double curTp = PositionGetDouble(POSITION_TP);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double newSl = NormalizeDouble(openPrice, digits);
   if (MathAbs(curSl - newSl) < _Point) return; // da o breakeven roi, khong sua lai
   if (trade.PositionModify(ticket, newSl, curTp))
      PrintFormat("EMACrossCloneEA: TP1 da dong (dat TP) - doi SL lenh TP2 (#%I64u) ve breakeven", ticket);
   else
      PrintFormat("EMACrossCloneEA: Loi doi SL ve breakeven cho lenh #%I64u: %d", ticket, trade.ResultRetcode());
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
   // [MOI v1.08] Circuit breaker: da lo qua InpMaxDailyLossUSD trong ngay hom nay (thuc hien + chua thuc
   // hien) thi DUNG VAO LENH MOI -- dat dau tien, TRUOC ca kiem tra spread/ATR, de khong lam gi them neu
   // da qua nguong. KHONG dong lenh dang mo (chi chan lenh MOI) -- dung theo yeu cau.
   if (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0)
   {
      double dayProfitUSD = CalcDayProfitUSD();
      if (dayProfitUSD <= -MathAbs(InpMaxDailyLossUSD))
      {
         Print("EMACrossCloneEA: da lo ", DoubleToString(dayProfitUSD, 2), " ", AccountInfoString(ACCOUNT_CURRENCY),
               " hom nay, vuot nguong InpMaxDailyLossUSD=", DoubleToString(InpMaxDailyLossUSD, 2),
               " -- TAM DUNG vao lenh MOI cho toi sang ngay mai (lenh dang mo, neu co, van duoc quan ly binh thuong)");
         g_DbgBlockedDailyLoss++;

         // Gui Telegram CANH BAO 1 LAN DUY NHAT moi ngay (khong spam moi lan tin hieu bi chan sau do).
         MqlDateTime dtNow;
         TimeToStruct(TimeCurrent(), dtNow);
         dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
         datetime dayStart = StructToTime(dtNow);
         if (g_DailyLossAlertDay != dayStart)
         {
            g_DailyLossAlertDay = dayStart;
            TelegramSendMessage(StringFormat("⚠️ <b>TẠM DỪNG VÀO LỆNH MỚI</b> — %s\n\nĐã lỗ <b>%.2f %s</b> hôm nay, vượt ngưỡng %.2f.\nLệnh đang mở (nếu có) vẫn được quản lý bình thường.\nTự mở lại vào sáng mai.",
                                               _Symbol, dayProfitUSD, AccountInfoString(ACCOUNT_CURRENCY), InpMaxDailyLossUSD));
         }
         return false;
      }
   }

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
   double sl = 0.0;

   if (InpSLAtrMult > 0)
      sl = (type == ORDER_TYPE_BUY) ? price - atr * InpSLAtrMult : price + atr * InpSLAtrMult;

   // [MOI v1.08] Lot theo % risk (khuyen nghi, mac dinh BAT) thay the lot co dinh InpLotSize -- tinh sao
   // cho neu gia di dung khoang cach SL (atr*InpSLAtrMult) thi mat dung InpRiskPercent% Balance.
   double slDistance = (InpSLAtrMult > 0) ? atr * InpSLAtrMult : 0.0;
   double totalLot = InpUseRiskPercent ? CalcRiskLot(slDistance) : InpLotSize;

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
   if (totalLot * marginReq > freeMargin)
   {
      Print("EMACrossCloneEA: khong du margin cho lenh lot=", DoubleToString(totalLot, 2));
      g_DbgBlockedFreeMargin++;
      return false;
   }

   // [MOI v1.11] Gan nhan "TEST" vao comment lenh neu duoc kich hoat tu nut Test BUY/SELL (khong phai
   // tu tin hieu EMA cross that) -- de phan biet ro trong lich su lenh/MT5 terminal.
   string testPrefix = g_IsTestTrigger ? "EMACrossCloneEA TEST " : "EMACrossCloneEA ";
   string dirIcon = (type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string testTag = g_IsTestTrigger ? "🧪 [TEST] " : "";
   string lotModeTxt = InpUseRiskPercent ? StringFormat(" (risk %.1f%%)", InpRiskPercent) : "";

   // [MOI v1.13] Khong o dual mode (giong het v1.12) -- 1 lenh don, InpTPAtrMult lam TP.
   if (!InpUseDualTpMode)
   {
      double tp = 0.0;
      if (InpTPAtrMult > 0)
         tp = (type == ORDER_TYPE_BUY) ? price + atr * InpTPAtrMult : price - atr * InpTPAtrMult;

      string tradeComment = testPrefix + ((type == ORDER_TYPE_BUY) ? "BUY" : "SELL");
      bool ok;
      if (type == ORDER_TYPE_BUY)
         ok = trade.Buy(totalLot, _Symbol, price, sl, tp, tradeComment);
      else
         ok = trade.Sell(totalLot, _Symbol, price, sl, tp, tradeComment);

      if (!ok)
      {
         Print("EMACrossCloneEA: mo lenh that bai, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         g_DbgOrderSendFail++;
         return false;
      }

      Print("EMACrossCloneEA: ", (g_IsTestTrigger ? "[TEST] " : ""), "mo lenh ", EnumToString(type), " lot=", DoubleToString(totalLot, 2),
            " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits), " (ATR=", DoubleToString(atr, _Digits), ")");

      TelegramSendMessage(StringFormat("%s%s <b>MỞ LỆNH %s</b> — %s\n\n📍 Giá vào: <b>%.2f</b>\n🛑 SL: %.2f\n🎯 TP: %.2f\n💰 Lot: %.2f%s",
                                         testTag, dirIcon, EnumToString(type), _Symbol, price, sl, tp, totalLot, lotModeTxt));
      return true;
   }

   // [MOI v1.13] Dual mode: chia lot lam 2, cung SL, khac TP (TP1 gan hon, TP2 xa hon) --
   // lenh 1 lam tron nua lot binh thuong, lenh 2 lay PHAN CON LAI cua tong lot (roi moi lam tron),
   // de tong 2 lenh luon sat dung totalLot nhat co the theo buoc lot cua broker.
   double legLot1 = NormalizeLot(totalLot / 2.0);
   double legLot2 = NormalizeLot(totalLot - legLot1);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double useTp1 = NormalizeDouble((type == ORDER_TYPE_BUY) ? price + atr * InpTP1AtrMult : price - atr * InpTP1AtrMult, digits);
   double useTp2 = NormalizeDouble((type == ORDER_TYPE_BUY) ? price + atr * InpTPAtrMult  : price - atr * InpTPAtrMult,  digits);

   bool ok1, ok2;
   if (type == ORDER_TYPE_BUY)
   {
      ok1 = trade.Buy(legLot1, _Symbol, price, sl, useTp1, testPrefix + "TP1");
      ok2 = trade.Buy(legLot2, _Symbol, price, sl, useTp2, testPrefix + "TP2");
   }
   else
   {
      ok1 = trade.Sell(legLot1, _Symbol, price, sl, useTp1, testPrefix + "TP1");
      ok2 = trade.Sell(legLot2, _Symbol, price, sl, useTp2, testPrefix + "TP2");
   }

   if (!ok1 && !ok2)
   {
      Print("EMACrossCloneEA: mo ca 2 lenh TP1/TP2 deu that bai, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      g_DbgOrderSendFail++;
      return false;
   }

   g_tp1Ticket = FindPositionByComment(testPrefix + "TP1");
   g_tp2Ticket = FindPositionByComment(testPrefix + "TP2");

   Print("EMACrossCloneEA: ", (g_IsTestTrigger ? "[TEST] " : ""), "mo tin hieu ", EnumToString(type),
         " SL=", DoubleToString(sl, _Digits), " TP1=", DoubleToString(useTp1, _Digits), "(#", g_tp1Ticket, ")",
         " TP2=", DoubleToString(useTp2, _Digits), "(#", g_tp2Ticket, ") Lot=", DoubleToString(legLot1, 2), "/", DoubleToString(legLot2, 2),
         " (ATR=", DoubleToString(atr, _Digits), ")");

   TelegramSendMessage(StringFormat("%s%s <b>MỞ LỆNH %s</b> — %s\n\n📍 Giá vào: <b>%.2f</b>\n🛑 SL: %.2f\n🎯 TP1: %.2f\n🎯 TP2: %.2f\n💰 Lot: %.2f + %.2f%s",
                                      testTag, dirIcon, EnumToString(type), _Symbol, price, sl, useTp1, useTp2, legLot1, legLot2, lotModeTxt));
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

   TelegramSendMessage(StringFormat("%s <b>ĐÓNG LỆNH %s</b> — %s (%s)\n\n📍 Giá đóng: %.2f\n💵 Kết quả: <b>%s%.2f %s</b>",
                                      resultIcon, origDir, _Symbol, reasonTxt, closePrice,
                                      (profit >= 0 ? "+" : ""), profit, AccountInfoString(ACCOUNT_CURRENCY)));

   // --- [MOI v1.13] Breakeven cho cap TP1/TP2 (chi ap dung khi dang o dual mode va cap nay ton tai) ---
   if (InpUseDualTpMode && InpMoveToBreakevenOnTp1 && (g_tp1Ticket != 0 || g_tp2Ticket != 0))
   {
      ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      bool  wasTp = (reason == DEAL_REASON_TP);

      if (posId == g_tp1Ticket && g_tp2Ticket != 0)
      {
         if (wasTp)
         {
            // TP1 THANG (dat TP) -- doi SL lenh TP2 con lai ve breakeven, de no tiep tuc chay an toan.
            MoveToBreakeven(g_tp2Ticket);
         }
         else
         {
            // TP1 dinh SL (khong phai dat TP) -- ca cap deu coi nhu da thua theo SL chung, dong not TP2.
            ClosePositionByTicket(g_tp2Ticket);
         }
         g_tp1Ticket = 0;
         g_tp2Ticket = 0;
      }
      else if (posId == g_tp2Ticket)
      {
         // TP2 dong truoc TP1 (gia chay thang qua ca 2 dich cung luc, hoac dinh SL truoc) -- khong can
         // lam gi them voi TP1 (no se tu dong/da dong theo dung SL/TP cua chinh no).
         g_tp1Ticket = 0;
         g_tp2Ticket = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Main tick handler -- gate theo nen moi. Doc shift=1 (nen da dong)  |
//| tu indicator -- ke ca khi InpC_ConfirmClose=false ben indicator,   |
//| EA nay van chi hanh dong tren nen da dong, giu an toan toi da.     |
//+------------------------------------------------------------------+
void OnTick()
{
   // [MOI v1.07, doi sang bang dep hon o v1.09] Dat TRUOC gate "nen moi" ben duoi co y -- can cap nhat
   // MOI TICK (khong phai moi nen) de lai/lo hien thi thay doi lien tuc theo gia thi truong.
   if (InpShowDayPips) UpdateDashboard();

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
   //    hieu vao lenh moi. Dung CloseAllPositions() (khong chi 1 ticket) vi o dual mode
   //    co the co ca 2 chan TP1/TP2 cung luc, ca 2 deu can dong.
   if (InpCloseOnExitSignal && exitSignal && openTicket != 0)
   {
      Print("EMACrossCloneEA: buffer Exit bao hieu, dong lenh #", openTicket);
      CloseAllPositions();
      openTicket = 0;
      openType = -1;
   }

   // 2) Tin hieu Buy
   if (buySignal && InpTradeOnBuySignal)
   {
      if (openTicket != 0 && openType == POSITION_TYPE_SELL)
      {
         if (InpReverseOnOppositeSignal)
         {
            Print("EMACrossCloneEA: tin hieu Buy nguoc chieu lenh Sell dang mo, dong lenh #", openTicket, " de dao chieu");
            CloseAllPositions();
            openTicket = 0; openType = -1;
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
            CloseAllPositions();
            openTicket = 0; openType = -1;
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
//| [MOI v1.11] Xu ly bam nut tren chart (Test TG / Test BUY / Test SELL).|
//| Dat o CUOI file (sau OpenPosition()/TelegramSendMessage()/           |
//| GetOpenPosition() da khai bao) vi ham nay goi lai ca 3 ham do.        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == DASH_PREFIX + "BtnTestTg")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); // bo trang thai "dang nhan" ngay, tranh nut bi ket
      Print("EMACrossCloneEA: [TEST] Da bam nut Test TG - gui tin nhan mau, KHONG dung lenh giao dich nao ca");
      bool tgOk = TelegramSendMessage(StringFormat("🧪 <b>TIN NHẮN TEST</b> — %s\n\nĐây là tin nhắn thử, xác nhận Bot Token/Chat ID/định dạng HTML đang hoạt động đúng. Không liên quan đến lệnh giao dịch thật nào.", _Symbol));
      // [MOI v1.12] Alert() hien popup NGAY tren man hinh MT5 -- truoc day chi ghi Journal, de bi bo qua
      // khien nguoi dung tuong chua bam duoc, bam lap lai (khong phai loi code, chi thieu phan hoi truc quan).
      if (tgOk)
         Alert("EMACrossCloneEA [TEST]: Da gui tin nhan test len Telegram thanh cong.");
      else
         Alert("EMACrossCloneEA [TEST]: Gui tin Telegram THAT BAI -- kiem tra InpTgBotToken/InpTgChatId hoac whitelist api.telegram.org (xem Journal de biet chi tiet).");
   }
   else if (sparam == DASH_PREFIX + "BtnTestBuy" || sparam == DASH_PREFIX + "BtnTestSell")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ENUM_ORDER_TYPE testType = (sparam == DASH_PREFIX + "BtnTestBuy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      // [MOI v1.11] Tranh chong lenh neu bam nham nhieu lan hoac da co lenh that dang mo -- giu dung
      // tinh than "1 lenh tai 1 thoi diem" cua EA nay (binh thuong duoc gate o OnTick(), o day phai tu
      // kiem tra rieng vi goi thang OpenPosition(), khong di qua OnTick()).
      long existingType = -1;
      if (GetOpenPosition(existingType) != 0)
      {
         Print("EMACrossCloneEA: [TEST] Da co lenh dang mo (Symbol+Magic nay) - bo qua Test ",
               EnumToString(testType), " de tranh chong lenh");
         TelegramSendMessage("🧪 <b>[TEST] Bỏ qua</b> — đã có lệnh đang mở, tránh chồng lệnh.");
         Alert("EMACrossCloneEA [TEST]: Bo qua -- da co lenh dang mo (Symbol+Magic nay), tranh chong lenh.");
         return;
      }

      Print("EMACrossCloneEA: [TEST] Da bam nut Test ", EnumToString(testType),
            " - ep mo 1 lenh that de kiem tra toan bo luong (SL/TP/lot/Telegram)");
      g_IsTestTrigger = true;
      bool openOk = OpenPosition(testType);
      g_IsTestTrigger = false;

      // [MOI v1.12] Alert() xac nhan NGAY ket qua (thanh cong hay ly do that bai) -- xem Journal de biet
      // chi tiet day du (spread/ATR/margin/OrderSend...), Alert() chi tom tat ngan gon de biet ngay.
      if (openOk)
         Alert("EMACrossCloneEA [TEST]: Da mo lenh ", EnumToString(testType), " thanh cong -- xem chi tiet SL/TP trong Journal.");
      else
         Alert("EMACrossCloneEA [TEST]: Mo lenh ", EnumToString(testType), " THAT BAI -- xem Journal de biet ly do (spread/ATR/margin/circuit breaker...).");
   }
}
//+------------------------------------------------------------------+
