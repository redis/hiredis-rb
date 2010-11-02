#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "redis_ext.h"

VALUE mod_redis_ext;
void Init_redis_ext() {
    mod_redis_ext = rb_define_module("RedisExt");
    InitReader(mod_redis_ext);
    InitConnection(mod_redis_ext);
}
