//+------------------------------------------------------------------+
//|                                        FractalCISD_Research.mq5  |
//|  EA NGHIÊN CỨU (research build) - KHÔNG phải EA chạy tiền thật.  |
//|                                                                  |
//|  Chiến lược: "HTF Candle-2 Sweep -> LTF CISD"                    |
//|   1. HTF (mặc định H1): nến C2 quét thanh khoản (fractal swing   |
//|      chưa bị lấy, hoặc đáy/đỉnh nến C1) rồi ĐÓNG lại phía trong. |
//|   2. LTF (mặc định M5), chỉ trong nến HTF kế tiếp (C3): chờ nhịp |
//|      hồi rồi CISD = nến đóng cửa vượt giá mở của chuỗi nến       |
//|      ngược chiều đã đưa giá vào cực trị của nhịp hồi.            |
//|   3. Vào lệnh thị trường khi nến CISD đóng; SL sau cực trị nhịp  |
//|      hồi (protected swing) + đệm ATR; TP = RR cố định hoặc cực   |
//|      trị đối diện của C2; đóng theo thời gian nếu quá N nến HTF. |
//|                                                                  |
//|  Logic khớp 1-1 với research/fractal_cisd/fractal_cisd_bt.py.    |
//|  Đặc tả & nguồn: docs/fractal_cisd/DAC_TA_CHIEN_LUOC.md          |
//+------------------------------------------------------------------+
#property copyright "Research build"
#property version   "0.10"
#property description "EA nghiên cứu: HTF Candle-2 quét thanh khoản -> CISD khung nhỏ. Chưa được kiểm chứng."

#include <Trade\Trade.mqh>

//--- Enum (chú thích hiển thị trong hộp thoại Input của MT5)
enum ENUM_LIQ_MODE
{
   LIQ_C1      = 0,   // Đáy/đỉnh nến C1 (Candle-2 closure thuần)
   LIQ_FRACTAL = 1,   // Fractal swing HTF chưa bị quét
   LIQ_NONE    = 2    // ĐỐI CHỨNG: bỏ điều kiện quét HTF
};
enum ENUM_TP_MODE
{
   TP_C2_EXTREME = 0, // Cực trị đối diện của nến C2 (thanh khoản)
   TP_FIXED_RR   = 1  // RR cố định
};

//====================================================================
// Input
//====================================================================
input group "=== Nhận dạng ==="
input ulong           InpMagic          = 26092801;     // Magic number (riêng cho EA này)
input string          InpCommentTag     = "FCISD";      // Tiền tố comment lệnh

input group "=== Khung thời gian ==="
input ENUM_TIMEFRAMES InpHTF            = PERIOD_H1;    // Khung bối cảnh (nến C1/C2/C3)
input ENUM_TIMEFRAMES InpLTF            = PERIOD_M5;    // Khung vào lệnh (CISD)

input group "=== Bối cảnh HTF: quét thanh khoản ==="
input ENUM_LIQ_MODE   InpLiqMode        = LIQ_FRACTAL;  // Loại thanh khoản bị quét
input int             InpPivot          = 2;            // Số nến mỗi bên của fractal HTF
input int             InpSwingLookback  = 48;           // Số nến HTF tối đa tìm swing
input int             InpValidHTF       = 1;            // Số nến HTF sau C2 được phép tìm CISD
input int             InpExitHTF        = 2;            // Đóng lệnh sau N nến HTF tính từ C2 đóng

input group "=== Xác nhận LTF ==="
input bool            InpRequireFVG     = false;        // Bắt buộc chân CISD có FVG cùng chiều
input int             InpATRPeriod      = 14;           // Chu kỳ ATR khung LTF

input group "=== SL / TP ==="
input ENUM_TP_MODE    InpTPMode         = TP_FIXED_RR;  // Cách đặt TP
input double          InpFixedRR        = 2.0;          // RR cố định (khi TP = RR cố định)
input double          InpMinRR          = 1.5;          // RR tối thiểu (khi TP = cực trị C2)
input double          InpSLBufATR       = 0.10;         // Đệm SL (x ATR LTF)
input double          InpMinSLATR       = 0.5;          // Khoảng SL tối thiểu (x ATR LTF)
input double          InpMaxSLATR       = 4.0;          // Khoảng SL tối đa (x ATR LTF)

