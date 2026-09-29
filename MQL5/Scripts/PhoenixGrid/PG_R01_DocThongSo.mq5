//+------------------------------------------------------------------+
//|                                           PG_R01_DocThongSo.mq5  |
//|                     DAVID HUNTER – PHOENIX GRID – 0941920986     |
//|                                                                  |
//|  Phiên bản nghiên cứu PG-R0.1 — SCRIPT CHỈ ĐỌC.                  |
//|  - Không gọi OrderSend, không mở/đóng/sửa lệnh nào.              |
//|  - Không ghi số tài khoản, tên chủ tài khoản, Balance, Equity.   |
//|  Kết quả: 2 file CSV (UTF-8, phân cách ';') trong                |
//|  <Common>\Files\PhoenixGrid\ và bản sao trong tab Experts.       |
//+------------------------------------------------------------------+
#property copyright   "DAVID HUNTER – PHOENIX GRID – 0941920986"
#property version     "0.10"
#property description "PG-R0.1: đọc thông số tài khoản/symbol và thống kê spread theo tick. Không gửi lệnh."
#property script_show_inputs

input string InpSymbol        = "";            // Symbol cần đọc (để trống = symbol của chart)
input int    InpSoNgaySpread  = 30;            // Số ngày tick để thống kê spread (0 = bỏ qua)
input string InpThuMuc        = "PhoenixGrid"; // Thư mục con trong Common\Files để ghi kết quả
input bool   InpDocLichSuDeal = true;          // Đọc lịch sử deal 365 ngày để ước tính commission/phí

#define PG_PHIEN_BAN   "PG-R0.1"
#define PG_MAX_SPREAD  5000                    // spread lớn hơn mức này (point) được gộp vào ô cuối
#define PG_SO_HANG     25                      // 24 giờ server + 1 hàng tổng

int  g_file = INVALID_HANDLE;
long g_hist[];                                 // histogram spread: hàng = giờ (0..23) hoặc tổng (24)

//+------------------------------------------------------------------+
//| Tiện ích ghi                                                      |
//+------------------------------------------------------------------+
void Ghi(const string khoa, const string gia_tri, const string ghi_chu = "")
  {
   if(g_file != INVALID_HANDLE)
      FileWrite(g_file, khoa, gia_tri, ghi_chu);
   PrintFormat("%s = %s  %s", khoa, gia_tri, ghi_chu);
  }

string D(const double v, const int so_le = 8) { return DoubleToString(v, so_le); }
string I(const long v)                         { return IntegerToString(v); }
string B(const bool v)                         { return v ? "true" : "false"; }

string HHMM(const datetime t)
  {
   long s = (long)t;
   return StringFormat("%02d:%02d", (int)(s / 3600), (int)((s % 3600) / 60));
  }

//+------------------------------------------------------------------+
//| Phần 1: terminal và thời gian                                     |
//+------------------------------------------------------------------+
void DocTerminal()
  {
   datetime server = TimeTradeServer();
   datetime gmt    = TimeGMT();
   Ghi("phien_ban_script", PG_PHIEN_BAN);
   Ghi("thoi_gian_server", TimeToString(server, TIME_DATE | TIME_SECONDS));
   Ghi("thoi_gian_gmt", TimeToString(gmt, TIME_DATE | TIME_SECONDS));
   Ghi("lech_gio_server_gmt", D(MathRound((double)((long)server - (long)gmt) / 3600.0), 0),
       "giờ; dựa trên đồng hồ máy tính, cần đồng hồ máy chạy đúng");
   Ghi("terminal_build", I(TerminalInfoInteger(TERMINAL_BUILD)));
   Ghi("terminal_ket_noi", B((bool)TerminalInfoInteger(TERMINAL_CONNECTED)));
   Ghi("ping_lan_cuoi_ms", D(TerminalInfoInteger(TERMINAL_PING_LAST) / 1000.0, 1), "độ trễ tới server giao dịch");
  }

