//+------------------------------------------------------------------+
//|                                            EMACrossClone.mq5     |
//|  Chi bao TU VIET (KHONG phai reverse-engineer / KHONG goi         |
//|  iCustom() toi indicator ben thu 3 nao ca) -- lay CAM HUNG tu     |
//|  chi bao dong goi san "MIK EMA Cross" (EMA9/20 cross + RSI14      |
//|  (EMA9/WMA45) + ATR + khung gio) ma bro da dung, nhung viet lai   |
//|  bang logic RIENG, TU GIAI THICH DUOC 100%, khong con phu thuoc   |
//|  vao file .ex5 dong goi cua ho nua (het loi INVALID_HANDLE, [4002]|
//|  ERR_ARRAY_OUT_OF_RANGE, "DLL loading is not allowed", "Invalid   |
//|  period" -- toan bo la trieu chung cua viec goi mot indicator     |
//|  dong ho ma minh khong co source, gio KHONG CON NUA vi day la     |
//|  code cua chinh minh).                                             |
//|                                                                    |
//|  QUAN TRONG -- MUC DO GIONG BAN GOC (da noi ro va duoc bro dong   |
//|  y 2026-09-19): day la 1 chi bao MOI, TU THIET KE theo tinh than  |
//|  "EMA cross + loc RSI + loc ATR + khung gio", KHONG PHAI ban clone |
//|  chinh xac cong thuc bi mat cua MIK EMA Cross (minh chua bao gio  |
//|  co source that cua ho, chi co ten input + gia tri mac dinh tu    |
//|  anh Properties dialog). Tin hieu Buy/Sell/Exit o day co the ra    |
//|  KHAC thoi diem/gia so voi ban goc -- day la 1 he thong doc lap,  |
//|  khong phai ban sao.                                               |
//|                                                                    |
//|  LOGIC (tu thiet ke, giai thich duoc tung dong):                  |
//|   - EMA nhanh (mac dinh 9) cat EMA cham (mac dinh 20) = tin hieu   |
//|     huong co ban (cross len = tang, cross xuong = giam).           |
//|   - Loc RSI: tinh RSI(14) tho, roi lam muot bang 2 duong trung     |
//|     binh khac chu ky tren CHINH day RSI do -- EMA nhanh (mac dinh  |
//|     9) va WMA cham (mac dinh 45). Neu EMA-cua-RSI > WMA-cua-RSI => |
//|     dong luong dang nghieng ve phia tang (xac nhan Buy); nguoc lai |
//|     xac nhan Sell. Day la ky thuat "MA cross ap dung len RSI" pho  |
//|     bien, tuong tu MACD nhung ap len RSI thay vi gia.              |
//|   - Loc ATR: neu bien dong (ATR) dang qua thap (< InpMinATR), BO   |
//|     QUA tin hieu Buy/Sell moi (thi truong qua yen, de nhieu) --    |
//|     mac dinh InpMinATR=0 nghia la TAT loc nay.                     |
//|   - Loc khung gio (tuy chon): chi cho phep tin hieu Buy/Sell MOI   |
//|     trong khung gio server quy dinh -- KHONG anh huong buffer Exit |
//|     (Exit la van an toan, luon duoc phep bao dong lenh bat ke gio).|
//|   - InpConfirmClose: true = xet cross tren nen DA DONG (shift=1),  |
//|     tranh repaint; false = xet ngay tren nen dang chay (shift=0),  |
//|     phan ung nhanh hon nhung co the doi tin hieu khi nen chua dong.|
//|   - InpBarsWait: so nen toi thieu giua 2 tin hieu Buy/Sell MOI     |
//|     lien tiep (chong nhieu/whipsaw). Khong ap dung cho Exit.       |
//|   - Buffer Exit: rieng biet, kich hoat MOI KHI EMA cat nguoc lai   |
//|     (KHONG can RSI/ATR/gio xac nhan) -- coi day la "canh bao xu    |
//|     huong da doi", nen it dieu kien hon Buy/Sell co chu dich (ra    |
//|     som hon la vao tre).                                           |
//|                                                                    |
//|  Khong co trinh bien dich MQL5 that trong moi truong nay -- code   |
//|  nay CHUA duoc compile/chay thu thuc te. Da tu kiem tra can bang   |
//|  ngoac/dau ngoac bang script rieng truoc khi giao.                |
//+------------------------------------------------------------------+
//|  v1.01 (2026-09-19): bro bao chart THAT hoan toan khong co mui    |
//|  ten Sell nao, ke ca tren khung thoi gian co downtrend ro ret.     |
//|  Da mo phong lai dung cong thuc nay bang Python tren du lieu gia   |
//|  tong hop (nhieu nhip tang/giam ro rang) -- ket qua ra CAN BANG    |
//|  TUYET DOI (12 lan Buy duoc xac nhan / 12 lan Sell duoc xac nhan), |
//|  nghia la ve LY THUYET cong thuc nay KHONG thien lech ve 1 huong.  |
//|  Vi khong co trinh bien dich/du lieu that trong moi truong nay de  |
//|  tu kiem chung tiep, v1.01 them cac dong Print() CHAN DOAN (dem so |
//|  lan EMA cat len/xuong va so lan Buy/Sell duoc RSI xac nhan, in 1  |
//|  lan duy nhat khi tinh lai toan bo lich su vua tai) -- can bro gan  |
//|  lai vao chart va gui lai dong log nay (tab Experts) de co SO LIEU  |
//|  THAT, tu do moi xac dinh duoc dung nguyen nhan (loi RSI filter,   |
//|  loi ve/hien thi, hay hien tuong that cua thi truong).             |
//+------------------------------------------------------------------+
//|  v1.02 (2026-09-19): so lieu that tu terminal cua bro (111025 nen) |
//|  cho ket qua CUC DOAN: crossUp=2549 (Buy xac nhan=2548, ~100%) |    |
//|  crossDown=2549 (Sell xac nhan=0, 0%) -- da thu mo phong lai bang  |
//|  Python voi nhieu kich ban thi truong xu huong manh (bull dai han, |
//|  correction ngan/dat kieu chu V...) nhung KHONG kich ban nao tao   |
//|  ra do lech CUC DOAN toi muc "0 tren 2549, khong 1 ngoai le" nhu    |
//|  so that -- cac mo phong chi ra do lech 60-90%, va con DOI CHIEU    |
//|  tuy kich ban, chua bao gio ra dung 0% hoac 100% tuyet doi. Dieu    |
//|  nay cho thay day nhieu kha nang la 1 dac diem THAT cua du lieu     |
//|  (vi du RSI bi "ghim" gan 100 qua lau do cong thuc Wilder trong     |
//|  mot xu huong tang qua manh/qua muot cua chinh XAUUSD), khong phai  |
//|   1 loi code don gian -- nhung van CAN xac nhan bang SO THAT truoc  |
//|  khi ket luan. v1.02 them Print() CHAN DOAN SAU HON: in ra gia tri  |
//|  SO THAT (RSI tho, EMA-RSI, WMA-RSI, chenh lech) cua 10 lan         |
//|  crossDown GAN NHAT trong lich su da tai, de xem chinh xac rWma     |
//|  dang cao hon rEma bao nhieu diem tai moi lan -- neu chenh lech RAT |
//|  LON va co he thong (vd luon > 10-15 diem) => nhieu kha nang la     |
//|  dac diem RSI bi ghim (bull market qua manh); neu chenh lech RAT   |
//|  NHO (vd chi 0.01-0.5 diem, "suyt nua thi qua") => day co the la    |
//|  dau hieu khac (vd nguong xac nhan qua khat khe voi du lieu that).  |
//+------------------------------------------------------------------+
//|  v1.03 (2026-09-19): bro gui log CHAN DOAN v1.02 that -- TIM RA    |
//|  DUNG NGUYEN NHAN: moi dong deu hien "rEma=inf" (Infinity that su, |
//|  khong phai EMPTY_VALUE=2147483647 chi la so lon), trong khi rWma  |
//|  van la so binh thuong (44-59). Day la bang chung TOAN HOC chac    |
//|  chan: inf > bat ky so nao = LUON DUNG => Buy luon xac nhan; inf < |
//|  bat ky so nao = LUON SAI => Sell khong bao gio xac nhan. Khop     |
//|  chinh xac 100% trieu chung da thay.                               |
//|                                                                    |
//|  Nguyen nhan goc: cong thuc EMA-cua-RSI (rsiEma) la cong thuc DE   |
//|  QUY (moi gia tri dua vao gia tri truoc do), nhung KHONG he kiem   |
//|  tra du lieu RSI tho (rsiArr, lay tu built-in iRSI qua CopyBuffer) |
//|  co hop le (huu han, trong khoang 0-100) hay khong truoc khi dua   |
//|  vao cong thuc. Neu chi CAN 1 nen nao do (thuong o vung rat xa qua |
//|  khu, luc cac indicator built-in con dang "khoi dong"/chua tinh    |
//|  du lieu lich su xong) ma rsiArr tra ve 1 gia tri khong huu han    |
//|  (NaN/Infinity thay vi RSI that), thi do la cong thuc DE QUY, gia  |
//|  tri hong nay se "lay lan" VINH VIEN cho TOAN BO hang tram nghin   |
//|  nen phia sau (vi rsiEma[k] luon phu thuoc rsiEma[k-1]) -- giai    |
//|  thich dung y het tai sao inf xuat hien deu dan suot nhieu ngay    |
//|  lien tuc, khong tu het. Con rWma (weighted MA) thi KHONG de quy   |
//|  (moi nen tinh lai tu dau bang dung 45 nen quanh no), nen 1 nen    |
//|  hong o rat xa qua khu se tu "troi qua" sau khi cua so 45 nen      |
//|  truot qua khoi diem loi -- giai thich dung y het tai sao rWma van |
//|  la so binh thuong o moi thoi diem gan day.                        |
//|                                                                    |
//|  FIX v1.03: viet lai rsiEma/rsiWma de LUON kiem tra tinh hop le    |
//|  cua moi gia tri RSI tho (dung MathIsValidNumber() + kiem tra nam  |
//|  trong [0,100]) TRUOC khi dua vao bat ky phep tinh nao. Neu gap 1  |
//|  gia tri khong hop le: rsiEma tai do danh dau EMPTY_VALUE va RESET |
//|  lai tu dau (doi du InpRSIFastMA nen hop le LIEN TIEP moi "seed"   |
//|  lai), thay vi de gia tri hong "ngam" vao cong thuc de quy. Ap     |
//|  dung tuong tu cho rsiWma va cho ca fastNow/slowNow/atrNow (loc    |
//|  dai them, chi phi khong dang ke) de tranh hoan toan kieu loi nay  |
//|  tai bat ky diem nao trong tuong lai, bat ke nguyen nhan sau xa la |
//|  gi (MT5 chua tai xong lich su, hay bat ky ly do runtime nao khac  |
//|  -- code gio KHONG THE bi "dau doc" vinh vien boi 1 gia tri hong   |
//|  nua). Giu nguyen toan bo Print() CHAN DOAN cua v1.02 + them dem   |
//|  so lan gia tri RSI tho bi phat hien khong hop le (dbgRsiInvalid)  |
//|  de xac nhan lai chan doan nay dung khi bro test lai.              |
//+------------------------------------------------------------------+
//|  v1.04 (2026-09-19): bro gui log that cua EMACrossCloneEA_v1.02    |
//|  chay backtest thang 9 (M15, XAUUSD) -- KY LA: dong Print() "InpFastEMA|
//|  phai > 0 va < InpSlowEMA" (validation trong OnInit) bi in ra LAP  |
//|  LAI o TUNG nen suot ca thang (1184 lan, khop voi so nen EA da xu   |
//|  ly), nghia la OnInit() dang bi goi lai MOI NEN va LUON that bai --  |
//|  DU tab Inputs cua EA xac nhan InpC_FastEMA=9, InpC_SlowEMA=20 (hop |
//|  le, da doi chieu code khop 15/15 tham so voi EA). Dieu nay ngu y   |
//|  gia tri THAT SU indicator nhan duoc trong OnInit() KHONG PHAI la   |
//|  9/20 nhu ky vong -- nhung chua the biet CHINH XAC gia tri gi vi    |
//|  Print() cu chi bao "sai" ma khong in ra con so that.               |
//|                                                                    |
//|  v1.04 KHONG sua logic gi ca (chua biet dung nguyen nhan de sua) -- |
//|  CHI them 1 dong Print() CHAN DOAN ngay truoc khi bao loi, in ra    |
//|  TOAN BO 15 gia tri input MA OnInit() NAY THAT SU NHAN DUOC (khong  |
//|  chi FastEMA/SlowEMA ma ca 13 input con lai) moi khi that bai kiem  |
//|  tra nay (gioi han 5 lan dau qua bo dem g_DbgInitFailPrints de       |
//|  tranh spam qua muc, nhung neu OnInit that bai lap lai vinh vien    |
//|  moi nen nhu log cho thay thi van co the in nhieu hon 5 dong tuy    |
//|  MT5 co giu duoc gia tri bien toan cuc g_DbgInitFailPrints qua cac  |
//|  lan goi lai OnInit() hay khong -- ban than dieu nay cung la 1 manh |
//|  moi: neu bo dem KHONG tang len (luon in lai tu dau), nghia la moi  |
//|  lan OnInit() la 1 THUC THE HOAN TOAN MOI, khong chia se bien toan  |
//|  cuc voi lan truoc). Can bro chay lai dung backtest thang 9 nay va   |
//|  gui lai vai dong Print() [CHAN DOAN v1.04] dau tien trong Journal  |
//|  de biet CHINH XAC gia tri nao dang bi sai/lech, tu do moi xac dinh |
//|  duoc day la loi truyen tham so qua iCustom(), file .ex5 khong dung |
//|  ban, hay 1 nguyen nhan runtime khac cua Strategy Tester.           |
//+------------------------------------------------------------------+
//|  v1.05 (2026-09-19): bro chay lai v1.04 dung cach (chon Expert =     |
//|  EMACrossCloneEA_v1.02, doi InpIndicatorFileName sang v1.04) va gui  |
//|  dong Journal [CHAN DOAN v1.04] dau tien:                            |
//|  InpFastEMA=20 InpSlowEMA=1 InpUseRSIFilter=true InpRSIPeriod=45     |
//|  InpRSIFastMA=14 InpRSISlowMA=0 InpATRPeriod=7 InpMinATR=22.0000     |
//|  InpOnlyHourWindow=false ...                                         |
//|                                                                       |
//|  DA MO PHONG LAI BANG SCRIPT VA KHOP CHINH XAC 100% TUNG SO MOT voi   |
//|  1 gia thuyet duy nhat: cau lenh "input group "..."" (chi de gom nhom |
//|  hien thi dep trong hop thoai Inputs) THAT RA van chiem 1 "slot" rieng|
//|  trong danh sach tham so cua chuong trinh da bien dich (.ex5). Indi-  |
//|  cator nay co 6 dong input group xen giua 15 input that -> tong cong  |
//|  21 slot. Khi EA goi iCustom() truyen 15 gia tri THEO VI TRI (positio-|
//|  nal) nhu dung chuan MQL5 (15 slot input that), moi gia tri lai bi    |
//|  "lech" dan vao slot thuc te tiep theo (ke ca slot group) moi khi di   |
//|  qua 1 ranh gioi group -- vi du gia tri 20 (dinh danh cho InpSlowEMA) |
//|  lai bi gan nham vao InpFastEMA, gia tri true cua InpUseRSIFilter bi  |
//|  ep kieu thanh so 1 roi gan nham vao InpSlowEMA (bien int) -- v.v. -- |
//|  cang ve sau cang lech nhieu hon vi di qua nhieu ranh gioi group hon,  |
//|  toi 4 input cuoi (InpConfirmClose, InpBarsWait, InpDrawEMALines,     |
//|  InpArrowDistATR) khong con gia tri nao de nhan nua, phai dung gia tri|
//|  mac dinh luc bien dich. Day chinh la ly do gan indicator TRUC TIEP    |
//|  len chart (Inputs dialog gan theo TEN bien, khong theo vi tri) luon   |
//|  chay dung, trong khi goi qua iCustom() tu EA (gan theo vi tri) luon   |
//|  sai -- khop 100% voi moi bang chung thu thap duoc tu dau den gio.     |
//|                                                                       |
//|  FIX v1.05: doi TOAN BO 6 dong "input group "..."" sang comment       |
//|  thuong (// ...) -- van giu nguyen thu tu/kieu/gia tri mac dinh cua   |
//|  toan bo 15 input that, chi bo di 6 "slot ma" khong can thiet. Sau    |
//|  fix nay indicator chi con dung 15 slot that su, khop 1:1 voi 15 gia  |
//|  tri EA truyen vao qua iCustom() -- het lech vi tri. Mat di viec gom  |
//|  nhom hien thi dep trong hop thoai Inputs (gio se hien thi thanh 1    |
//|  danh sach phang 15 dong), doi lai la iCustom() hoat dong dung.       |
//+------------------------------------------------------------------+
//|  v1.06 (2026-09-19): CHI doi ban quyen tu "HaiDangVN" sang         |
//|  "Gold Hunter" theo yeu cau -- KHONG doi bat ky dong logic nao ca. |
//+------------------------------------------------------------------+
//|  v1.07 (2026-09-21): SUA LAI CO CHE PHAT TIN HIEU Buy/Sell cho     |
//|  KHOP CHUAN MIK, theo quan sat truc tiep tren chart THAT cua       |
//|  nguoi dung: 2 lenh Sell khung H1 duoc mo ra khi MIK_EmaCross_     |
//|  Signal_v3.4 (ban goc cua MIK) bao SELL, nhung tai dung nen do KHONG|
//|  he co cross EMA9/EMA20 gia moi (2 duong da cheo nhau tu truoc do   |
//|  vai nen roi). Doi chieu voi source that su cua MIK_EmaCross_Signal|
//|  .mq5 (ham BarState()) xac nhan: MIK KHONG doi hoi phai co cross   |
//|  EMA gia TUOI tai chinh nen -- no tinh TRANG THAI TONG HOP moi nen |
//|  (huong EMA gia AND huong RSI-EMA9 so RSI-WMA45), roi CHI phat tin |
//|  hieu khi trang thai tong hop nay DOI so voi nen truoc (stCur !=   |
//|  stPrev). Trang thai co the doi vi RIENG ve RSI doi (du EMA gia da |
//|  cheo tu som hon) -- day chinh la truong hop thuc te nguoi dung gap|
//|  phai. Ban v1.00-v1.06 cua file nay bat "phai co cross EMA gia tai |
//|  chinh nen" lam DIEU KIEN CAN de xet Buy/Sell -- sai le so voi MIK,|
//|  lam bo lo dung nhung tin hieu kieu nay.                           |
//|                                                                     |
//|  FIX v1.07: bo han dieu kien "if (!crossUp && !crossDown) continue"|
//|  o dau vong lap. Thay vao do, MOI nen deu tinh stateCur (1=Buy,     |
//|  -1=Sell, 0=Flat) tu huong EMA gia (priceBull/priceBear) KET HOP    |
//|  huong RSI (rsiBull/rsiBear, neu InpUseRSIFilter=true -- van GIU    |
//|  RSI la filter TUY CHON nhu thiet ke goc cua file nay, khac MIK coi |
//|  RSI la bat buoc), roi so sanh voi prevState (trang thai nen truoc  |
//|  do da xu ly) de quyet dinh co ve Buy/Sell hay khong -- dung y het  |
//|  co che stCur!=stPrev cua MIK_EmaCross_Signal.mq5. BufExit GIU      |
//|  NGUYEN hanh vi cu (canh bao som thuan tuy tu cross EMA gia, khong  |
//|  doi -- day la tinh nang rieng cua file nay, khong phai nguyen nhan |
//|  user bao loi). Cac filter ATR/gio/barsWait van ap dung y het cu,   |
//|  chi ap len dieu kien "trang thai doi" thay vi "co cross".          |
//+------------------------------------------------------------------+
//|  v1.08 (2026-09-21): THEM filter TUY CHON vung qua mua/qua ban,     |
//|  theo phan hoi thuc te cua nguoi dung: nhieu tin hieu Buy/Sell cua  |
//|  v1.07 (dung tren cross EMA that) van "khong dep" -- diem vao xau   |
//|  vi RSI da qua mua/qua ban sau, dang "duoi theo" song sap can, de   |
//|  bi hoi lai ngay sau khi vao lenh.                                  |
//|                                                                      |
//|  NGUYEN NHAN: filter RSI hien co (InpUseRSIFilter/rsiBull/rsiBear)   |
//|  chi xet HUONG 2 duong RSI-EMA9 vs RSI-WMA45 cat nhau, KHONG xet     |
//|  RSI THO dang o MUC nao -- nen van xac nhan Buy dung luc RSI thô da  |
//|  len toi 80-90 (qua mua sau), hoac Sell luc RSI da xuong 10-20 (qua  |
//|  ban sau).                                                           |
//|                                                                      |
//|  FIX v1.08: them 3 input MOI (InpUseRsiZoneFilter mac dinh FALSE --  |
//|  KHONG doi hanh vi mac dinh cua v1.07/MIK goc; InpRsiOverbought=70,  |
//|  InpRsiOversold=30). Khi bat len: chan xac nhan Buy MOI neu RSI tho  |
//|  (rsiArr[k], gia tri iRSI() truc tiep, KHAC voi rsiEma/rsiWma dung   |
//|  cho huong) >= InpRsiOverbought; chan Sell MOI neu RSI tho <=        |
//|  InpRsiOversold. Ap dung TRUOC buyConfirmedNow/sellConfirmedNow,     |
//|  cung nhom voi atrOK/hourOK/waitOK -- KHONG anh huong BufExit va     |
//|  KHONG anh huong viec tinh stateCur/prevState (van doi trang thai    |
//|  binh thuong, chi la khong ve mui ten/khong lastEntryBar khi bi      |
//|  chan boi vung qua mua/qua ban).                                     |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.08"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "EMA nhanh"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1

