#include <sys/socket.h>
#include <errno.h>
#include "hiredis_ext.h"

typedef struct redisParentContext {
    redisContext *context;
    struct timeval *timeout;
} redisParentContext;

static void parent_context_try_free_context(redisParentContext *pc) {
    if (pc->context) {
        redisFree(pc->context);
        pc->context = NULL;
    }
}

static void parent_context_try_free_timeout(redisParentContext *pc) {
    if (pc->timeout) {
        free(pc->timeout);
        pc->timeout = NULL;
    }
}

static void parent_context_try_free(redisParentContext *pc) {
    parent_context_try_free_context(pc);
    parent_context_try_free_timeout(pc);
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
        rb_raise(rb_eEOFError,"%s",errstr);
        break;
    default:
        /* Raise something else */
        rb_raise(rb_eRuntimeError,"%s",errstr);
    }
}

static VALUE connection_parent_context_alloc(VALUE klass) {
    redisParentContext *pc = malloc(sizeof(*pc));
    pc->context = NULL;
    pc->timeout = NULL;
    return Data_Wrap_Struct(klass, parent_context_mark, parent_context_free, pc);
}

static int __wait_readable(int fd, struct timeval *timeout, int *isset) {
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(fd, &fds);

    if (rb_thread_select(fd + 1, &fds, NULL, NULL, timeout) < 0) {
        return -1;
    }

    if (FD_ISSET(fd, &fds) && isset) {
        *isset = 1;
    }

    return 0;
}

static int __wait_writable(int fd, struct timeval *timeout, int *isset) {
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(fd, &fds);

    if (rb_thread_select(fd + 1, NULL, &fds, NULL, timeout) < 0) {
        return -1;
    }

    if (FD_ISSET(fd, &fds) && isset) {
        *isset = 1;
    }

    return 0;
}

static VALUE connection_generic_connect(VALUE self, redisContext *c, VALUE arg_timeout) {
    redisParentContext *pc;
    struct timeval tv;
    struct timeval *timeout = NULL;

    Data_Get_Struct(self,redisParentContext,pc);

    if (c->err) {
        char buf[1024];
        int err;

        /* Copy error and free context */
        err = c->err;
        snprintf(buf,sizeof(buf),"%s",c->errstr);
        redisFree(c);

        if (err == REDIS_ERR_IO) {
            /* Raise native Ruby I/O error */
            rb_sys_fail(0);
        } else {
            /* Raise something else */
            rb_raise(rb_eRuntimeError,"%s",buf);
        }
    }

    /* Default to context-wide timeout setting */
    if (pc->timeout != NULL) {
        timeout = pc->timeout;
    }

    /* Override timeout when timeout argument is available */
    if (arg_timeout != Qnil) {
        tv.tv_sec = NUM2INT(arg_timeout) / 1000000;
        tv.tv_usec = NUM2INT(arg_timeout) % 1000000;
        timeout = &tv;
    }

    /* Wait for socket to become writable */
    int writable = 0;
    if (__wait_writable(c->fd, timeout, &writable) < 0) {
        goto sys_fail;
    }

    if (!writable) {
        errno = ETIMEDOUT;
        goto sys_fail;
    }

    /* Check for socket error */
    int optval = 0;
    socklen_t optlen = sizeof(optval);
    if (getsockopt(c->fd, SOL_SOCKET, SO_ERROR, &optval, &optlen) < 0) {
        goto sys_fail;
    }

    if (optval) {
        errno = optval;
        goto sys_fail;
    }

    parent_context_try_free(pc);
    pc->context = c;
    pc->context->reader->fn = &redisExtReplyObjectFunctions;
    return Qnil;

sys_fail:
    redisFree(c);
    rb_sys_fail(0);
}

static VALUE connection_connect(int argc, VALUE *argv, VALUE self) {
    redisParentContext *pc;
    redisContext *c;
    VALUE arg_host = Qnil;
    VALUE arg_port = Qnil;
    VALUE arg_timeout = Qnil;

    if (argc == 2 || argc == 3) {
        arg_host = argv[0];
        arg_port = argv[1];

        if (argc == 3) {
            arg_timeout = argv[2];

            /* Sanity check */
            if (NUM2INT(arg_timeout) <= 0) {
                rb_raise(rb_eArgError, "timeout should be positive");
            }
        }
    } else {
        rb_raise(rb_eArgError, "invalid number of arguments");
    }

    Data_Get_Struct(self,redisParentContext,pc);
    c = redisConnectNonBlock(StringValuePtr(arg_host), NUM2INT(arg_port));
    return connection_generic_connect(self,c,arg_timeout);
}

