#ifndef HOST_TESTS_ALL_H
#define HOST_TESTS_ALL_H
#include "host_tests_phase1.h"
#include "host_tests_phase3.h"
inline void HostRunAllTests(void) {
    HostTestPhase1();
    HostTestPhase3();
}
#endif
