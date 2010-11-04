#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "hiredis_ext.h"

VALUE mod_hiredis;
void Init_hiredis_ext() {
    mod_hiredis = rb_define_module("Hiredis");
    InitReader(mod_hiredis);
    InitConnection(mod_hiredis);
}
