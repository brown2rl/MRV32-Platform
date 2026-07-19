#include "kernel_types.h"

extern context_t ctx;
extern ssize_t syswrite( int fd, const char *buf, int size);
extern ssize_t sysread(int fd, char *buf, int count, int raw_flag);
extern ssize_t sys_sd_read(char *arg0, int arg1);
extern ssize_t sys_sd_write(char *arg0, int arg1);
extern int sysexecve(char *argv);
extern ssize_t sysexit();
extern ssize_t sysopen(const char *filename, int append, int create_flag);
extern ssize_t sysclose(int fd);


void sys_dispatch(context_t *ctx) {
    int nr = ctx->regs[17];

    uint32_t arg0 = ctx->regs[10];
    uint32_t arg1 = ctx->regs[11];
    uint32_t arg2 = ctx->regs[12];
    uint32_t arg3 = ctx->regs[13];

    int ret;

    switch (nr) {
        case SYS_WRITE:
            ret = syswrite( arg0, (char *)arg1, arg2);
            break;
        case SYS_READ:
            ret = sysread( arg0, (char *)arg1, arg2, arg3);
            break;
        case SYS_SD_READ:
            ret = sys_sd_read((char *)arg0, arg1);
            break;
        case SYS_SD_WRITE:
            ret = sys_sd_write((char *)arg0, arg1);
            break;
        case SYS_EXECVE:
            ret = sysexecve((char *)arg0);
            break;
        case SYS_EXIT:
            sysexit();
            break;
        case SYS_OPEN:
            ret = sysopen((char *)arg0, arg1, arg2);
            break;
        case SYS_CLOSE:
            ret = sysclose( arg0);
            break;        
        default:
            ret = -1;
    }

    ctx->regs[10] = ret;

    ctx->pc += 4;
}