#property indicator_label2  "EMA cham"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1

#property indicator_label3  "Buy"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  2

#property indicator_label4  "Sell"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

#property indicator_label5  "Exit"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrSilver
#property indicator_width5  2

// === 1. EMA Cross ===
// v1.05: doi tu "input group" (chi de trang tri UI) sang comment thuong.
// LY DO: "input group" tao ra 1 "slot" rieng trong danh sach tham so cua
// chuong trinh bien dich -- khi EA goi iCustom() TRUYEN THAM SO THEO VI TRI
// (positional), moi "slot group" nay chiem mat 1 vi tri, lam TOAN BO 15 gia
// tri thuc EA truyen vao bi LECH DAN sang dung bien ke tiep (vi du gia tri
// dinh danh cho InpSlowEMA=20 lai bi gan nham vao InpFastEMA, v.v.) -- day
// la nguyen nhan GOC cua loi "InpFastEMA phai > 0 va < InpSlowEMA" xuat hien
// tren MOI nen khi chay qua EA (iCustom, positional), trong khi gan indicator
// truc tiep len chart lai chay dung (Inputs dialog gan theo TEN, khong theo
// vi tri, nen khong bi anh huong). Da xac nhan khop 100% voi du lieu that te
// tu Journal [CHAN DOAN v1.04] cua bro (InpFastEMA nhan duoc 20 = gia tri that
// ra danh cho InpSlowEMA, InpSlowEMA nhan duoc 1 = true cua InpUseRSIFilter
// bi ep kieu, v.v. -- khop chinh xac tung so mot).
input int    InpFastEMA   = 9;     // Chu ky EMA nhanh
input int    InpSlowEMA   = 20;    // Chu ky EMA cham

