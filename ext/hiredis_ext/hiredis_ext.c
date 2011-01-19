#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "hiredis_ext.h"

VALUE mod_hiredis;
VALUE mod_ext;
void Init_hiredis_ext() {
    mod_hiredis = rb_define_module("Hiredis");
    mod_ext = rb_define_module_under(mod_hiredis,"Ext");
    InitReader(mod_ext);
    InitConnection(mod_ext);
}
