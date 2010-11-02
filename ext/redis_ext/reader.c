#include <assert.h>
#include "redis_ext.h"

/* Add VALUE to parent when the redisReadTask has a parent.
 * Note that the parent should always be of type T_ARRAY. */
static void *tryParentize(const redisReadTask *task, VALUE v) {
    if (task && task->parent != NULL) {
        VALUE parent = (VALUE)task->parent;
        assert(TYPE(parent) == T_ARRAY);
        rb_ary_store(parent,task->idx,v);
    }
    return (void*)v;
}

static void *createStringObject(const redisReadTask *task, char *str, size_t len) {
    VALUE v = rb_str_new(str,len);
    return tryParentize(task,v);
}

static void *createArrayObject(const redisReadTask *task, int elements) {
    VALUE v = rb_ary_new2(elements);
    return tryParentize(task,v);
}

static void *createIntegerObject(const redisReadTask *task, long long value) {
    VALUE v = LL2NUM(value);
    return tryParentize(task,v);
}

static void *createNilObject(const redisReadTask *task) {
    return tryParentize(task,Qnil);
}

static void freeObject(void *ptr) {
    /* Garbage collection will clean things up. */
}

/* Declare our set of reply object functions only once. */
redisReplyObjectFunctions redisExtReplyObjectFunctions = {
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
    void *reader = redisReplyReaderCreate(&redisExtReplyObjectFunctions);
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
    if (redisReplyReaderGetReply(reader,(void**)&reply) != REDIS_OK) {
        char *errstr = redisReplyReaderGetError(reader);
        rb_raise(rb_eRuntimeError, errstr);
    }
    return reply;
}

VALUE InitReader(VALUE mod) {
    VALUE klass = rb_define_class_under(mod, "Reader", rb_cObject);
    rb_define_alloc_func(klass, reader_allocate);
    rb_define_method(klass, "feed", reader_feed, 1);
    rb_define_method(klass, "gets", reader_gets, 0);
    return klass;
}
