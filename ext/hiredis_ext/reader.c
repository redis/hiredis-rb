#include <assert.h>
#include "hiredis_ext.h"

/* Force encoding on new strings? */
static VALUE enc_klass;
static ID enc_default_external = 0;
static ID str_force_encoding = 0;

/* Singleton method to test if the reply contains an error. */
ID ivar_hiredis_error;

/* Add VALUE to parent when the redisReadTask has a parent.
 * Note that the parent should always be of type T_ARRAY. */
static void *tryParentize(const redisReadTask *task, VALUE v) {
    if (task && task->parent != NULL) {
        VALUE parent = (VALUE)task->parent->obj;
        assert(TYPE(parent) == T_ARRAY);
        rb_ary_store(parent,task->idx,v);
    }
    return (void*)v;
}

static VALUE object_contains_error(VALUE self) {
    return Qtrue;
}

static void *createStringObject(const redisReadTask *task, char *str, size_t len) {
    VALUE v, enc;
    v = rb_str_new(str,len);

    /* Force default external encoding if possible. */
    if (enc_default_external) {
        enc = rb_funcall(enc_klass,enc_default_external,0);
        v = rb_funcall(v,str_force_encoding,1,enc);
    }

    if (task->type == REDIS_REPLY_ERROR) {
        v = rb_funcall(rb_eRuntimeError,rb_intern("new"),1,v);
        rb_ivar_set(v,ivar_hiredis_error,v);

        if (task && task->parent != NULL) {
            /* Also make the parent respond to this method. Redis currently
             * only emits nested multi bulks of depth 2, so we don't need
             * to cascade setting this ivar. Make sure to only set the first
             * error reply on the parent. */
            VALUE parent = (VALUE)task->parent->obj;
            if (!rb_ivar_defined(parent,ivar_hiredis_error))
                rb_ivar_set(parent,ivar_hiredis_error,v);
        }
    }

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
    void *reader = redisReplyReaderCreate();
    redisReplyReaderSetReplyObjectFunctions(reader,&redisExtReplyObjectFunctions);
    return Data_Wrap_Struct(klass, reader_mark, redisReplyReaderFree, reader);
}

static VALUE reader_feed(VALUE klass, VALUE str) {
    void *reader;
    unsigned int size;

    if (TYPE(str) != T_STRING)
        rb_raise(rb_eTypeError, "not a string");

    Data_Get_Struct(klass, void, reader);
    redisReplyReaderFeed(reader,RSTRING_PTR(str),(size_t)RSTRING_LEN(str));
    return INT2NUM(0);
}

static VALUE reader_gets(VALUE klass) {
    void *reader;
    VALUE reply;

    Data_Get_Struct(klass, void, reader);
    if (redisReplyReaderGetReply(reader,(void**)&reply) != REDIS_OK) {
        char *errstr = redisReplyReaderGetError(reader);
        rb_raise(rb_eRuntimeError,"%s",errstr);
    }

    return reply;
}

VALUE klass_reader;
void InitReader(VALUE mod) {
    klass_reader = rb_define_class_under(mod, "Reader", rb_cObject);
    rb_define_alloc_func(klass_reader, reader_allocate);
    rb_define_method(klass_reader, "feed", reader_feed, 1);
    rb_define_method(klass_reader, "gets", reader_gets, 0);
    ivar_hiredis_error = rb_intern("@__hiredis_error");

    /* If the Encoding class is present, #default_external should be used to
     * determine the encoding for new strings. The "enc_default_external"
     * ID is non-zero when encoding should be set on new strings. */
    if (rb_const_defined(rb_cObject, rb_intern("Encoding"))) {
        enc_klass = rb_const_get(rb_cObject, rb_intern("Encoding"));
        enc_default_external = rb_intern("default_external");
        str_force_encoding = rb_intern("force_encoding");
    } else {
        enc_default_external = 0;
    }
}
