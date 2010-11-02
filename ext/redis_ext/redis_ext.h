#ifndef __REDIS_EXT_H
#define __REDIS_EXT_H

#include "hiredis.h"
#include "ruby.h"

/* Defined in redis_ext.c */
extern VALUE mod_redis_ext;
extern VALUE klass_reader;

/* Defined in reader.c */
extern redisReplyObjectFunctions redisExtReplyObjectFunctions;
extern VALUE InitReader(VALUE module);

/* Borrowed from Nokogiri */
#ifndef RSTRING_PTR
#define RSTRING_PTR(s) (RSTRING(s)->ptr)
#endif

#ifndef RSTRING_LEN
#define RSTRING_LEN(s) (RSTRING(s)->len)
#endif

#ifndef RARRAY_PTR
#define RARRAY_PTR(a) RARRAY(a)->ptr
#endif

#ifndef RARRAY_LEN
#define RARRAY_LEN(a) RARRAY(a)->len
#endif

#endif
