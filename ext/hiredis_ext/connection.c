#include <sys/socket.h>
#include <errno.h>
#include "hiredis_ext.h"

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

static void parent_context_raise(redisParentContext *pc) {
    int err;
    char errstr[1024];

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
        rb_raise(error_eof,"%s",errstr);
        break;
    default:
        /* Raise something else */
        rb_raise(rb_eRuntimeError,"%s",errstr);
    }
}

static VALUE connection_parent_context_alloc(VALUE klass) {
    redisParentContext *pc = malloc(sizeof(*pc));
    pc->context = NULL;
    return Data_Wrap_Struct(klass, parent_context_mark, parent_context_free, pc);
}

static VALUE connection_generic_connect(VALUE self, redisContext *c) {
    redisParentContext *pc;
    int err;
    char errstr[1024];

    Data_Get_Struct(self,redisParentContext,pc);

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
            rb_raise(rb_eRuntimeError,"%s",errstr);
        }
    }

    redisSetReplyObjectFunctions(c,&redisExtReplyObjectFunctions);
    pc->context = c;
    return Qnil;
}

static VALUE connection_connect(VALUE self, VALUE _host, VALUE _port) {
    redisParentContext *pc;
    redisContext *c;
    char *host = StringValuePtr(_host);
    int port = NUM2INT(_port);

    Data_Get_Struct(self,redisParentContext,pc);
    parent_context_try_free(pc);

    c = redisConnect(host,port);
    return connection_generic_connect(self,c);
}

static VALUE connection_connect_unix(VALUE self, VALUE _path) {
    redisParentContext *pc;
    redisContext *c;
    char *path = StringValuePtr(_path);

    Data_Get_Struct(self,redisParentContext,pc);
    parent_context_try_free(pc);

    c = redisConnectUnix(path);
    return connection_generic_connect(self,c);
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
        rb_raise(rb_eRuntimeError,"%s","not connected");
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
        rb_raise(rb_eArgError,"%s","not an array");

    Data_Get_Struct(self,redisParentContext,pc);
    if (!pc->context)
        rb_raise(rb_eRuntimeError,"%s","not connected");

    argc = (int)RARRAY_LEN(command);
    argv = malloc(argc*sizeof(char*));
    alen = malloc(argc*sizeof(size_t));
    for (i = 0; i < argc; i++) {
        VALUE arg = rb_obj_as_string(RARRAY_PTR(command)[i]);
        argv[i] = RSTRING_PTR(arg);
        alen[i] = RSTRING_LEN(arg);
    }
    redisAppendCommandArgv(pc->context,argc,(const char**)argv,alen);
    free(argv);
    free(alen);
    return Qnil;
}

static int __get_reply(redisParentContext *pc, VALUE *reply) {
    redisContext *c = pc->context;
    int wdone = 0;
    void *aux = NULL;

    /* Try to read pending replies */
    if (redisGetReplyFromReader(c,&aux) == REDIS_ERR)
        return -1;

    if (aux == NULL) {
        do { /* Write until done */
            if (redisBufferWrite(c,&wdone) == REDIS_ERR)
                return -1;
        } while (!wdone);
        do { /* Read until there is a reply */
            rb_thread_wait_fd(c->fd);
            if (redisBufferRead(c) == REDIS_ERR)
                return -1;
            if (redisGetReplyFromReader(c,&aux) == REDIS_ERR)
                return -1;
        } while (aux == NULL);
    }

    /* Set reply object */
    if (reply != NULL) *reply = (VALUE)aux;
    return 0;
}

static VALUE connection_read(VALUE self) {
    redisParentContext *pc;
    VALUE reply;

    Data_Get_Struct(self,redisParentContext,pc);
    if (!pc->context)
        rb_raise(rb_eRuntimeError, "not connected");

    if (__get_reply(pc,&reply) == -1)
        parent_context_raise(pc);

    return reply;
}

static VALUE connection_set_timeout(VALUE self, VALUE usecs) {
    redisParentContext *pc;
    int s = NUM2INT(usecs)/1000000;
    int us = NUM2INT(usecs)-(s*1000000);
    struct timeval timeout = { s, us };

    Data_Get_Struct(self,redisParentContext,pc);
    if (!pc->context)
        rb_raise(rb_eRuntimeError, "not connected");

    if (redisSetTimeout(pc->context,timeout) == REDIS_ERR)
        parent_context_raise(pc);

    return usecs;
}


VALUE klass_connection;
VALUE error_eof;
void InitConnection(VALUE mod) {
    klass_connection = rb_define_class_under(mod, "Connection", rb_cObject);
    rb_define_alloc_func(klass_connection, connection_parent_context_alloc);
    rb_define_method(klass_connection, "connect", connection_connect, 2);
    rb_define_method(klass_connection, "connect_unix", connection_connect_unix, 1);
    rb_define_method(klass_connection, "connected?", connection_is_connected, 0);
    rb_define_method(klass_connection, "disconnect", connection_disconnect, 0);
    rb_define_method(klass_connection, "timeout=", connection_set_timeout, 1);
    rb_define_method(klass_connection, "write", connection_write, 1);
    rb_define_method(klass_connection, "read", connection_read, 0);
    error_eof = rb_define_class_under(klass_connection, "EOFError", rb_eStandardError);
}