// === 2. Loc RSI (ap dung 2 duong trung binh len RSI) ===
input bool   InpUseRSIFilter = true;  // Bat/tat loc RSI cho Buy/Sell (Exit luon bo qua loc nay)
input int    InpRSIPeriod    = 14;    // Chu ky RSI goc
input int    InpRSIFastMA    = 9;     // Chu ky EMA lam muot RSI (nhanh)
input int    InpRSISlowMA    = 45;    // Chu ky WMA lam muot RSI (cham)

// === 3. Loc ATR (bo qua tin hieu khi qua yen) ===
input int    InpATRPeriod = 14;    // Chu ky ATR
input double InpMinATR    = 0.0;   // ATR toi thieu de cho phep tin hieu Buy/Sell moi (0 = tat loc)

// === 4. Khung gio giao dich (tuy chon, chi anh huong Buy/Sell, KHONG anh huong Exit) ===
input bool   InpOnlyHourWindow = false; // Chi cho tin hieu Buy/Sell moi trong khung gio ben duoi
input int    InpFromHour       = 7;     // Gio bat dau (server time, 0-23)
input int    InpToHour         = 22;    // Gio ket thuc (server time, 0-23)

// === 4b. [MOI v1.08] Loc vung qua mua/qua ban (tuy chon, chi anh huong Buy/Sell, KHONG anh huong Exit) ===
input bool   InpUseRsiZoneFilter = false; // Bat/tat: chan tin hieu MOI khi RSI tho dang qua mua/qua ban
input double InpRsiOverbought    = 70.0;  // Khong xac nhan Buy MOI neu RSI tho hien tai >= muc nay
input double InpRsiOversold      = 30.0;  // Khong xac nhan Sell MOI neu RSI tho hien tai <= muc nay