input group "=== Quản trị rủi ro ==="
input double          InpRiskPercent    = 0.5;          // Rủi ro mỗi lệnh (% số dư)
input double          InpFixedLot       = 0.0;          // Lot cố định (>0 thì bỏ qua % rủi ro)
input int             InpMaxTradesDay   = 3;            // Số lệnh tối đa mỗi ngày (theo magic)
input double          InpMaxDailyLossPct= 2.0;          // Lỗ tối đa trong ngày (% số dư đầu ngày, 0 = tắt)
input int             InpMaxConsecLoss  = 3;            // Số lệnh thua liên tiếp trong ngày thì dừng (0 = tắt)
input bool            InpAllowBuy       = true;         // Cho phép BUY
input bool            InpAllowSell      = true;         // Cho phép SELL

input group "=== Phiên giao dịch (giờ UTC) ==="
input bool            InpUseSession     = true;         // Chỉ vào lệnh trong phiên
input int             InpGMTOffset      = 0;            // Giờ server trừ giờ UTC (ví dụ GMT+3 nhập 3)
input double          InpS1Start        = 7.0;          // Phiên 1 bắt đầu (giờ UTC, London)
input double          InpS1End          = 10.0;         // Phiên 1 kết thúc (giờ UTC)
input double          InpS2Start        = 12.0;         // Phiên 2 bắt đầu (giờ UTC, New York)
input double          InpS2End          = 16.0;         // Phiên 2 kết thúc (giờ UTC)

input group "=== Chi phí / khớp lệnh ==="
input int             InpMaxSpreadPts   = 60;           // Spread tối đa (point, 0 = tắt)
input double          InpMaxSpreadSL    = 0.20;         // Spread tối đa so với khoảng SL (tỷ lệ)
input int             InpDeviationPts   = 30;           // Độ trượt giá cho phép khi khớp (point)

input group "=== SMT (tuỳ chọn, mặc định tắt) ==="
input bool            InpUseSMT         = false;        // Yêu cầu SMT với mã tương quan tại nến C2
input string          InpSMTSymbol      = "XAGUSD";     // Mã tương quan (tên đúng theo sàn)

input group "=== Nhật ký ==="
input bool            InpVerbose        = true;         // Ghi log chi tiết từng nến
input bool            InpCsvLog         = true;         // Ghi thêm file CSV (thư mục Common\Files)

//====================================================================
// Trạng thái
//====================================================================
struct Setup
{
   bool     active;
   int      side;        // +1 mua, -1 bán
   datetime c2Start;
   datetime c2End;      // = đầu cửa sổ C3
   datetime winEnd;
   datetime exitTime;
   double   c2High;
   double   c2Low;
   double   level;       // mức thanh khoản bị quét
   bool     consumed;    // đã vào lệnh -> không dùng lại
};

CTrade   g_trade;
Setup    g_setups[4];
int      g_nSetups   = 0;
datetime g_lastHTF   = 0;
datetime g_lastLTF   = 0;
int      g_fileHandle= INVALID_HANDLE;
int      g_htfSec    = 0;
int      g_ltfSec    = 0;

// bộ đếm lý do (in tổng kết khi dừng EA)
string   g_reasonKeys[];
int      g_reasonCnt[];

//====================================================================
// Tiện ích log
//====================================================================
void CountReason(const string key)
{
   int n = ArraySize(g_reasonKeys);
   for(int i=0;i<n;i++)
      if(g_reasonKeys[i]==key){ g_reasonCnt[i]++; return; }
   ArrayResize(g_reasonKeys,n+1);
   ArrayResize(g_reasonCnt,n+1);
   g_reasonKeys[n]=key;
   g_reasonCnt[n]=1;
}

void Log(const string tag,const string msg,const bool important=false)
{
   if(!InpVerbose && !important) return;
   string line = StringFormat("[%s] %s | %s | %s", InpCommentTag, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS), tag, msg);
   Print(line);
   if(InpCsvLog && g_fileHandle!=INVALID_HANDLE)
   {
      FileWrite(g_fileHandle, TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS), tag, msg);
      FileFlush(g_fileHandle);
   }
}

string SideStr(const int side){ return side>0 ? "BUY" : "SELL"; }

//====================================================================
// Thời gian / phiên
//====================================================================
bool InSession(const datetime serverTime)
{
   if(!InpUseSession) return true;
   MqlDateTime dt; TimeToStruct(serverTime,dt);
   double h = (double)(((dt.hour - InpGMTOffset) % 24 + 24) % 24) + dt.min/60.0;
   if(h>=InpS1Start && h<InpS1End) return true;
   if(h>=InpS2Start && h<InpS2End) return true;
   return false;
}