//+------------------------------------------------------------------+
//| Phần 2: tài khoản (không ghi số tài khoản, tên, số dư)            |
//+------------------------------------------------------------------+
void DocTaiKhoan()
  {
   Ghi("account_server", AccountInfoString(ACCOUNT_SERVER));
   Ghi("account_company", AccountInfoString(ACCOUNT_COMPANY));
   Ghi("account_currency", AccountInfoString(ACCOUNT_CURRENCY));
   Ghi("account_trade_mode", EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)),
       "DEMO / REAL / CONTEST");
   Ghi("account_leverage", I(AccountInfoInteger(ACCOUNT_LEVERAGE)));
   Ghi("account_margin_mode", EnumToString((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)),
       "Phoenix Grid cần RETAIL_HEDGING");
   Ghi("account_margin_so_mode", EnumToString((ENUM_ACCOUNT_STOPOUT_MODE)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)));
   Ghi("account_margin_so_call", D(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL), 2), "mức margin call");
   Ghi("account_margin_so_so", D(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 2), "mức stop out");
   Ghi("account_limit_orders", I(AccountInfoInteger(ACCOUNT_LIMIT_ORDERS)), "0 = không giới hạn");
   Ghi("account_trade_allowed", B((bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)));
   Ghi("account_trade_expert", B((bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT)));
   Ghi("so_vi_the_dang_mo", I(PositionsTotal()), "tài khoản riêng của Phoenix Grid nên là 0 trước khi chạy");
   Ghi("so_lenh_cho", I(OrdersTotal()));
  }

//+------------------------------------------------------------------+
//| Phần 3: thông số symbol                                           |
//+------------------------------------------------------------------+
void DocSymbol(const string sym)
  {
   Ghi("symbol", sym);
   Ghi("symbol_description", SymbolInfoString(sym, SYMBOL_DESCRIPTION));
   Ghi("symbol_path", SymbolInfoString(sym, SYMBOL_PATH));
   Ghi("currency_base", SymbolInfoString(sym, SYMBOL_CURRENCY_BASE));
   Ghi("currency_profit", SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT));
   Ghi("currency_margin", SymbolInfoString(sym, SYMBOL_CURRENCY_MARGIN));
   Ghi("digits", I(SymbolInfoInteger(sym, SYMBOL_DIGITS)));
   Ghi("point", D(SymbolInfoDouble(sym, SYMBOL_POINT)));
   Ghi("trade_contract_size", D(SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE)));
   Ghi("trade_tick_size", D(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE)));
   Ghi("trade_tick_value", D(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE)));
   Ghi("trade_tick_value_profit", D(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_PROFIT)));
   Ghi("trade_tick_value_loss", D(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS)));
   Ghi("trade_calc_mode", EnumToString((ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE)));
   Ghi("trade_mode", EnumToString((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_MODE)));
   Ghi("trade_exemode", EnumToString((ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(sym, SYMBOL_TRADE_EXEMODE)));

   long filling = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   Ghi("filling_mode_flags", I(filling), StringFormat("FOK=%s IOC=%s",
       B((filling & SYMBOL_FILLING_FOK) != 0), B((filling & SYMBOL_FILLING_IOC) != 0)));

   long order_mode = SymbolInfoInteger(sym, SYMBOL_ORDER_MODE);
   Ghi("order_mode_flags", I(order_mode));
   Ghi("cho_phep_close_by", B((order_mode & SYMBOL_ORDER_CLOSEBY) != 0), "đóng cặp BUY/SELL đối ứng không trả thêm spread");
   Ghi("cho_phep_sl_tp", StringFormat("SL=%s TP=%s", B((order_mode & SYMBOL_ORDER_SL) != 0),
       B((order_mode & SYMBOL_ORDER_TP) != 0)), "SL thảm họa phía server");

   Ghi("trade_stops_level", I(SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL)), "point");
   Ghi("trade_freeze_level", I(SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL)), "point");
   Ghi("volume_min", D(SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN), 4));
   Ghi("volume_max", D(SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX), 4));
   Ghi("volume_step", D(SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP), 4));
   Ghi("volume_limit", D(SymbolInfoDouble(sym, SYMBOL_VOLUME_LIMIT), 4), "0 = không giới hạn tổng khối lượng");
   Ghi("spread_hien_tai_point", I(SymbolInfoInteger(sym, SYMBOL_SPREAD)));
   Ghi("spread_float", B((bool)SymbolInfoInteger(sym, SYMBOL_SPREAD_FLOAT)));
   Ghi("swap_mode", EnumToString((ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(sym, SYMBOL_SWAP_MODE)));
   Ghi("swap_long", D(SymbolInfoDouble(sym, SYMBOL_SWAP_LONG), 4));
   Ghi("swap_short", D(SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT), 4));
   Ghi("swap_rollover3days", EnumToString((ENUM_DAY_OF_WEEK)SymbolInfoInteger(sym, SYMBOL_SWAP_ROLLOVER3DAYS)),
       "ngày tính swap ×3");
   Ghi("margin_initial", D(SymbolInfoDouble(sym, SYMBOL_MARGIN_INITIAL)));
   Ghi("margin_maintenance", D(SymbolInfoDouble(sym, SYMBOL_MARGIN_MAINTENANCE)));
   Ghi("margin_hedged", D(SymbolInfoDouble(sym, SYMBOL_MARGIN_HEDGED)));
   Ghi("margin_hedged_use_leg", B((bool)SymbolInfoInteger(sym, SYMBOL_MARGIN_HEDGED_USE_LEG)),
       "true = chỉ tính margin cho chân lớn hơn");

   double rate_init = 0.0, rate_maint = 0.0;
   if(SymbolInfoMarginRate(sym, ORDER_TYPE_BUY, rate_init, rate_maint))
     {
      Ghi("margin_rate_buy_initial", D(rate_init, 6));
      Ghi("margin_rate_buy_maintenance", D(rate_maint, 6));
     }
   if(SymbolInfoMarginRate(sym, ORDER_TYPE_SELL, rate_init, rate_maint))
     {
      Ghi("margin_rate_sell_initial", D(rate_init, 6));
      Ghi("margin_rate_sell_maintenance", D(rate_maint, 6));
     }
  }