static VALUE connection_connect_unix(int argc, VALUE *argv, VALUE self) {
    redisParentContext *pc;
    redisContext *c;
    VALUE arg_path = Qnil;
    VALUE arg_timeout = Qnil;

    if (argc == 1 || argc == 2) {
        arg_path = argv[0];

        if (argc == 2) {
            arg_timeout = argv[1];

            /* Sanity check */
            if (NUM2INT(arg_timeout) <= 0) {
                rb_raise(rb_eArgError, "timeout should be positive");
            }
        }
    } else {
        rb_raise(rb_eArgError, "invalid number of arguments");
    }

    Data_Get_Struct(self,redisParentContext,pc);
    c = redisConnectUnixNonBlock(StringValuePtr(arg_path));
    return connection_generic_connect(self,c,arg_timeout);
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
    VALUE *args;
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
    args = RARRAY_PTR(command);
    argv = malloc(argc*sizeof(char*));
    alen = malloc(argc*sizeof(size_t));
    for (i = 0; i < argc; i++) {
        /* Replace arguments in the arguments array to prevent their string
         * equivalents to be garbage collected before this loop is done. */
        args[i] = rb_obj_as_string(args[i]);
        argv[i] = RSTRING_PTR(args[i]);
        alen[i] = RSTRING_LEN(args[i]);
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
    if (redisGetReplyFromReader(c,&aux) == REDIS_ERR) {
        /* Protocol error */
        return -1;
    }

    if (aux == NULL) {
        /* Write until the write buffer is drained */
        while (!wdone) {
            errno = 0;

            if (redisBufferWrite(c, &wdone) == REDIS_ERR) {
                /* Socket error */
                return -1;
            }

            if (errno == EAGAIN) {
                int writable = 0;

                if (__wait_writable(c->fd, pc->timeout, &writable) < 0) {
                    rb_sys_fail(0);
                }

                if (!writable) {
                    errno = EAGAIN;
                    rb_sys_fail(0);
                }
            }
        }

        /* Read until there is a full reply */
        while (aux == NULL) {
            errno = 0;

            if (redisBufferRead(c) == REDIS_ERR) {
                /* Socket error */
                return -1;
            }

            if (errno == EAGAIN) {
                int readable = 0;

                if (__wait_readable(c->fd, pc->timeout, &readable) < 0) {
                    rb_sys_fail(0);
                }

                if (!readable) {
                    errno = EAGAIN;
                    rb_sys_fail(0);
                }

                /* Retry */
                continue;
            }

            if (redisGetReplyFromReader(c,&aux) == REDIS_ERR) {
                /* Protocol error */
                return -1;
            }
        }
    }

    /* Set reply object */
    if (reply != NULL) {
        *reply = (VALUE)aux;
    }

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
    struct timeval *ptr;

    Data_Get_Struct(self,redisParentContext,pc);

    /* Sanity check */
    if (NUM2INT(usecs) <= 0) {
        rb_raise(rb_eArgError, "timeout should be positive");
    }

    parent_context_try_free_timeout(pc);
    ptr = malloc(sizeof(*ptr));
    ptr->tv_sec = NUM2INT(usecs) / 1000000;
    ptr->tv_usec = NUM2INT(usecs) % 1000000;
    pc->timeout = ptr;
    return Qnil;
}


VALUE klass_connection;
void InitConnection(VALUE mod) {
    klass_connection = rb_define_class_under(mod, "Connection", rb_cObject);
    rb_define_alloc_func(klass_connection, connection_parent_context_alloc);
    rb_define_method(klass_connection, "connect", connection_connect, -1);
    rb_define_method(klass_connection, "connect_unix", connection_connect_unix, -1);
    rb_define_method(klass_connection, "connected?", connection_is_connected, 0);
    rb_define_method(klass_connection, "disconnect", connection_disconnect, 0);
    rb_define_method(klass_connection, "timeout=", connection_set_timeout, 1);
    rb_define_method(klass_connection, "write", connection_write, 1);
    rb_define_method(klass_connection, "read", connection_read, 0);
}
