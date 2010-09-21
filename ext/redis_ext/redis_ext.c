#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "hiredis.h"
#include "ruby.h"

static VALUE mod_redis_ext;
static VALUE klass_reader;

/* Add VALUE to parent when the redisReadTask has a parent.
 * Note that the parent should always be of type T_ARRAY. */
static void *tryParentize(redisReadTask *task, VALUE v) {
    if (task && task->parent != NULL) {
        VALUE parent = (VALUE)task->parent;
        assert(TYPE(parent) == T_ARRAY);
        rb_ary_store(parent,task->idx,v);
    }
    return (void*)v;
}

static void *createStringObject(redisReadTask *task, char *str, size_t len) {
    VALUE v = rb_str_new(str,len);
    return tryParentize(task,v);
}

static void *createArrayObject(redisReadTask *task, int elements) {
    VALUE v = rb_ary_new2(elements);
    return tryParentize(task,v);
}

static void *createIntegerObject(redisReadTask *task, long long value) {
    VALUE v = LL2NUM(value);
    return tryParentize(task,v);
}

static void *createNilObject(redisReadTask *task) {
    return tryParentize(task,Qnil);
}

static void freeObject(void *ptr) {
    /* Garbage collection will clean things up. */
}

static redisReplyFunctions redisFunctions = {
    createStringObject,
    createArrayObject,
    createIntegerObject,
    createNilObject,
    freeObject
};

static void reader_mark(void *reader) {
    VALUE root;
    root = (VALUE)redisReplyReaderGetObject(reader);
    if (root != 0 && TYPE(root) == T_ARRAY) rb_gc_mark(root);
}

static VALUE reader_allocate(VALUE klass) {
    void *reader = redisReplyReaderCreate(&redisFunctions);
    return Data_Wrap_Struct(klass, reader_mark, redisReplyReaderFree, reader);
}

static VALUE reader_feed(VALUE klass, VALUE str) {
    void *reader;
    unsigned int size;

    if (TYPE(str) != T_STRING)
        rb_raise(rb_eTypeError, "not a string");

    Data_Get_Struct(klass, void, reader);
    redisReplyReaderFeed(reader, RSTRING(str)->ptr, RSTRING(str)->len);
    return INT2NUM(0);
}

static VALUE reader_gets(VALUE klass) {
    void *reader;
    VALUE reply;

    Data_Get_Struct(klass, void, reader);
    reply = (VALUE)redisReplyReaderGetReply(reader);
    return reply == 0 ? Qfalse : reply;
}

void Init_redis_ext() {
    mod_redis_ext = rb_define_module("RedisExt");
    klass_reader = rb_define_class_under(mod_redis_ext, "Reader", rb_cObject);
    rb_define_alloc_func(klass_reader, reader_allocate);
    rb_define_method(klass_reader, "feed", reader_feed, 1);
    rb_define_method(klass_reader, "gets", reader_gets, 0);
}
