//+------------------------------------------------------------------+
//| IDHG_TestFramework.mqh — khung self-test dùng chung               |
//| Chạy được trong MT5 (script) và trong host harness.               |
//+------------------------------------------------------------------+
#ifndef IDHG_TEST_FRAMEWORK_MQH
#define IDHG_TEST_FRAMEWORK_MQH

int    g_tPass = 0;
int    g_tFail = 0;
string g_tSuite = "";
string g_tFailed[];

void T_Begin(const string suite)
  {
   g_tSuite = suite;
   Print("------ ", suite, " ------");
  }

bool T_Check(const bool cond, const string name, const string detail = "")
  {
   if(cond)
     {
      g_tPass++;
      Print("  PASS  ", g_tSuite, " :: ", name);
      return true;
     }
   g_tFail++;
   int n = ArraySize(g_tFailed);
   ArrayResize(g_tFailed, n + 1);
   g_tFailed[n] = g_tSuite + " :: " + name + (detail != "" ? " (" + detail + ")" : "");
   Print("  FAIL  ", g_tSuite, " :: ", name, (detail != "" ? " — " + detail : ""));
   return false;
  }

bool T_Near(const double actual, const double expected, const double eps, const string name)
  {
   return T_Check(MathAbs(actual - expected) <= eps, name,
                  "thực tế=" + DoubleToString(actual, 6) + " kỳ vọng=" + DoubleToString(expected, 6));
  }

bool T_EqInt(const long actual, const long expected, const string name)
  {
   return T_Check(actual == expected, name,
                  "thực tế=" + IntegerToString(actual) + " kỳ vọng=" + IntegerToString(expected));
  }

bool T_EqStr(const string actual, const string expected, const string name)
  {
   return T_Check(actual == expected, name, "thực tế='" + actual + "' kỳ vọng='" + expected + "'");
  }

int T_Report(void)
  {
   Print("====== KẾT QUẢ: PASS=", g_tPass, " FAIL=", g_tFail, " ======");
   for(int i = 0; i < ArraySize(g_tFailed); i++)
      Print("  ✗ ", g_tFailed[i]);
   return g_tFail;
  }

#endif