datetime DayStart(const datetime t)
{
   MqlDateTime dt; TimeToStruct(t,dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   return StructToTime(dt);
}

//====================================================================
// Thống kê lệnh theo magic (khôi phục được sau khi khởi động lại)
//====================================================================
bool HasOpenPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
         return true;
   }
   return false;
}

// Đếm lệnh vào trong ngày, lãi/lỗ đã đóng trong ngày, chuỗi thua liên tiếp trong ngày
void TodayStats(int &entries,double &closedPL,int &consecLoss)
{
   entries=0; closedPL=0; consecLoss=0;
   datetime from=DayStart(TimeCurrent());
   if(!HistorySelect(from,TimeCurrent()+60)) return;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i);
      if(d==0) continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_IN) entries++;
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_INOUT || entry==DEAL_ENTRY_OUT_BY)
      {
         double pl=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP);
         closedPL+=pl;
         if(pl<0) consecLoss++; else consecLoss=0;
      }
   }
}

// Đã có lệnh vào sau thời điểm t (dùng để đánh dấu setup đã dùng khi khởi động lại)
bool EnteredSince(const datetime t)
{
   if(!HistorySelect(t,TimeCurrent()+60)) return false;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i);
      if(d==0) continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN) return true;
   }
   return false;
}

//====================================================================
// Dữ liệu nến (mảng theo thứ tự thời gian tăng dần, chỉ nến ĐÃ ĐÓNG)
//====================================================================
// Lấy nến LTF có thời điểm mở trong [from, to) - to là thời điểm mở của nến đang chạy
int CopyLTF(const datetime from,MqlRates &r[])
{
   ArraySetAsSeries(r,false);
   datetime lastClosedOpen = iTime(_Symbol,InpLTF,1);
   if(lastClosedOpen==0 || lastClosedOpen<from) return 0;
   int n=CopyRates(_Symbol,InpLTF,from,lastClosedOpen,r);
   return n;
}

double ATRAt(const MqlRates &r[],const int j,const int period)
{
   if(j<period) return 0;
   double s=0;
   for(int i=j-period+1;i<=j;i++)
   {
      double pc=r[i-1].close;
      double tr=MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-pc),MathAbs(r[i].low-pc)));
      s+=tr;
   }
   return s/period;
}

//====================================================================
// Bước 1: đánh giá nến HTF đã đóng (shift) như nến C2
//====================================================================
bool IsFractalLow(const MqlRates &h[],const int q,const int piv)
{
   for(int i=1;i<=piv;i++)
      if(!(h[q].low<h[q-i].low && h[q].low<h[q+i].low)) return false;
   return true;
}
bool IsFractalHigh(const MqlRates &h[],const int q,const int piv)
{
   for(int i=1;i<=piv;i++)
      if(!(h[q].high>h[q-i].high && h[q].high>h[q+i].high)) return false;
   return true;
}

// Trả về mức thanh khoản bị quét (0 nếu không có). k = chỉ số C2 trong mảng h
double SweptLevel(const MqlRates &h[],const int k,const int side,string &why)
{
   if(InpLiqMode==LIQ_NONE)
   {
      why="đối chứng: không yêu cầu quét";
      return side>0 ? h[k].low : h[k].high;
   }
   if(InpLiqMode==LIQ_C1)
   {
      double lv = side>0 ? h[k-1].low : h[k-1].high;
      if(side>0 && h[k].low<lv && h[k].close>lv){ why="C2 quét đáy C1 và đóng lại trên"; return lv; }
      if(side<0 && h[k].high>lv && h[k].close<lv){ why="C2 quét đỉnh C1 và đóng lại dưới"; return lv; }
      why = (side>0 ? (h[k].low<lv ? "quét đáy C1 nhưng đóng dưới" : "không quét đáy C1")
                    : (h[k].high>lv ? "quét đỉnh C1 nhưng đóng trên" : "không quét đỉnh C1"));
      return 0;
   }
   // LIQ_FRACTAL
   double best=0; bool found=false;
   int qMin = MathMax(InpPivot, k-InpSwingLookback);
   for(int q=k-1-InpPivot; q>=qMin; q--)
   {
      if(side>0)
      {
         if(!IsFractalLow(h,q,InpPivot)) continue;
         double v=h[q].low, mn=DBL_MAX;
         for(int x=q+1;x<k;x++) mn=MathMin(mn,h[x].low);
         if(mn>v && h[k].low<v && h[k].close>v)
            if(!found || v<best){ best=v; found=true; }
      }
      else
      {
         if(!IsFractalHigh(h,q,InpPivot)) continue;
         double v=h[q].high, mx=-DBL_MAX;
         for(int x=q+1;x<k;x++) mx=MathMax(mx,h[x].high);
         if(mx<v && h[k].high>v && h[k].close<v)
            if(!found || v>best){ best=v; found=true; }
      }
   }
   why = found ? "C2 quét fractal swing HTF và đóng lại" : "không có fractal swing nào bị quét rồi đóng lại";
   return found ? best : 0;
}

