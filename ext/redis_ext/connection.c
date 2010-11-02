#include <errno.h>
#include "redis_ext.h"

typedef struct redisParentContext {
    redisContext *context;
} redisParentContext;

static void parent_context_try_free(redisParentContext *pc) {
    if (pc->context) {
        redisFree(pc->context);
        pc->context = NULL;
    }
}

static void parent_context_mark(redisParentContext *pc) {
    VALUE root;
    fflush(stdout);
    if (pc->context && pc->context->reader) {
        root = (VALUE)redisReplyReaderGetObject(pc->context->reader);
        if (root != 0 && TYPE(root) == T_ARRAY) {
            rb_gc_mark(root);
        }
    }
}

static void parent_context_free(redisParentContext *pc) {
    parent_context_try_free(pc);
    free(pc);
}

static VALUE connection_parent_context_alloc(VALUE klass) {
    redisParentContext *pc = malloc(sizeof(*pc));
    pc->context = NULL;
    return Data_Wrap_Struct(klass, parent_context_mark, parent_context_free, pc);
}

static VALUE connection_connect(VALUE self, VALUE _host, VALUE _port) {
    redisParentContext *pc;
    redisContext *c;
    char *host = StringValuePtr(_host);
    int port = NUM2INT(_port);
    int err;
    char errstr[1024];

    Data_Get_Struct(self,redisParentContext,pc);
    parent_context_try_free(pc);

    c = redisConnect(host,port);
    if (c->err) {
        /* Copy error and free context */
        err = c->err;
        snprintf(errstr,sizeof(errstr),"%s",c->errstr);
        redisFree(c);

        if (err == REDIS_ERR_IO) {
            /* Raise native Ruby I/O error */
            rb_sys_fail(0);
        } else {
            /* Raise something else */
            rb_raise(rb_eRuntimeError,errstr);
        }
    }

    redisSetReplyObjectFunctions(c,&redisExtReplyObjectFunctions);
    pc->context = c;
    return Qnil;
}

static VALUE connection_is_connected(VALUE self) {
    redisParentContext *pc;
    Data_Get_Struct(self,redisParentContext,pc);
    if (pc->context && !pc->context->err)
        return Qtrue;
    else
        return Qfalse;
}

static VALUE connection_disconnect(VALUE self) {
    redisParentContext *pc;
    Data_Get_Struct(self,redisParentContext,pc);
    if (!pc->context)
        rb_raise(rb_eRuntimeError, "not connected");
    parent_context_try_free(pc);
    return Qnil;
}

static VALUE connection_write(VALUE self, VALUE command) {
    redisParentContext *pc;
    int argc;
    char **argv = NULL;
    size_t *alen = NULL;
    int i;

    /* Commands should be an array of commands, where each command
     * is an array of string arguments. */
    if (TYPE(command) != T_ARRAY)
        rb_raise(rb_eArgError, "not an array");

    Data_Get_Struct(self,redisParentContext,pc);
    if (!pc->context)
        rb_raise(rb_eRuntimeError, "not connected");

    argc = RARRAY_LEN(command);
    argv = malloc(argc*sizeof(char*));
    alen = malloc(argc*sizeof(size_t));
    for (i = 0; i < argc; i++) {
        VALUE arg = rb_obj_as_string(RARRAY_PTR(command)[i]);
        argv[i] = RSTRING_PTR(arg);
        alen[i] = RSTRING_LEN(arg);
    }
    redisAppendCommandArgv(pc->context,argc,argv,alen);
    free(argv);
    free(alen);
    return Qnil;
}

static VALUE connection_read(VALUE self) {
    redisParentContext *pc;
    VALUE reply;
    int err;
    char errstr[1024];

    Data_Get_Struct(self,redisParentContext,pc);
    if (!pc->context)
        rb_raise(rb_eRuntimeError, "not connected");

    if (redisGetReply(pc->context,(void**)&reply) != REDIS_OK) {
        /* Copy error and free context */
        err = pc->context->err;
        snprintf(errstr,sizeof(errstr),"%s",pc->context->errstr);
        parent_context_try_free(pc);

        switch(err) {
        case REDIS_ERR_IO:
            /* Raise native Ruby I/O error */
            rb_sys_fail(0);
            break;
        case REDIS_ERR_EOF:
            /* Raise our own EOF error */
            rb_raise(error_eof,errstr);
            break;
        default:
            /* Raise something else */
            rb_raise(rb_eRuntimeError,errstr);
        }
    }
    return reply;
}

VALUE klass_connection;
VALUE error_eof;
void InitConnection(VALUE mod) {
    klass_connection = rb_define_class_under(mod, "Connection", rb_cObject);
    rb_define_alloc_func(klass_connection, connection_parent_context_alloc);
    rb_define_method(klass_connection, "connect", connection_connect, 2);
    rb_define_method(klass_connection, "connected?", connection_is_connected, 0);
    rb_define_method(klass_connection, "disconnect", connection_disconnect, 0);
    rb_define_method(klass_connection, "write", connection_write, 1);
    rb_define_method(klass_connection, "read", connection_read, 0);
    error_eof = rb_define_class_under(klass_connection, "EOFError", rb_eStandardError);
}
