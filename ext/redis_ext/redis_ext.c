#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "redis_ext.h"

VALUE mod_redis_ext;
VALUE klass_reader;

void Init_redis_ext() {
    mod_redis_ext = rb_define_module("RedisExt");
    klass_reader = InitReader(mod_redis_ext);
}