//+------------------------------------------------------------------+
//| Phần 4: giá trị suy ra — VPP, K (giả định H_K), margin, swap      |
//+------------------------------------------------------------------+
void TinhGiaTriSuyRa(const string sym)
  {
   MqlTick tick;
   if(!SymbolInfoTick(sym, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
     {
      Ghi("gia_hien_tai", "khong_co_tick", StringFormat("lỗi %d; mở chart symbol khi thị trường đang mở", GetLastError()));
      return;
     }
   double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tv_loss   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
   double tv_profit = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   double vmin      = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

   Ghi("gia_bid", D(tick.bid, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)));
   Ghi("gia_ask", D(tick.ask, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)));
   Ghi("thoi_diem_tick", TimeToString(tick.time, TIME_DATE | TIME_SECONDS));

   if(tick_size > 0.0)
     {
      double vpp_loss = tv_loss / tick_size;
      Ghi("vpp_loss", D(vpp_loss, 6), "tiền tài khoản khi 1 lot đi ngược 1,0 giá (1 USD/oz)");
      Ghi("vpp_profit", D(tv_profit / tick_size, 6), "tiền tài khoản khi 1 lot đi thuận 1,0 giá");
      Ghi("K_theo_tick_value", D(0.01 * vpp_loss, 6), "0,01 lot, 1 USD/oz; giả định H_K = 1 USC");
      Ghi("lo_lot_toi_thieu_100_usd", D(vmin * vpp_loss * 100.0, 2), "lot tối thiểu, giá đi ngược 100 USD/oz");
      Ghi("spread_hien_tai_tien_001_lot", D((tick.ask - tick.bid) * 0.01 * vpp_loss, 4), "chi phí spread của 0,01 lot");

      long swap_mode = SymbolInfoInteger(sym, SYMBOL_SWAP_MODE);
      if(swap_mode == SYMBOL_SWAP_MODE_POINTS)
        {
         Ghi("swap_long_tien_1_lot_1_dem", D(SymbolInfoDouble(sym, SYMBOL_SWAP_LONG) * point * vpp_loss, 4));
         Ghi("swap_short_tien_1_lot_1_dem", D(SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT) * point * vpp_loss, 4));
        }
      else
         Ghi("swap_tien_1_lot_1_dem", "khong_tinh_tu_dong", "swap_mode khác POINTS, xem swap_long/swap_short");
     }

   // K tính trực tiếp bằng OrderCalcProfit: giá đi ngược đúng 1,0 (1 USD/oz)
   double p = 0.0;
   if(OrderCalcProfit(ORDER_TYPE_BUY, sym, 0.01, tick.ask, tick.ask - 1.0, p))
      Ghi("K_theo_OrderCalcProfit_buy", D(-p, 6), "lỗ của BUY 0,01 khi giá giảm 1,0");
   else
      Ghi("K_theo_OrderCalcProfit_buy", "loi", I(GetLastError()));
   if(OrderCalcProfit(ORDER_TYPE_SELL, sym, 0.01, tick.bid, tick.bid + 1.0, p))
      Ghi("K_theo_OrderCalcProfit_sell", D(-p, 6), "lỗ của SELL 0,01 khi giá tăng 1,0");
   else
      Ghi("K_theo_OrderCalcProfit_sell", "loi", I(GetLastError()));

   // Margin theo từng chân, KHÔNG tính ưu đãi hedge (đúng cách tính dự trữ margin phòng thủ của kế hoạch)
   double m = 0.0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, sym, 0.01, tick.ask, m))
      Ghi("margin_buy_001", D(m, 4), "margin 1 chân BUY 0,01 tại giá Ask hiện tại");
   if(OrderCalcMargin(ORDER_TYPE_SELL, sym, 0.01, tick.bid, m))
      Ghi("margin_sell_001", D(m, 4), "margin 1 chân SELL 0,01 tại giá Bid hiện tại");
   if(OrderCalcMargin(ORDER_TYPE_BUY, sym, vmin, tick.ask, m))
      Ghi("margin_buy_lot_toi_thieu", D(m, 4));
   if(OrderCalcMargin(ORDER_TYPE_BUY, sym, 1.0, tick.ask, m))
      Ghi("margin_buy_1_lot", D(m, 4));
   Ghi("margin_cap_hedge_thuc_te", "can_do_tay_tren_demo",
       "mở BUY 0,01 + SELL 0,01 trên DEMO, ghi Margin trước/sau (xem hướng dẫn R0.1)");

   // Kiểm tra giả định H_K (chỉ có nghĩa khi tiền tài khoản là USC)
   if(OrderCalcProfit(ORDER_TYPE_BUY, sym, 0.01, tick.ask, tick.ask - 1.0, p))
     {
      bool usc = (AccountInfoString(ACCOUNT_CURRENCY) == "USC");
      bool dat = usc && MathAbs(-p - 1.0) <= 0.02;
      Ghi("kiem_tra_H_K", dat ? "DAT" : "KHONG_DAT",
          StringFormat("K = %.6f %s; H_K: 0,01 lot = 1 USC mỗi 1 USD/oz", -p, AccountInfoString(ACCOUNT_CURRENCY)));
     }
  }