// SMT với mã tương quan (thuận): setup mua cần mã kia KHÔNG tạo đáy thấp hơn đáy C1 của nó
bool SMTConfirmed(const int side,const datetime c1Time,const datetime c2Time,string &why)
{
   if(!InpUseSMT){ why="tắt"; return true; }
   int s1=iBarShift(InpSMTSymbol,InpHTF,c1Time,true);
   int s2=iBarShift(InpSMTSymbol,InpHTF,c2Time,true);
   if(s1<0 || s2<0){ why="thiếu dữ liệu "+InpSMTSymbol+" đúng thời điểm"; return false; }
   double l1=iLow(InpSMTSymbol,InpHTF,s1), l2=iLow(InpSMTSymbol,InpHTF,s2);
   double h1=iHigh(InpSMTSymbol,InpHTF,s1), h2=iHigh(InpSMTSymbol,InpHTF,s2);
   if(side>0){ bool ok = l2>=l1; why = ok ? "SMT tăng: mã tương quan không phá đáy C1" : "không SMT: mã tương quan cũng phá đáy"; return ok; }
   bool ok = h2<=h1; why = ok ? "SMT giảm: mã tương quan không phá đỉnh C1" : "không SMT: mã tương quan cũng phá đỉnh";
   return ok;
}

void AddSetup(const Setup &s)
{
   // bỏ setup đã hết hạn, tránh trùng
   for(int i=0;i<g_nSetups;i++)
      if(g_setups[i].c2Start==s.c2Start && g_setups[i].side==s.side) return;
   if(g_nSetups>=ArraySize(g_setups))
   {
      for(int i=1;i<g_nSetups;i++) g_setups[i-1]=g_setups[i];
      g_nSetups--;
   }
   g_setups[g_nSetups++]=s;
}

void EvaluateHTF(const int shift)
{
   int need = InpSwingLookback + InpPivot + 3;
   MqlRates h[];
   ArraySetAsSeries(h,false);
   int got=CopyRates(_Symbol,InpHTF,shift,need,h);
   if(got<InpPivot*2+3){ Log("HTF","không đủ dữ liệu HTF ("+IntegerToString(got)+" nến)",true); return; }
   int k=got-1;  // nến C2
   datetime c2End = h[k].time + g_htfSec;
   for(int side=1; side>=-1; side-=2)
   {
      if(side>0 && !InpAllowBuy) continue;
      if(side<0 && !InpAllowSell) continue;
      string why;
      double lv=SweptLevel(h,k,side,why);
      if(lv==0)
      {
         Log("HTF", StringFormat("C2 %s %s: không setup (%s)", TimeToString(h[k].time), SideStr(side), why));
         CountReason("HTF_khong_quet");
         continue;
      }
      string smtWhy;
      if(!SMTConfirmed(side,h[k-1].time,h[k].time,smtWhy))
      {
         Log("HTF", StringFormat("C2 %s %s: bỏ qua do SMT (%s)", TimeToString(h[k].time), SideStr(side), smtWhy));
         CountReason("HTF_khong_SMT");
         continue;
      }
      Setup s;
      s.active=true; s.side=side; s.c2Start=h[k].time; s.c2End=c2End;
      s.winEnd = c2End + InpValidHTF*g_htfSec;
      s.exitTime = c2End + InpExitHTF*g_htfSec;
      s.c2High=h[k].high; s.c2Low=h[k].low; s.level=lv;
      s.consumed = EnteredSince(c2End);  // khôi phục sau khởi động lại
      AddSetup(s);
      Log("SETUP", StringFormat("%s tạo từ C2 %s: mức=%s, C2 H/L=%s/%s, cửa sổ tới %s, SMT=%s%s",
            SideStr(side), TimeToString(h[k].time), DoubleToString(lv,_Digits),
            DoubleToString(s.c2High,_Digits), DoubleToString(s.c2Low,_Digits),
            TimeToString(s.winEnd), smtWhy, s.consumed?" (đã dùng trước đó)":""), true);
   }
}