// === 5. Thoi diem xac nhan tin hieu ===
input bool   InpConfirmClose = true; // true = xet tren nen DA DONG (an toan, khong repaint); false = xet ngay tren nen dang chay
input int    InpBarsWait     = 0;    // So nen toi thieu giua 2 tin hieu Buy/Sell MOI lien tiep (0 = khong gioi han)

// === 6. Ve tren chart ===
input bool   InpDrawEMALines  = true; // Ve 2 duong EMA nhanh/cham len chart
input double InpArrowDistATR  = 0.5;  // Khoang cach mui ten ra khoi nen, tinh theo boi so ATR

//--- buffer arrays
double BufEMAFast[];
double BufEMASlow[];
double BufBuy[];
double BufSell[];
double BufExit[];

//--- indicator handles noi bo (built-in MT5, KHONG phai iCustom toi ben thu 3)
int g_HandleEMAFast = INVALID_HANDLE;
int g_HandleEMASlow = INVALID_HANDLE;
int g_HandleRSI     = INVALID_HANDLE;
int g_HandleATR     = INVALID_HANDLE;

//--- v1.04: dem so lan OnInit() that bai o buoc kiem tra FastEMA/SlowEMA, gioi han so lan in chi tiet
//    (xem changelog v1.04 o dau file).
int g_DbgInitFailPrints = 0;