//+------------------------------------------------------------------+
//| Phần 5: phiên giao dịch và phiên báo giá (giờ server)             |
//+------------------------------------------------------------------+
void DocPhien(const string sym)
  {
   for(int d = 0; d < 7; d++)
     {
      ENUM_DAY_OF_WEEK ngay = (ENUM_DAY_OF_WEEK)d;
      string gd = "", bg = "";
      datetime from = 0, to = 0;
      for(uint k = 0; k < 10; k++)
        {
         if(!SymbolInfoSessionTrade(sym, ngay, k, from, to))
            break;
         gd += (gd == "" ? "" : ",") + HHMM(from) + "-" + HHMM(to);
        }
      for(uint k = 0; k < 10; k++)
        {
         if(!SymbolInfoSessionQuote(sym, ngay, k, from, to))
            break;
         bg += (bg == "" ? "" : ",") + HHMM(from) + "-" + HHMM(to);
        }
      Ghi("phien_giao_dich_" + EnumToString(ngay), gd == "" ? "khong_co" : gd);
      Ghi("phien_bao_gia_" + EnumToString(ngay), bg == "" ? "khong_co" : bg);
     }
  }

//+------------------------------------------------------------------+
//| Phần 6: lịch sử deal → ước tính commission/phí                    |
//+------------------------------------------------------------------+
void DocLichSuDeal(const string sym)
  {
   if(!InpDocLichSuDeal)
     {
      Ghi("lich_su_deal", "bo_qua", "InpDocLichSuDeal = false");
      return;
     }
   datetime den = TimeCurrent();
   datetime tu  = (datetime)((long)den - 365L * 86400L);
   if(!HistorySelect(tu, den))
     {
      Ghi("lich_su_deal", "loi", I(GetLastError()));
      return;
     }
   int    tong   = HistoryDealsTotal();
   int    so     = 0;
   double lot_in = 0.0, comm = 0.0, fee = 0.0;
   for(int i = 0; i < tong; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0 || HistoryDealGetString(tk, DEAL_SYMBOL) != sym)
         continue;
      long loai = HistoryDealGetInteger(tk, DEAL_TYPE);
      if(loai != DEAL_TYPE_BUY && loai != DEAL_TYPE_SELL)
         continue;
      so++;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         lot_in += HistoryDealGetDouble(tk, DEAL_VOLUME);
      comm += HistoryDealGetDouble(tk, DEAL_COMMISSION);
      fee  += HistoryDealGetDouble(tk, DEAL_FEE);
     }
   Ghi("lich_su_deal_so_deal", I(so), "deal BUY/SELL của symbol trong 365 ngày");
   if(lot_in > 0.0)
      Ghi("commission_fee_moi_lot_khu_hoi", D((comm + fee) / lot_in, 4), "tổng commission + fee chia tổng lot vào lệnh");
   else
      Ghi("commission_fee_moi_lot_khu_hoi", "chua_co_deal", "tài khoản chưa có deal trên symbol này");
  }

