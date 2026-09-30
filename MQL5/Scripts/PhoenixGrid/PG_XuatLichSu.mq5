//+------------------------------------------------------------------+
//|                                               PG_XuatLichSu.mq5  |
//|                     DAVID HUNTER – PHOENIX GRID – 0941920986     |
//|                                                                  |
//|  Script CHỈ ĐỌC. Xuất ra CSV để phân tích hành vi một EA đang     |
//|  chạy (ví dụ Hydra 4.5) từ chính lịch sử tài khoản:              |
//|  - mọi deal (vào / ra, giá, lot, lãi, lý do đóng, magic, comment)|
//|  - mọi lệnh trong lịch sử (loại, trạng thái, SL / TP, comment)   |
//|  - các vị thế đang mở lúc chạy script                            |
//|  Không gửi, không sửa, không đóng lệnh. Chạy một lần rồi tự dừng.|
//|  File ghi vào Common\Files\<thư mục>, tên có server và khoảng    |
//|  ngày (không có số tài khoản).                                   |
//|  Chưa compile trong môi trường phát triển.                       |
//+------------------------------------------------------------------+
#property copyright   "DAVID HUNTER – PHOENIX GRID – 0941920986"
#property version     "1.00"
#property description "Chỉ đọc: xuất lịch sử deal, lệnh và vị thế đang mở ra CSV (Common\\Files\\PhoenixGrid). Không gửi lệnh."
#property script_show_inputs

input datetime InpTuNgay  = D'2026.01.01 00:00';   // Từ ngày (giờ server)
input datetime InpDenNgay = 0;                      // Đến ngày (0 = tới bây giờ)
input string   InpSymbol  = "";                     // Chỉ symbol này (để trống = mọi symbol)
input long     InpMagic   = -1;                     // Chỉ magic này (-1 = mọi magic, 0 = lệnh tay)
input string   InpThuMuc  = "PhoenixGrid";          // Thư mục con trong Common\Files

//--- Bỏ ký tự phân cách và xuống dòng khỏi chuỗi (comment của lệnh)
string Sach(string s)
  {
   StringReplace(s, ";", ",");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
  }

//--- Tên server chỉ giữ chữ, số và dấu gạch
string TenServer()
  {
   string s = AccountInfoString(ACCOUNT_SERVER), r = "";
   for(int i = 0; i < StringLen(s); i++)
     {
      ushort c = StringGetCharacter(s, i);
      bool ok = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '-';
      r += ok ? ShortToString(c) : "-";
     }
   return r;
  }

string Ngay(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return StringFormat("%04d%02d%02d", d.year, d.mon, d.day);
  }

string Gia(const string sym, const double v)
  {
   int dg = (sym != "") ? (int)SymbolInfoInteger(sym, SYMBOL_DIGITS) : 0;
   return DoubleToString(v, (dg > 0) ? dg : 5);
  }

string TG(const datetime t) { return (t > 0) ? TimeToString(t, TIME_DATE | TIME_SECONDS) : ""; }

int MoFile(const string ten, const string tieuDe)
  {
   int h = FileOpen(InpThuMuc + "\\" + ten, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';', CP_UTF8);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("PG: không mở được %s (lỗi %d)", ten, GetLastError());
      return INVALID_HANDLE;
     }
   FileWriteString(h, tieuDe + "\r\n");
   return h;
  }

bool Loc(const string sym, const long magic, const bool laSoDu)
  {
   if(laSoDu)
      return true;                                   // nạp / rút luôn giữ (xem được lúc nạp lại sau khi cháy)
   if(InpSymbol != "" && sym != InpSymbol)
      return false;
   if(InpMagic >= 0 && magic != InpMagic)
      return false;
   return true;
  }

int XuatDeal(const string ten)
  {
   int h = MoFile(ten, "ticket;order;position_id;magic;symbol;time;time_msc;type;entry;reason;volume;price;profit;commission;swap;fee;sl;tp;comment");
   if(h == INVALID_HANDLE)
      return -1;
   int n = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      string sym   = HistoryDealGetString(d, DEAL_SYMBOL);
      long   magic = HistoryDealGetInteger(d, DEAL_MAGIC);
      ENUM_DEAL_TYPE loai = (ENUM_DEAL_TYPE)HistoryDealGetInteger(d, DEAL_TYPE);
      if(!Loc(sym, magic, loai == DEAL_TYPE_BALANCE))
         continue;
      string s = StringFormat("%I64u;%I64d;%I64d;%I64d;%s;%s;%I64d;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s",
                              d, HistoryDealGetInteger(d, DEAL_ORDER), HistoryDealGetInteger(d, DEAL_POSITION_ID), magic, sym,
                              TG((datetime)HistoryDealGetInteger(d, DEAL_TIME)), HistoryDealGetInteger(d, DEAL_TIME_MSC),
                              EnumToString(loai), EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY)),
                              EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(d, DEAL_REASON)),
                              DoubleToString(HistoryDealGetDouble(d, DEAL_VOLUME), 2), Gia(sym, HistoryDealGetDouble(d, DEAL_PRICE)),
                              DoubleToString(HistoryDealGetDouble(d, DEAL_PROFIT), 2), DoubleToString(HistoryDealGetDouble(d, DEAL_COMMISSION), 2),
                              DoubleToString(HistoryDealGetDouble(d, DEAL_SWAP), 2), DoubleToString(HistoryDealGetDouble(d, DEAL_FEE), 2),
                              Gia(sym, HistoryDealGetDouble(d, DEAL_SL)), Gia(sym, HistoryDealGetDouble(d, DEAL_TP)),
                              Sach(HistoryDealGetString(d, DEAL_COMMENT)));
      FileWriteString(h, s + "\r\n");
      n++;
     }
   FileClose(h);
   return n;
  }