//====================================================================
// Bước 2: CISD trên LTF
//====================================================================
bool IsAgainst(const MqlRates &b,const int side){ return side>0 ? b.close<b.open : b.close>b.open; }
bool IsWith(const MqlRates &b,const int side){ return side>0 ? b.close>b.open : b.close<b.open; }

// Chuỗi tham chiếu trong [j0..j]; trả false nếu không có
bool CisdRef(const MqlRates &r[],const int j0,const int j,const int side,
             double &ext,int &extIdx,int &runStart,int &runEnd,double &runOpen)
{
   extIdx=j0; ext = side>0 ? r[j0].low : r[j0].high;
   for(int x=j0+1;x<=j;x++)
   {
      if(side>0 && r[x].low<ext){ ext=r[x].low; extIdx=x; }
      if(side<0 && r[x].high>ext){ ext=r[x].high; extIdx=x; }
   }
   int a=extIdx;
   while(a>=j0 && !IsAgainst(r[a],side)) a--;
   if(a<j0) return false;
   int s=a;
   while(s-1>=j0 && IsAgainst(r[s-1],side)) s--;
   runStart=s; runEnd=a; runOpen=r[s].open;
   return true;
}

void ProcessSetup(Setup &s)
{
   datetime now=TimeCurrent();
   if(!s.active) return;
   if(s.consumed){ s.active=false; return; }
   MqlRates r[];
   // cần thêm nến trước cửa sổ để tính ATR
   datetime from = s.c2End - (InpATRPeriod+3)*g_ltfSec;
   int n=CopyLTF(from,r);
   if(n<=0) return;
   int j0=-1;
   for(int i=0;i<n;i++) if(r[i].time>=s.c2End){ j0=i; break; }
   if(j0<0) return;           // chưa có nến LTF nào của cửa sổ đóng
   int j=n-1;                 // nến LTF vừa đóng
   datetime jEnd = r[j].time + g_ltfSec;
   if(jEnd > s.winEnd)
   {
      s.active=false;
      CountReason("het_han_khong_CISD");
      Log("HET_HAN", StringFormat("%s C2 %s: hết cửa sổ C3 mà không vào lệnh", SideStr(s.side), TimeToString(s.c2Start)), true);
      return;
   }
   // huỷ nếu có nến LTF đóng vượt cực trị C2
   for(int x=j0;x<=j;x++)
   {
      if((s.side>0 && r[x].close<s.c2Low) || (s.side<0 && r[x].close>s.c2High))
      {
         s.active=false;
         CountReason("huy_dong_qua_cuc_tri_C2");
         Log("HUY", StringFormat("%s C2 %s: nến LTF %s đóng %s cực trị C2", SideStr(s.side), TimeToString(s.c2Start),
               TimeToString(r[x].time), s.side>0?"dưới":"trên"), true);
         return;
      }
   }
   double ext,runOpen; int extIdx,runStart,runEnd;
   if(!CisdRef(r,j0,j,s.side,ext,extIdx,runStart,runEnd,runOpen))
   {
      Log("CHO", StringFormat("%s C2 %s: chưa có chuỗi nến ngược chiều trong nhịp hồi", SideStr(s.side), TimeToString(s.c2Start)));
      return;
   }
   bool crossed = s.side>0 ? r[j].close>runOpen : r[j].close<runOpen;
   bool firstCross=true;
   for(int x=runEnd+1;x<j;x++)
      if((s.side>0 && r[x].close>runOpen) || (s.side<0 && r[x].close<runOpen)){ firstCross=false; break; }
   if(!(IsWith(r[j],s.side) && crossed && firstCross && j>runEnd))
   {
      Log("CHO", StringFormat("%s C2 %s: chưa CISD (open chuỗi=%s, đóng nến=%s, cực trị=%s)", SideStr(s.side),
            TimeToString(s.c2Start), DoubleToString(runOpen,_Digits), DoubleToString(r[j].close,_Digits), DoubleToString(ext,_Digits)));
      return;
   }
   Log("CISD", StringFormat("%s C2 %s: CISD tại nến %s (open chuỗi %s -> đóng %s), cực trị nhịp hồi %s",
         SideStr(s.side), TimeToString(s.c2Start), TimeToString(r[j].time), DoubleToString(runOpen,_Digits),
         DoubleToString(r[j].close,_Digits), DoubleToString(ext,_Digits)), true);
   if(InpRequireFVG)
   {
      bool has=false;
      for(int x=MathMax(extIdx+2,j0+2); x<=j; x++)
      {
         if(s.side>0 && r[x].low>r[x-2].high) has=true;
         if(s.side<0 && r[x].high<r[x-2].low) has=true;
      }
      if(!has){ CountReason("khong_co_FVG"); Log("TU_CHOI","không có FVG trong chân CISD",true); return; }
   }
   double atr=ATRAt(r,j,InpATRPeriod);
   TryEnter(s,ext,atr,jEnd);
}