//+------------------------------------------------------------------+
//| Phần 7: thống kê spread theo tick trong N ngày gần nhất           |
//+------------------------------------------------------------------+
int PhanVi(const int hang, const long tong_hang, const double q)
  {
   if(tong_hang <= 0)
      return -1;
   long nguong = (long)MathCeil(q * (double)tong_hang);
   if(nguong < 1)
      nguong = 1;
   int  rong = PG_MAX_SPREAD + 1;
   long cong = 0;
   for(int sp = 0; sp < rong; sp++)
     {
      cong += g_hist[hang * rong + sp];
      if(cong >= nguong)
         return sp;
     }
   return PG_MAX_SPREAD;
  }

int LonNhat(const int hang)
  {
   int rong = PG_MAX_SPREAD + 1;
   for(int sp = PG_MAX_SPREAD; sp >= 0; sp--)
      if(g_hist[hang * rong + sp] > 0)
         return sp;
   return -1;
  }

void ThongKeSpread(const string sym, const string stamp)
  {
   if(InpSoNgaySpread <= 0)
     {
      Ghi("spread_tick", "bo_qua", "InpSoNgaySpread = 0");
      return;
     }
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0)
     {
      Ghi("spread_tick", "loi", "point = 0");
      return;
     }
   int rong = PG_MAX_SPREAD + 1;
   ArrayResize(g_hist, PG_SO_HANG * rong);
   ArrayInitialize(g_hist, 0);

   long bay_gio = (long)TimeTradeServer();
   long ngay_0  = bay_gio - (long)InpSoNgaySpread * 86400L;
   ngay_0      -= ngay_0 % 86400L;               // đầu ngày server
   long dem[PG_SO_HANG];
   ArrayInitialize(dem, 0);
   int  ngay_co_tick = 0, ngay_loi = 0;
   MqlTick ticks[];

   for(long d = ngay_0; d < bay_gio; d += 86400L)
     {
      ulong tu_msc  = (ulong)d * 1000;
      ulong den_msc = (ulong)(d + 86400L) * 1000 - 1;
      ResetLastError();
      int n = CopyTicksRange(sym, ticks, COPY_TICKS_INFO, tu_msc, den_msc);
      if(n < 0)
        {
         ngay_loi++;
         PrintFormat("CopyTicksRange lỗi %d ngày %s", GetLastError(), TimeToString((datetime)d, TIME_DATE));
         continue;
        }
      if(n == 0)
         continue;
      ngay_co_tick++;
      PrintFormat("PG-R0.1: ngày %s có %d tick", TimeToString((datetime)d, TIME_DATE), n);
      for(int i = 0; i < n; i++)
        {
         if(ticks[i].bid <= 0.0 || ticks[i].ask <= 0.0 || ticks[i].ask < ticks[i].bid)
            continue;
         int sp = (int)MathRound((ticks[i].ask - ticks[i].bid) / point);
         if(sp > PG_MAX_SPREAD)
            sp = PG_MAX_SPREAD;
         int gio = (int)(((long)ticks[i].time % 86400L) / 3600L);
         g_hist[gio * rong + sp]++;
         g_hist[24 * rong + sp]++;
         dem[gio]++;
         dem[24]++;
        }
     }

   Ghi("spread_tick_so_ngay_yeu_cau", I(InpSoNgaySpread));
   Ghi("spread_tick_so_ngay_co_tick", I(ngay_co_tick));
   Ghi("spread_tick_so_ngay_loi", I(ngay_loi), "CopyTicksRange trả lỗi (thường do chưa tải lịch sử tick)");
   Ghi("spread_tick_tong_so_tick", I(dem[24]));
   if(dem[24] <= 0)
      return;
   Ghi("spread_tick_trung_vi_point", I(PhanVi(24, dem[24], 0.50)));
   Ghi("spread_tick_p90_point", I(PhanVi(24, dem[24], 0.90)));
   Ghi("spread_tick_p99_point", I(PhanVi(24, dem[24], 0.99)));
   Ghi("spread_tick_p999_point", I(PhanVi(24, dem[24], 0.999)));
   Ghi("spread_tick_lon_nhat_point", I(LonNhat(24)), StringFormat("gộp ở %d nếu lớn hơn", PG_MAX_SPREAD));

   string ten = InpThuMuc + "\\PG_R01_spread_theo_gio_" + sym + "_" + stamp + ".csv";
   int f = FileOpen(ten, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';', CP_UTF8);
   if(f == INVALID_HANDLE)
     {
      PrintFormat("Không mở được file %s (lỗi %d)", ten, GetLastError());
      return;
     }
   FileWrite(f, "gio_server", "so_tick", "trung_vi_point", "p90_point", "p99_point", "lon_nhat_point");
   for(int h = 0; h < 24; h++)
      FileWrite(f, h, dem[h], PhanVi(h, dem[h], 0.50), PhanVi(h, dem[h], 0.90), PhanVi(h, dem[h], 0.99), LonNhat(h));
   FileClose(f);
   Ghi("file_spread_theo_gio", ten);
  }