int XuatLenh(const string ten)
  {
   int h = MoFile(ten, "ticket;position_id;magic;symbol;time_setup;time_done;type;state;reason;volume_initial;volume_current;price_open;sl;tp;comment");
   if(h == INVALID_HANDLE)
      return -1;
   int n = 0;
   for(int i = 0; i < HistoryOrdersTotal(); i++)
     {
      ulong o = HistoryOrderGetTicket(i);
      if(o == 0)
         continue;
      string sym   = HistoryOrderGetString(o, ORDER_SYMBOL);
      long   magic = HistoryOrderGetInteger(o, ORDER_MAGIC);
      if(!Loc(sym, magic, false))
         continue;
      string s = StringFormat("%I64u;%I64d;%I64d;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s",
                              o, HistoryOrderGetInteger(o, ORDER_POSITION_ID), magic, sym,
                              TG((datetime)HistoryOrderGetInteger(o, ORDER_TIME_SETUP)), TG((datetime)HistoryOrderGetInteger(o, ORDER_TIME_DONE)),
                              EnumToString((ENUM_ORDER_TYPE)HistoryOrderGetInteger(o, ORDER_TYPE)),
                              EnumToString((ENUM_ORDER_STATE)HistoryOrderGetInteger(o, ORDER_STATE)),
                              EnumToString((ENUM_ORDER_REASON)HistoryOrderGetInteger(o, ORDER_REASON)),
                              DoubleToString(HistoryOrderGetDouble(o, ORDER_VOLUME_INITIAL), 2),
                              DoubleToString(HistoryOrderGetDouble(o, ORDER_VOLUME_CURRENT), 2),
                              Gia(sym, HistoryOrderGetDouble(o, ORDER_PRICE_OPEN)), Gia(sym, HistoryOrderGetDouble(o, ORDER_SL)),
                              Gia(sym, HistoryOrderGetDouble(o, ORDER_TP)), Sach(HistoryOrderGetString(o, ORDER_COMMENT)));
      FileWriteString(h, s + "\r\n");
      n++;
     }
   FileClose(h);
   return n;
  }

int XuatViThe(const string ten)
  {
   int h = MoFile(ten, "ticket;magic;symbol;time;type;volume;price_open;sl;tp;price_current;profit;swap;comment");
   if(h == INVALID_HANDLE)
      return -1;
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong p = PositionGetTicket(i);
      if(p == 0)
         continue;
      string sym   = PositionGetString(POSITION_SYMBOL);
      long   magic = PositionGetInteger(POSITION_MAGIC);
      if(!Loc(sym, magic, false))
         continue;
      string s = StringFormat("%I64u;%I64d;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s",
                              p, magic, sym, TG((datetime)PositionGetInteger(POSITION_TIME)),
                              EnumToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)),
                              DoubleToString(PositionGetDouble(POSITION_VOLUME), 2), Gia(sym, PositionGetDouble(POSITION_PRICE_OPEN)),
                              Gia(sym, PositionGetDouble(POSITION_SL)), Gia(sym, PositionGetDouble(POSITION_TP)),
                              Gia(sym, PositionGetDouble(POSITION_PRICE_CURRENT)), DoubleToString(PositionGetDouble(POSITION_PROFIT), 2),
                              DoubleToString(PositionGetDouble(POSITION_SWAP), 2), Sach(PositionGetString(POSITION_COMMENT)));
      FileWriteString(h, s + "\r\n");
      n++;
     }
   FileClose(h);
   return n;
  }

void OnStart()
  {
   datetime den = (InpDenNgay > 0) ? InpDenNgay : (datetime)((long)TimeCurrent() + 86400);
   if(den <= InpTuNgay)
     {
      Alert("PG_XuatLichSu: 'Đến ngày' phải sau 'Từ ngày'");
      return;
     }
   ResetLastError();
   if(!FolderCreate(InpThuMuc, FILE_COMMON))
      PrintFormat("PG: FolderCreate trả về false (lỗi %d), có thể thư mục đã tồn tại", GetLastError());
   if(!HistorySelect(InpTuNgay, den))
     {
      Alert("PG_XuatLichSu: không đọc được lịch sử tài khoản");
      return;
     }
   string sv = TenServer(), ky = Ngay(InpTuNgay) + "_" + Ngay(den);
   string loc = ((InpSymbol != "") ? "_" + InpSymbol : "") + ((InpMagic >= 0) ? "_m" + IntegerToString(InpMagic) : "");
   int nD = XuatDeal("PG_lich_su_deal_" + sv + loc + "_" + ky + ".csv");
   int nL = XuatLenh("PG_lich_su_lenh_" + sv + loc + "_" + ky + ".csv");
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   int nV = XuatViThe("PG_vi_the_mo_" + sv + loc + "_" + StringFormat("%04d%02d%02d_%02d%02d", d.year, d.mon, d.day, d.hour, d.min) + ".csv");
   string ms = StringFormat("PG_XuatLichSu: %d deal, %d lệnh, %d vị thế đang mở -> Common\\Files\\%s", nD, nL, nV, InpThuMuc);
   Print(ms);
   Alert(ms);
  }
//+------------------------------------------------------------------+