int OnInit()
{
   SetIndexBuffer(0, BufEMAFast, INDICATOR_DATA);
   SetIndexBuffer(1, BufEMASlow, INDICATOR_DATA);
   SetIndexBuffer(2, BufBuy,     INDICATOR_DATA);
   SetIndexBuffer(3, BufSell,    INDICATOR_DATA);
   SetIndexBuffer(4, BufExit,    INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, InpDrawEMALines ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, InpDrawEMALines ? DRAW_LINE : DRAW_NONE);

   PlotIndexSetInteger(2, PLOT_ARROW, 233); // mui ten len
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // mui ten xuong
   PlotIndexSetInteger(4, PLOT_ARROW, 170); // kim cuong (exit)

   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // v1.04: bro chay EA qua Strategy Tester ca thang 9, Journal cho thay dong Print() ngay ben duoi
   // (InpFastEMA phai > 0...) bi lap lai o MOI NEN suot ca thang -- nghia la OnInit() dang bi goi lai
   // lien tuc va LUON that bai kiem tra FastEMA/SlowEMA, DU EA truyen dung InpC_FastEMA=9/InpC_SlowEMA=20
   // (da xac nhan qua tab Inputs). Day la dieu VO LY neu gia tri THAT SU nhan duoc dung la 9/20 -- nen
   // truoc khi doan tiep, in ra TOAN BO 15 gia tri INPUT THAT SU ma OnInit() nay nhan duoc, moi khi that
   // bai (gioi han vai lan dau de tranh spam qua muc, nhung neu OnInit lap lai vinh vien nhu log cho
   // thay thi co the van se in nhieu lan -- van chap nhan duoc de co bang chung ro rang).
   if (InpFastEMA <= 0 || InpSlowEMA <= 0 || InpFastEMA >= InpSlowEMA)
   {
      g_DbgInitFailPrints++;
      if (g_DbgInitFailPrints <= 5)
      {
         Print("EMACrossClone: [CHAN DOAN v1.04] InpFastEMA phai > 0 va < InpSlowEMA -- THAT BAI. ",
               "Gia tri THAT SU nhan duoc trong lan OnInit() nay: ",
               "InpFastEMA=", InpFastEMA, " InpSlowEMA=", InpSlowEMA, " InpUseRSIFilter=", InpUseRSIFilter,
               " InpRSIPeriod=", InpRSIPeriod, " InpRSIFastMA=", InpRSIFastMA, " InpRSISlowMA=", InpRSISlowMA,
               " InpATRPeriod=", InpATRPeriod, " InpMinATR=", DoubleToString(InpMinATR, 4),
               " InpOnlyHourWindow=", InpOnlyHourWindow, " InpFromHour=", InpFromHour, " InpToHour=", InpToHour,
               " InpConfirmClose=", InpConfirmClose, " InpBarsWait=", InpBarsWait,
               " InpDrawEMALines=", InpDrawEMALines, " InpArrowDistATR=", DoubleToString(InpArrowDistATR, 4));
      }
      Print("EMACrossClone: InpFastEMA phai > 0 va < InpSlowEMA. Kiem tra lai Inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpRSIPeriod <= 0 || InpRSIFastMA <= 0 || InpRSISlowMA <= 0)
   {
      Print("EMACrossClone: chu ky RSI/EMA-RSI/WMA-RSI phai > 0. Kiem tra lai Inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpATRPeriod <= 0)
   {
      Print("EMACrossClone: chu ky ATR phai > 0. Kiem tra lai Inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_HandleEMAFast = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleEMASlow = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleRSI     = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_HandleATR     = iATR(_Symbol, _Period, InpATRPeriod);

   if (g_HandleEMAFast == INVALID_HANDLE || g_HandleEMASlow == INVALID_HANDLE ||
       g_HandleRSI == INVALID_HANDLE || g_HandleATR == INVALID_HANDLE)
   {
      Print("EMACrossClone: khong tao duoc 1 trong cac indicator built-in (EMA/RSI/ATR). Ma loi: ", GetLastError());
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "EMACrossClone(" + IntegerToString(InpFastEMA) + "/" + IntegerToString(InpSlowEMA) + ")");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_HandleEMAFast != INVALID_HANDLE) IndicatorRelease(g_HandleEMAFast);
   if (g_HandleEMASlow != INVALID_HANDLE) IndicatorRelease(g_HandleEMASlow);
   if (g_HandleRSI     != INVALID_HANDLE) IndicatorRelease(g_HandleRSI);
   if (g_HandleATR     != INVALID_HANDLE) IndicatorRelease(g_HandleATR);
}

//--- kiem tra gio hien tai co nam trong khung [InpFromHour, InpToHour] khong (ho tro qua nua dem)
bool IsInHourWindow(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int h = dt.hour;
   if (InpFromHour <= InpToHour)
      return (h >= InpFromHour && h < InpToHour);
   else // khung gio qua dem, vd 22 -> 5
      return (h >= InpFromHour || h < InpToHour);
}

//--- v1.03: kiem tra 1 gia tri RSI THO co "dung nghia" hay khong truoc khi dua vao bat ky phep tinh nao.
//    RSI luon nam trong [0,100] theo dinh nghia -- bat ky gia tri nao ngoai khoang nay (ke ca EMPTY_VALUE=
//    2147483647 khi nen chua du du lieu de tinh, hoac te hon la NaN/Infinity neu built-in indicator gap
//    su co runtime) DEU bi coi la "chua dung", KHONG duoc dua vao cong thuc -- dac biet quan trong voi
//    cong thuc DE QUY (rsiEma ben duoi), vi 1 gia tri hong lot vao se "lay lan" vinh vien cho moi nen sau.
bool IsRsiUsable(double v)
{
   if (!MathIsValidNumber(v)) return false; // chan NaN/Infinity
   return (v >= -0.0001 && v <= 100.0001);  // RSI hop le luon trong [0,100] (co du sai so lam tron nho)
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int minBarsNeeded = MathMax(InpSlowEMA, MathMax(InpRSIPeriod, MathMax(InpRSIFastMA, InpRSISlowMA))) + InpATRPeriod + 10;
   if (rates_total < minBarsNeeded) return 0;

   //--- GHI CHU VE CHIEU INDEX (quan trong, de tranh 1 loi kinh dien khi viet indicator MQL5):
   //    time[]/open[]/high[]/low[]/close[] (tham so cua OnCalculate) VA cac buffer cua CHINH indicator nay
   //    (BufEMAFast, BufBuy, ...) mac dinh la KHONG PHAI series -- index 0 = nen CU NHAT, index rates_total-1
   //    = nen hien tai/moi nhat (dung nhu vi du "Custom Moving Average" chuan cua MetaEditor). De moi thu
   //    THANG HANG voi nhau (khong phai dao chieu roi doi lai, de sinh loi), ta CO Y KHONG goi ArraySetAsSeries()
   //    cho emaFastArr/emaSlowArr/rsiArr/atrArr ben duoi -- de chung cung mac dinh KHONG series, cung chieu voi
   //    time[]/BufBuy[] o tren. Nghia la: voi cung 1 chi so k, emaFastArr[k] va time[offset+k]/BufBuy[offset+k]
   //    (offset giai thich ben duoi) LUON tuong ung DUNG 1 nen -- khong can dao nguoc mang o dau ca.
   double emaFastArr[], emaSlowArr[], rsiArr[], atrArr[];

   int need = rates_total; // tinh lai toan bo moi lan cho don gian/an toan (indicator, khong phai EA, chi phi chap nhan duoc)
   if (CopyBuffer(g_HandleEMAFast, 0, 0, need, emaFastArr) <= 0) return 0;
   if (CopyBuffer(g_HandleEMASlow, 0, 0, need, emaSlowArr) <= 0) return 0;
   if (CopyBuffer(g_HandleRSI, 0, 0, need, rsiArr) <= 0) return 0;
   if (CopyBuffer(g_HandleATR, 0, 0, need, atrArr) <= 0) return 0;

   int barsAvail = ArraySize(emaFastArr);
   barsAvail = MathMin(barsAvail, ArraySize(emaSlowArr));
   barsAvail = MathMin(barsAvail, ArraySize(rsiArr));
   barsAvail = MathMin(barsAvail, ArraySize(atrArr));
   if (barsAvail < 2) return rates_total;

   //--- Neu cac indicator built-in (EMA/RSI/ATR) can "khoi dong" nen chua the tra ve du rates_total gia tri
   //    (thuong chi xay ra o rat xa qua khu), CopyBuffer() se tra ve IT HON rates_total phan tu, va phan
   //    THIEU luon la o PHIA CU (vi cac ham nay tinh tu qua khu toi hien tai) -- nen "offset" = so nen bi
   //    thieu o dau, va emaFastArr[k] (k=0..barsAvail-1) tuong ung voi time[offset+k]/BufBuy[offset+k].
   int offset = rates_total - barsAvail;

   //--- EMA-cua-RSI (chu ky InpRSIFastMA) va WMA-cua-RSI (chu ky InpRSISlowMA), tinh thu cong TREN CHINH
   //    day RSI goc (rsiArr), cung chieu index (0=cu nhat trong cua so vua lay). Xem ghi chu dau file.
   //
   //--- v1.03 -- FIX QUAN TRONG: rsiEma la cong thuc DE QUY (rsiEma[k] phu thuoc rsiEma[k-1]), nen PHAI
   //    kiem tra rsiArr[k] "dung nghia RSI" (IsRsiUsable, xem ham o tren) TRUOC khi dua vao, neu khong 1
   //    gia tri hong (NaN/Infinity, vi du luc built-in indicator con dang khoi dong o rat xa qua khu) se
   //    "lay lan" VINH VIEN cho toan bo cac nen phia sau -- day CHINH XAC la nguyen nhan bug "Sell khong
   //    bao gio xac nhan" da tim ra tu log CHAN DOAN v1.02 that cua bro (rEma=inf o moi nen). Cach xu ly:
   //    dung 1 bo dem "validRun" (so nen RSI hop le LIEN TIEP tinh den k) -- chi "seed" (khoi tao) rsiEma
   //    khi co du InpRSIFastMA nen hop le lien tiep, va neu gap 1 nen KHONG hop le thi RESET validRun ve 0
   //    (bat buoc phai "seed" lai tu dau khi du lieu tot tro lai) thay vi de gia tri hong ngam vao cong
   //    thuc de quy. dbgRsiInvalid dem lai so lan phat hien de xac nhan chan doan nay dung tren may that.
   double rsiEma[]; ArrayResize(rsiEma, barsAvail);
   double alpha = 2.0 / (InpRSIFastMA + 1.0);
   int validRun = 0;
   int dbgRsiInvalid = 0;
   for (int k = 0; k < barsAvail; k++)
   {
      if (!IsRsiUsable(rsiArr[k]))
      {
         rsiEma[k] = EMPTY_VALUE;
         validRun = 0; // du lieu RSI tai day khong dung nghia -- phai "seed" lai tu dau sau nay
         dbgRsiInvalid++;
         continue;
      }
      validRun++;
      if (validRun < InpRSIFastMA) { rsiEma[k] = EMPTY_VALUE; continue; }
      if (validRun == InpRSIFastMA)
      {
         double sum = 0.0;
         for (int j = 0; j < InpRSIFastMA; j++) sum += rsiArr[k - j]; // an toan: validRun>=InpRSIFastMA dam bao ca InpRSIFastMA nen nay deu hop le
         rsiEma[k] = sum / InpRSIFastMA; // seed = SMA cua InpRSIFastMA gia tri RSI hop le dau tien
      }
      else
      {
         // an toan: validRun > InpRSIFastMA dam bao nen k-1 cung nam trong CUNG 1 chuoi hop le lien tiep
         // (khong bi reset giua chung), nen rsiEma[k-1] chac chan la 1 gia tri "sach", khong phai EMPTY_VALUE.
         rsiEma[k] = rsiArr[k] * alpha + rsiEma[k - 1] * (1.0 - alpha);
      }
   }

   //--- WMA khong de quy (moi nen tinh lai tu dau) nen it rui ro hon, nhung van kiem tra IsRsiUsable cho
   //    CHAC (v1.03) -- neu 1 trong so InpRSISlowMA nen trong cua so bi hong, coi ca nen k do la EMPTY_VALUE
   //    thay vi am tham dung gia tri hong vao trung binh (truoc day khong kiem tra diem nay).
   double rsiWma[]; ArrayResize(rsiWma, barsAvail);
   for (int k = 0; k < barsAvail; k++)
   {
      if (k < InpRSISlowMA - 1) { rsiWma[k] = EMPTY_VALUE; continue; }
      double sum = 0.0, wsum = 0.0;
      bool windowOK = true;
      for (int j = 0; j < InpRSISlowMA; j++)
      {
         double v = rsiArr[k - j];
         if (!IsRsiUsable(v)) { windowOK = false; break; }
         double w = (double)(InpRSISlowMA - j);
         sum += v * w;
         wsum += w;
      }
      rsiWma[k] = windowOK ? (sum / wsum) : EMPTY_VALUE;
   }

   //--- Tinh lai TOAN BO buffer moi lan OnCalculate() duoc goi (khong dung prev_calculated de tinh incremental).
   //    Day la lua chon CO CHU DICH: indicator nay khong co dashboard/nang, chi phi CPU cho viec tinh lai het
   //    la chap nhan duoc, doi lai loai bo hoan toan rui ro loi incremental-recalculation (vi du lastEntryBar
   //    bi sai neu MT5 tinh lai tu giua lich su thay vi tu dau) -- an toan hon khi khong co trinh bien dich
   //    that de kiem thu truc tiep trong moi truong nay.
   int lastEntryBar = -1000000; // chi so k cua tin hieu Buy/Sell MOI gan nhat, de ap InpBarsWait

   //--- v1.07: trang thai tong hop (1=Buy,-1=Sell,0=Flat) cua nen VUA XU LY GAN NHAT, de so sanh
   //    "doi trang thai" dung chuan MIK (stCur != stPrev), thay vi doi hoi phai co cross EMA tai chinh nen.
   int prevState = 0;

   //--- CHAN DOAN v1.01: dem so lan cross/xac nhan de kiem tra Buy/Sell co can bang khong tren du lieu THAT.
   //    Mo phong bang Python tren du lieu tong hop cho ket qua can bang tuyet doi (12 Buy / 12 Sell), nen neu
   //    tren chart that lai lech han ve 1 phia, day la dau hieu can so lieu THAT tu chinh terminal de tim
   //    nguyen nhan -- xem dong Print() tong ket o cuoi ham nay (chi in 1 lan khi tinh lai toan bo lich su).
   int dbgCrossUp = 0, dbgCrossDown = 0, dbgBuyOK = 0, dbgSellOK = 0, dbgRsiEmptyUp = 0, dbgRsiEmptyDown = 0;

   //--- [MOI v1.08] dem so lan tin hieu doi trang thai BI CHAN rieng boi filter vung qua mua/qua ban,
   //    de bro xac nhan filter co dang hoat dong that khong (neu InpUseRsiZoneFilter=true ma 2 so nay
   //    luon = 0 tren du lieu that, nghia la chua bao gio gap truong hop can loc, hoac nguong dat chua hop ly).
   int dbgBlockedZoneUp = 0, dbgBlockedZoneDown = 0;

   //--- CHAN DOAN v1.02: luu lai SO THAT (khong chi true/false) cua N lan crossDown/crossUp GAN NHAT,
   //    de in ra cuoi ham -- xem chinh xac rEma vs rWma chenh nhau bao nhieu diem tai tung thoi diem that.
   const int DBG_KEEP = 10;
   datetime dbgDnTime[10];  double dbgDnRsi[10], dbgDnEma[10], dbgDnWma[10]; bool dbgDnConfirmed[10];
   datetime dbgUpTime[10];  double dbgUpRsi[10], dbgUpEma[10], dbgUpWma[10]; bool dbgUpConfirmed[10];
   int dbgDnFill = 0, dbgUpFill = 0; // so lan da ghi (co the vuot DBG_KEEP, dung modulo de giu 10 lan GAN NHAT)

   for (int k = 1; k < barsAvail; k++)
   {
      int sIdx = offset + k;
      if (sIdx < 0 || sIdx >= rates_total) continue;

      BufEMAFast[sIdx] = emaFastArr[k];
      BufEMASlow[sIdx] = emaSlowArr[k];
      BufBuy[sIdx]  = EMPTY_VALUE;
      BufSell[sIdx] = EMPTY_VALUE;
      BufExit[sIdx] = EMPTY_VALUE;

      //--- InpConfirmClose: neu bat, KHONG xet tin hieu tren nen dang chay (k = bar cuoi cung, chua dong) --
      //    de no "cho" toi lan OnCalculate() ke tiep, khi nen do da dong hoan toan va tro thanh nen k-1, k-2...
      //    Day la cach chuan, KHONG repaint, khac voi kieu "lui shift" (de gay nham lan hon).
      bool isFormingBar = (k == barsAvail - 1);
      if (InpConfirmClose && isFormingBar) continue;

      double fastNow  = emaFastArr[k];
      double slowNow  = emaSlowArr[k];
      double fastPrev = emaFastArr[k - 1];
      double slowPrev = emaSlowArr[k - 1];

      //--- v1.03: phong ngua them -- neu built-in EMA gia (hiem, nhung cung tung thay RSI gap kieu nay) tra
      //    ve NaN/Infinity o 1 vai nen (vd luc con dang khoi dong lich su), BO QUA hoan toan nen do thay vi
      //    de gia tri hong lam sai lech cross detection (khong de quy nen khong "lay lan", chi anh huong
      //    dung 1 nen nay).
      if (!MathIsValidNumber(fastNow) || !MathIsValidNumber(slowNow) ||
          !MathIsValidNumber(fastPrev) || !MathIsValidNumber(slowPrev)) continue;

      bool crossUp   = (fastPrev <= slowPrev) && (fastNow > slowNow);
      bool crossDown = (fastPrev >= slowPrev) && (fastNow < slowNow);

      //--- v1.07: BO dieu kien bat buoc "phai co cross EMA tai chinh nen" o day (khac v1.00-v1.06).
      //    MIK goc phat Buy/Sell khi TRANG THAI TONG HOP doi so voi nen truoc, khong doi hoi cross gia
      //    tuoi -- xem changelog v1.07 o dau file. crossUp/crossDown van duoc tinh o tren, chi dung rieng
      //    cho BufExit (canh bao som, giu nguyen hanh vi cu) o phia duoi.

      //--- loc RSI (chi anh huong Buy/Sell, KHONG anh huong Exit). InpUseRSIFilter=false: giu nguyen thiet
      //    ke cu cua file nay -- RSI la filter TUY CHON, trang thai chi phu thuoc huong EMA gia. true: ket
      //    hop CA 2 ve dung y het MIK (huong gia AND huong RSI).
      bool priceBull = fastNow > slowNow;
      bool priceBear = fastNow < slowNow;

      bool rsiUsable = true;
      bool rsiBull = true, rsiBear = true;
      bool rsiEmptyHere = false;
      if (InpUseRSIFilter)
      {
         double rEma = rsiEma[k];
         double rWma = rsiWma[k];
         // v1.03: dung IsRsiUsable() thay vi so sanh == EMPTY_VALUE -- chan ca truong hop hiem gap (neu con
         // sot) la NaN/Infinity chu khong chi dung EMPTY_VALUE, tranh lap lai chinh xac bug da tim ra.
         if (!IsRsiUsable(rEma) || !IsRsiUsable(rWma)) { rsiUsable = false; rsiBull = false; rsiBear = false; rsiEmptyHere = true; }
         else { rsiBull = (rEma > rWma); rsiBear = (rEma < rWma); }
      }
      if (InpUseRSIFilter && rsiEmptyHere)
      {
         if (priceBull) dbgRsiEmptyUp++; else if (priceBear) dbgRsiEmptyDown++;
      }

      //--- v1.07: trang thai tong hop cua NEN NAY, dung y het BarState() cua MIK_EmaCross_Signal.mq5.
      int stateCur;
      if (!InpUseRSIFilter)          stateCur = priceBull ? 1 : (priceBear ? -1 : 0);
      else if (!rsiUsable)           stateCur = 0;   // RSI chua san sang -> coi nhu Flat, giong MIK khong the xac dinh
      else if (priceBull && rsiBull) stateCur = 1;
      else if (priceBear && rsiBear) stateCur = -1;
      else                             stateCur = 0;

      //--- loc ATR (chi anh huong Buy/Sell, KHONG anh huong Exit)
      double atrNow = atrArr[k];
      bool atrOK = (InpMinATR <= 0.0) || (MathIsValidNumber(atrNow) && atrNow >= InpMinATR);

      //--- loc khung gio (chi anh huong Buy/Sell, KHONG anh huong Exit)
      bool hourOK = (!InpOnlyHourWindow) || IsInHourWindow(time[sIdx]);

      //--- loc barsWait (chi anh huong Buy/Sell, KHONG anh huong Exit)
      bool waitOK = (InpBarsWait <= 0) || (k - lastEntryBar >= InpBarsWait);

      //--- [MOI v1.08] loc vung qua mua/qua ban theo RSI THO (chi anh huong Buy/Sell, KHONG anh huong Exit).
      //    Ly do them: filter RSI hien co (rsiBull/rsiBear) chi xet HUONG (RSI-EMA vs RSI-WMA cat nhau),
      //    KHONG xet RSI dang o MUC nao -- nen van co the xac nhan Buy dung luc RSI da qua mua sau (vd >80),
      //    tuc la dang "duoi theo" 1 song da can, diem vao xau/de bi hoi lai ngay. Mac dinh TAT (giu dung
      //    hanh vi v1.07/MIK goc) -- bat len de loc bot cac tin hieu kieu nay.
      bool zoneOK = true;
      if (InpUseRsiZoneFilter && MathIsValidNumber(rsiArr[k]))
      {
         if (stateCur == 1  && rsiArr[k] >= InpRsiOverbought) { zoneOK = false; if (stateCur != prevState) dbgBlockedZoneUp++; }
         if (stateCur == -1 && rsiArr[k] <= InpRsiOversold)   { zoneOK = false; if (stateCur != prevState) dbgBlockedZoneDown++; }
      }

      double atrDist     = (MathIsValidNumber(atrNow) && atrNow > 0 && atrNow != EMPTY_VALUE) ? atrNow * InpArrowDistATR : 0.0;
      double atrDistExit = atrDist * 1.6; // Exit ve XA nen hon Buy/Sell, tranh chong len nhau khi ca 2 cung ban tren 1 nen

      //--- BufExit: GIU NGUYEN thiet ke cu (KHONG doi o v1.07) -- canh bao som thuan tuy tu cross EMA gia,
      //    khong can RSI/ATR/gio, khong lien quan toi stateCur/prevState o duoi.
      if (crossUp)   { dbgCrossUp++;   BufExit[sIdx] = low[sIdx]  - atrDistExit; }
      if (crossDown) { dbgCrossDown++; BufExit[sIdx] = high[sIdx] + atrDistExit; }

      //--- v1.07: Buy/Sell gio phat khi TRANG THAI TONG HOP doi so voi nen truoc (dung chuan MIK), roi moi
      //    ap tiep cac filter ATR/gio/barsWait (tuy chon rieng cua file nay, MIK goc khong co).
      if (stateCur != prevState)
      {
         if (stateCur == 1)
         {
            bool buyConfirmedNow = (atrOK && hourOK && waitOK && zoneOK);
            if (buyConfirmedNow)
            {
               BufBuy[sIdx] = low[sIdx] - atrDist;
               lastEntryBar = k;
               dbgBuyOK++;
            }
            if (!rsiEmptyHere)
            {
               int wIdx = dbgUpFill % DBG_KEEP;
               dbgUpTime[wIdx] = time[sIdx]; dbgUpRsi[wIdx] = rsiArr[k];
               dbgUpEma[wIdx] = rsiEma[k];   dbgUpWma[wIdx] = rsiWma[k];
               dbgUpConfirmed[wIdx] = buyConfirmedNow;
               dbgUpFill++;
            }
         }
         else if (stateCur == -1)
         {
            bool sellConfirmedNow = (atrOK && hourOK && waitOK && zoneOK);
            if (sellConfirmedNow)
            {
               BufSell[sIdx] = high[sIdx] + atrDist;
               lastEntryBar = k;
               dbgSellOK++;
            }
            if (!rsiEmptyHere)
            {
               int wIdx = dbgDnFill % DBG_KEEP;
               dbgDnTime[wIdx] = time[sIdx]; dbgDnRsi[wIdx] = rsiArr[k];
               dbgDnEma[wIdx] = rsiEma[k];   dbgDnWma[wIdx] = rsiWma[k];
               dbgDnConfirmed[wIdx] = sellConfirmedNow;
               dbgDnFill++;
            }
         }
      }

      prevState = stateCur;
   }

   if (prev_calculated == 0)
   {
      Print("EMACrossClone: [CHAN DOAN v1.08] Tong ket tinh lai toan bo lich su da tai (", barsAvail, " nen) -- ",
            "Buy xac nhan (doi trang thai)=", dbgBuyOK, " | Sell xac nhan (doi trang thai)=", dbgSellOK, " | ",
            "(tham khao) cross EMA gia tho: crossUp=", dbgCrossUp, " crossDown=", dbgCrossDown,
            " -- KHONG con la dieu kien bat buoc cho Buy/Sell tu v1.07, chi con dung cho BufExit | ",
            "RSI dang EMPTY luc gia dang bull/bear (bi bo qua state)=", dbgRsiEmptyUp, "(up)/", dbgRsiEmptyDown, "(down) | ",
            "Bi CHAN boi filter vung qua mua/qua ban (InpUseRsiZoneFilter, MOI v1.08)=", dbgBlockedZoneUp, "(Buy)/", dbgBlockedZoneDown, "(Sell)",
            (InpUseRsiZoneFilter ? "" : "  (dang TAT, 2 so nay luon = 0)"), " | ",
            "So nen RSI tho KHONG hop le da bi CHAN (fix v1.03, dbgRsiInvalid)=", dbgRsiInvalid,
            (dbgRsiInvalid > 0 ? "  <-- XAC NHAN: day chinh la nen (cac nen) gay ra bug inf o v1.02, gio da duoc chan lai" : "  (0 la binh thuong neu chua gap lai truong hop nay)"));

      //--- In chi tiet SO THAT cua toi da 10 lan crossDown GAN NHAT (theo dung thu tu thoi gian) --
      //    day la phan QUAN TRONG NHAT de xac nhan fix da hoat dong: rEma/rWma gio phai la so huu han binh
      //    thuong (khong con "inf" nhu log v1.02), va ty le Sell XAC NHAN phai tro ve muc hop ly (khong con 0%).
      int dnCount = MathMin(dbgDnFill, DBG_KEEP);
      Print("EMACrossClone: [CHAN DOAN v1.03] Chi tiet ", dnCount, " lan crossDown GAN NHAT (rEma=EMA9-cua-RSI, rWma=WMA45-cua-RSI, can rEma<rWma moi xac nhan Sell):");
      for (int n = 0; n < dnCount; n++)
      {
         int idx = (dbgDnFill <= DBG_KEEP) ? n : (dbgDnFill + n) % DBG_KEEP; // thu tu cu->moi trong so DBG_KEEP gan nhat
         Print("   crossDown #", n + 1, " luc ", TimeToString(dbgDnTime[idx], TIME_DATE | TIME_MINUTES),
               " -- RSI_tho=", DoubleToString(dbgDnRsi[idx], 2),
               " rEma=", DoubleToString(dbgDnEma[idx], 4),
               " rWma=", DoubleToString(dbgDnWma[idx], 4),
               " (rEma-rWma=", DoubleToString(dbgDnEma[idx] - dbgDnWma[idx], 4), ")",
               " => ", (dbgDnConfirmed[idx] ? "Sell XAC NHAN" : "Sell BI CHAN boi RSI"));
      }

      int upCount = MathMin(dbgUpFill, DBG_KEEP);
      Print("EMACrossClone: [CHAN DOAN v1.03] Chi tiet ", upCount, " lan crossUp GAN NHAT (doi chieu):");
      for (int n = 0; n < upCount; n++)
      {
         int idx = (dbgUpFill <= DBG_KEEP) ? n : (dbgUpFill + n) % DBG_KEEP;
         Print("   crossUp #", n + 1, " luc ", TimeToString(dbgUpTime[idx], TIME_DATE | TIME_MINUTES),
               " -- RSI_tho=", DoubleToString(dbgUpRsi[idx], 2),
               " rEma=", DoubleToString(dbgUpEma[idx], 4),
               " rWma=", DoubleToString(dbgUpWma[idx], 4),
               " (rEma-rWma=", DoubleToString(dbgUpEma[idx] - dbgUpWma[idx], 4), ")",
               " => ", (dbgUpConfirmed[idx] ? "Buy XAC NHAN" : "Buy BI CHAN boi RSI"));
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