//====================================================================
// Bước 3: vào lệnh
//====================================================================
double NormPrice(const double p)
{
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(ts<=0) return NormalizeDouble(p,_Digits);
   return NormalizeDouble(MathRound(p/ts)*ts,_Digits);
}

double CalcLot(const int side,const double entry,const double sl)
{
   double minL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double lot;
   if(InpFixedLot>0) lot=InpFixedLot;
   else
   {
      double riskMoney=AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPercent/100.0;
      double lossPerLot=0;
      ENUM_ORDER_TYPE t = side>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcProfit(t,_Symbol,1.0,entry,sl,lossPerLot)) return 0;
      lossPerLot=MathAbs(lossPerLot);
      if(lossPerLot<=0) return 0;
      lot=riskMoney/lossPerLot;
   }
   lot=MathFloor(lot/step)*step;
   if(lot<minL) return 0;     // KHÔNG làm tròn lên lot tối thiểu (sẽ vượt rủi ro)
   if(lot>maxL) lot=maxL;
   int volDigits=(int)MathMax(0,MathCeil(-MathLog10(step)-1e-9));
   return NormalizeDouble(lot,volDigits);
}

void Reject(const string key,const string msg)
{
   CountReason(key);
   Log("TU_CHOI", key+": "+msg, true);
}

