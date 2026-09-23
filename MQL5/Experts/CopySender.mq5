//+------------------------------------------------------------------+
//|                                                   CopySender.mq5 |
//| Gan vao terminal dang dang nhap tai khoan NGUON (ke ca mat khau  |
//| investor). EA chi doc vi the + lenh cho va ghi ra                |
//| Common\Files\<kenh>.csv de CopyReceiver.mq5 o terminal khac tren |
//| CUNG MAY sao chep lai. EA nay KHONG dat lenh.                    |
//+------------------------------------------------------------------+
#property copyright "CopySender"
#property version   "1.00"
#property description "Ghi vi the + lenh cho cua tai khoan nguon ra Common\\Files de CopyReceiver sao chep."

input string InpChannel    = "copy1"; // Ten kenh (phai trung voi CopyReceiver)
input int    InpIntervalMs = 250;     // Chu ky ghi (ms)

string D(const string sym, const double v)
  {
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   return DoubleToString(v, digits > 0 ? digits : 5);
  }

void AddUnique(string &arr[], const string s)
  {
   for(int i = 0; i < ArraySize(arr); i++)
      if(arr[i] == s)
         return;
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n] = s;
  }

void Publish()
  {
   int h = FileOpen(InpChannel + ".csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return; // receiver dang doc, lan sau ghi lai
   int n = 0;
   FileWriteString(h, StringFormat("H,%I64d,%.2f,%I64d\r\n", (long)TimeLocal(),
                                   AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoInteger(ACCOUNT_LOGIN)));
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      string s = PositionGetString(POSITION_SYMBOL);
      FileWriteString(h, StringFormat("P,%I64u,%s,%d,%.2f,%s,%s,%s\r\n", t, s,
                                      (int)PositionGetInteger(POSITION_TYPE),
                                      PositionGetDouble(POSITION_VOLUME),
                                      D(s, PositionGetDouble(POSITION_PRICE_OPEN)),
                                      D(s, PositionGetDouble(POSITION_SL)),
                                      D(s, PositionGetDouble(POSITION_TP))));
      n++;
     }
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      string s = OrderGetString(ORDER_SYMBOL);
      FileWriteString(h, StringFormat("O,%I64u,%s,%d,%.2f,%s,%s,%s\r\n", t, s,
                                      (int)OrderGetInteger(ORDER_TYPE),
                                      OrderGetDouble(ORDER_VOLUME_CURRENT),
                                      D(s, OrderGetDouble(ORDER_PRICE_OPEN)),
                                      D(s, OrderGetDouble(ORDER_SL)),
                                      D(s, OrderGetDouble(ORDER_TP))));
      n++;
     }
   // gia hien tai cua nguon -> receiver bu chenh lech gia giua 2 san
   string qs[];
   ArrayResize(qs, 0);
   for(int i = 0; i < PositionsTotal(); i++)
      if(PositionGetTicket(i) != 0)
         AddUnique(qs, PositionGetString(POSITION_SYMBOL));
   for(int i = 0; i < OrdersTotal(); i++)
      if(OrderGetTicket(i) != 0)
         AddUnique(qs, OrderGetString(ORDER_SYMBOL));
   AddUnique(qs, _Symbol);
   for(int i = 0; i < ArraySize(qs); i++)
      FileWriteString(h, StringFormat("Q,%s,%s,%s\r\n", qs[i],
                                      D(qs[i], SymbolInfoDouble(qs[i], SYMBOL_BID)),
                                      D(qs[i], SymbolInfoDouble(qs[i], SYMBOL_ASK))));
   // dong ket thuc: receiver dung de biet file da ghi xong
   FileWriteString(h, StringFormat("E,%d\r\n", n));
   FileClose(h);
  }

int OnInit()
  {
   PrintFormat("[CopySender] Tai khoan %I64d, kenh '%s' -> %s\\Files\\%s.csv",
               AccountInfoInteger(ACCOUNT_LOGIN), InpChannel,
               TerminalInfoString(TERMINAL_COMMONDATA_PATH), InpChannel);
   EventSetMillisecondTimer(MathMax(50, InpIntervalMs));
   Publish();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { EventKillTimer(); }
void OnTimer()                  { Publish(); }
void OnTick()                   {}
//+------------------------------------------------------------------+