//+------------------------------------------------------------------+
//| Điểm vào                                                          |
//+------------------------------------------------------------------+
void OnStart()
  {
   string sym = (InpSymbol == "") ? _Symbol : InpSymbol;
   if(!SymbolSelect(sym, true))
     {
      PrintFormat("PG-R0.1: không chọn được symbol %s (lỗi %d)", sym, GetLastError());
      return;
     }

   string stamp = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES);
   StringReplace(stamp, ".", "");
   StringReplace(stamp, ":", "");
   StringReplace(stamp, " ", "_");

   FolderCreate(InpThuMuc, FILE_COMMON);
   string ten = InpThuMuc + "\\PG_R01_thong_so_" + sym + "_" + stamp + ".csv";
   g_file = FileOpen(ten, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';', CP_UTF8);
   if(g_file == INVALID_HANDLE)
     {
      PrintFormat("PG-R0.1: không mở được file %s (lỗi %d)", ten, GetLastError());
      return;
     }
   FileWrite(g_file, "khoa", "gia_tri", "ghi_chu");

   DocTerminal();
   DocTaiKhoan();
   DocSymbol(sym);
   TinhGiaTriSuyRa(sym);
   DocPhien(sym);
   DocLichSuDeal(sym);
   ThongKeSpread(sym, stamp);

   FileClose(g_file);
   g_file = INVALID_HANDLE;
   PrintFormat("PG-R0.1: đã ghi %s trong thư mục Common\\Files (%s)", ten,
               TerminalInfoString(TERMINAL_COMMONDATA_PATH));
  }
//+------------------------------------------------------------------+