void TryEnter(Setup &s,const double ext,const double atr,const datetime sigTime)
{
   if(HasOpenPosition()){ Reject("dang_co_lenh","đã có vị thế cùng magic"); return; }
   if(!InSession(sigTime)){ Reject("ngoai_phien","thời điểm tín hiệu "+TimeToString(sigTime)+" ngoài phiên"); return; }
   int entries; double closedPL; int consec;
   TodayStats(entries,closedPL,consec);
   if(entries>=InpMaxTradesDay){ Reject("du_so_lenh_ngay",IntegerToString(entries)+" lệnh hôm nay"); return; }
   if(InpMaxConsecLoss>0 && consec>=InpMaxConsecLoss){ Reject("chuoi_thua_ngay",IntegerToString(consec)+" lệnh thua liên tiếp"); return; }
   if(InpMaxDailyLossPct>0)
   {
      double bal=AccountInfoDouble(ACCOUNT_BALANCE);
      double startBal=bal-closedPL;
      if(closedPL<=-startBal*InpMaxDailyLossPct/100.0){ Reject("lo_ngay","lỗ đã đóng "+DoubleToString(closedPL,2)); return; }
   }
   if(atr<=0){ Reject("chua_du_ATR","chưa đủ nến tính ATR"); return; }

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk)){ Reject("khong_co_tick","SymbolInfoTick lỗi "+IntegerToString(GetLastError())); return; }
   double spread=tk.ask-tk.bid;
   double spreadPts=spread/_Point;
   double entry = s.side>0 ? tk.ask : tk.bid;
   double buf=InpSLBufATR*atr;
   double sl,risk;
   if(s.side>0){ sl=ext-buf; risk=entry-sl; }
   else        { sl=ext+buf+spread; risk=sl-entry; }
   if(risk<=0){ Reject("SL_khong_hop_le","giá đã vượt SL dự kiến"); return; }
   if(risk<InpMinSLATR*atr){ Reject("SL_qua_hep",StringFormat("SL=%.2f < %.2f ATR",risk,InpMinSLATR)); return; }
   if(risk>InpMaxSLATR*atr){ Reject("SL_qua_rong",StringFormat("SL=%.2f > %.2f ATR (ATR=%.2f)",risk,InpMaxSLATR,atr)); return; }
   if(InpMaxSpreadPts>0 && spreadPts>InpMaxSpreadPts){ Reject("spread_tuyet_doi",StringFormat("spread %.0f > %d point",spreadPts,InpMaxSpreadPts)); return; }
   if(spread/risk>InpMaxSpreadSL){ Reject("spread_so_voi_SL",StringFormat("spread/SL = %.2f",spread/risk)); return; }
   double tp;
   if(InpTPMode==TP_C2_EXTREME)
   {
      tp = s.side>0 ? s.c2High : s.c2Low;
      double rr = s.side>0 ? (tp-entry)/risk : (entry-tp)/risk;
      if(rr<InpMinRR){ Reject("RR_muc_tieu_thap",StringFormat("RR tới cực trị C2 = %.2f < %.2f",rr,InpMinRR)); return; }
   }
   else tp = entry + s.side*InpFixedRR*risk;

   sl=NormPrice(sl); tp=NormPrice(tp);
   // khoảng cách tối thiểu của sàn
   double stopsLvl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(MathAbs(entry-sl)<stopsLvl || MathAbs(tp-entry)<stopsLvl){ Reject("stops_level","SL/TP quá gần theo quy định sàn"); return; }

   double lot=CalcLot(s.side,entry,sl);
   if(lot<=0){ Reject("lot_qua_nho","lot tính theo rủi ro nhỏ hơn lot tối thiểu"); return; }
   double margin;
   ENUM_ORDER_TYPE ot = s.side>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(ot,_Symbol,lot,entry,margin) && margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   { Reject("khong_du_ky_quy",StringFormat("cần %.2f",margin)); return; }

   // comment chứa thời điểm thoát theo giờ để khôi phục khi khởi động lại
   string cmt=StringFormat("%s %s %I64d",InpCommentTag,s.side>0?"B":"S",(long)s.exitTime);
   bool ok=false;
   for(int attempt=0; attempt<2 && !ok; attempt++)
   {
      if(attempt>0)
      {
         if(!SymbolInfoTick(_Symbol,tk)) break;
         entry = s.side>0 ? tk.ask : tk.bid;
         if((s.side>0 && entry<=sl) || (s.side<0 && entry>=sl)) break;
      }
      ok = s.side>0 ? g_trade.Buy(lot,_Symbol,0,sl,tp,cmt) : g_trade.Sell(lot,_Symbol,0,sl,tp,cmt);
      uint rc=g_trade.ResultRetcode();
      if(ok && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_PLACED || rc==TRADE_RETCODE_DONE_PARTIAL)) break;
      Log("LOI_LENH",StringFormat("lần %d: retcode=%u (%s), lỗi=%d",attempt+1,rc,g_trade.ResultRetcodeDescription(),GetLastError()),true);
      ok=false;
      if(!(rc==TRADE_RETCODE_REQUOTE || rc==TRADE_RETCODE_PRICE_CHANGED || rc==TRADE_RETCODE_PRICE_OFF)) break;
   }
   if(ok)
   {
      s.consumed=true; s.active=false;
      CountReason("VAO_LENH");
      Log("VAO_LENH",StringFormat("%s lot=%.2f giá=%s SL=%s TP=%s rủi ro=%s (%.2f ATR) spread=%.0f pt, thoát theo giờ lúc %s",
            SideStr(s.side),lot,DoubleToString(g_trade.ResultPrice(),_Digits),DoubleToString(sl,_Digits),
            DoubleToString(tp,_Digits),DoubleToString(risk,_Digits),risk/atr,spreadPts,TimeToString(s.exitTime)),true);
   }
   else CountReason("loi_gui_lenh");
}

//====================================================================
// Quản lý vị thế: thoát theo thời gian
//====================================================================
void ManagePositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      datetime exitT=0;
      string c=PositionGetString(POSITION_COMMENT);
      string parts[];
      if(StringSplit(c,' ',parts)==3) exitT=(datetime)StringToInteger(parts[2]);
      if(exitT<=0)  // comment bị sàn sửa: dùng giới hạn trên an toàn
         exitT=(datetime)PositionGetInteger(POSITION_TIME)+InpExitHTF*g_htfSec;
      if(TimeCurrent()>=exitT)
      {
         if(g_trade.PositionClose(tk,InpDeviationPts))
            Log("THOAT_GIO",StringFormat("đóng #%I64u do hết thời gian (%s)",tk,TimeToString(exitT)),true);
         else
            Log("LOI_LENH",StringFormat("đóng #%I64u thất bại: retcode=%u %s",tk,g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription()),true);
      }
   }
}

//====================================================================
// Sự kiện
//====================================================================
int OnInit()
{
   g_htfSec=PeriodSeconds(InpHTF);
   g_ltfSec=PeriodSeconds(InpLTF);
   if(g_htfSec<=g_ltfSec)
   {
      Print("[",InpCommentTag,"] Khung HTF phải lớn hơn khung LTF");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(g_htfSec % g_ltfSec != 0)
   {
      Print("[",InpCommentTag,"] HTF phải là bội số của LTF");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpValidHTF<1 || InpExitHTF<InpValidHTF || InpPivot<1 || InpRiskPercent<0)
   {
      Print("[",InpCommentTag,"] Tham số không hợp lệ (ValidHTF>=1, ExitHTF>=ValidHTF, Pivot>=1)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseSMT && !SymbolSelect(InpSMTSymbol,true))
   {
      Print("[",InpCommentTag,"] Không tìm thấy mã SMT: ",InpSMTSymbol);
      return INIT_PARAMETERS_INCORRECT;
   }
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpDeviationPts);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetMarginMode();

   if(InpCsvLog)
   {
      string fn=StringFormat("FCISD_%s_%I64u.csv",_Symbol,InpMagic);
      g_fileHandle=FileOpen(fn,FILE_READ|FILE_WRITE|FILE_CSV|FILE_UNICODE|FILE_COMMON|FILE_SHARE_READ,';');
      if(g_fileHandle!=INVALID_HANDLE) FileSeek(g_fileHandle,0,SEEK_END);
   }
   Log("INIT",StringFormat("%s HTF=%s LTF=%s liq=%d FVG=%s TP=%d RR=%.2f rủi ro=%.2f%% phiên=%s GMT%+d SMT=%s",
         _Symbol,EnumToString(InpHTF),EnumToString(InpLTF),(int)InpLiqMode,InpRequireFVG?"bật":"tắt",(int)InpTPMode,
         InpFixedRR,InpRiskPercent,InpUseSession?"bật":"tắt",InpGMTOffset,InpUseSMT?InpSMTSymbol:"tắt"),true);

   // Khôi phục sau khởi động lại / đổi timeframe: dựng lại các setup có cửa sổ còn hiệu lực
   g_nSetups=0;
   for(int sh=InpValidHTF; sh>=1; sh--)
   {
      datetime t=iTime(_Symbol,InpHTF,sh);
      if(t==0) continue;
      if(t+g_htfSec+InpValidHTF*g_htfSec > TimeCurrent()) EvaluateHTF(sh);
   }
   g_lastHTF=iTime(_Symbol,InpHTF,0);
   g_lastLTF=0;   // xử lý nến LTF vừa đóng ở tick đầu tiên
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   string s="";
   for(int i=0;i<ArraySize(g_reasonKeys);i++) s+=g_reasonKeys[i]+"="+IntegerToString(g_reasonCnt[i])+" ";
   Log("TONG_KET","lý do dừng="+IntegerToString(reason)+" | "+s,true);
   if(g_fileHandle!=INVALID_HANDLE){ FileClose(g_fileHandle); g_fileHandle=INVALID_HANDLE; }
}

void OnTick()
{
   ManagePositions();

   datetime htf0=iTime(_Symbol,InpHTF,0);
   datetime ltf0=iTime(_Symbol,InpLTF,0);
   if(htf0==0 || ltf0==0) return;   // dữ liệu chưa sẵn sàng

   if(htf0!=g_lastHTF)
   {
      g_lastHTF=htf0;
      EvaluateHTF(1);
   }
   if(ltf0!=g_lastLTF)
   {
      g_lastLTF=ltf0;
      for(int i=0;i<g_nSetups;i++)
         if(g_setups[i].active) ProcessSetup(g_setups[i]);
      // dọn setup không còn hiệu lực
      int w=0;
      for(int i=0;i<g_nSetups;i++) if(g_setups[i].active) g_setups[w++]=g_setups[i];
      g_nSetups=w;
   }
}

double OnTester()
{
   // tiêu chí tối ưu mặc định: Profit Factor (chỉ để tham khảo, không dùng để chọn tham số trên dữ liệu kiểm tra)
   return TesterStatistics(STAT_PROFIT_FACTOR);
}
//+------------------------------------------------------------------+
