#ifndef SYSCALLS_H
#define SYSCALLS_H

static inline int sys_execve(char *argv)
{
    register const char *a0 __asm__("a0") = argv;
    register int         a7 __asm__("a7") = 1;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a7)
        : "memory"
    );
    return (int)a0;
}

static inline void sys_exit(void)
{
    register int a7 __asm__("a7") = 2;
    __asm__ volatile (
        "ecall"
        :
        : "r"(a7)
    );
    __builtin_unreachable();
}

static inline long sys_write(int fd, const char *buf, int count)
{
    register int         a0 __asm__("a0") = fd;
    register const char *a1 __asm__("a1") = buf;
    register int         a2 __asm__("a2") = count;
    register int         a7 __asm__("a7") = 6;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2), "r"(a7)
        : "memory"
    );
    return a0;
}

static inline long sys_read(int fd, char *buf, int count)
{
    register int   a0 __asm__("a0") = fd;
    register char *a1 __asm__("a1") = buf;
    register int   a2 __asm__("a2") = count;
    register int   a3 __asm__("a3") = 0;
    register int   a7 __asm__("a7") = 5;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2), "r"(a3), "r"(a7)
        : "memory"
    );
    return a0;
}

static inline long sys_sd_read(char *buf, int block)
{
    register char *a0 __asm__("a0") = buf;
    register int   a1 __asm__("a1") = block;
    register int   a7 __asm__("a7") = 7;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a7)
        : "memory"
    );
    return (int)a0;
}

static inline long sys_sd_write(char *buf, int block)
{
    register char *a0 __asm__("a0") = buf;
    register int   a1 __asm__("a1") = block;
    register int   a7 __asm__("a7") = 8;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a7)
        : "memory"
    );
    return (int)a0;
}

static inline int sys_open(const char *filename, int append, int create_flag)
{
    register const char *a0 __asm__("a0") = filename;
    register int         a1 __asm__("a1") = append;
    register int         a2 __asm__("a2") = create_flag;
    register int         a7 __asm__("a7") = 3;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2), "r"(a7)
        : "memory"
    );
    return (int)a0;
}

static inline int sys_close(int fd)
{
    register int	 a0 __asm__("a0") = fd;
    register int         a7 __asm__("a7") = 4;  
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a7)
        : "memory"
    );
    return (int)a0;
}

static inline long sys_lseek(int fd, long int offset, int whence)
{
    register int   	a0 __asm__("a0") = fd;
    register long int 	a1 __asm__("a1") = offset;
    register int   	a2 __asm__("a2") = whence;
    register int   	a7 __asm__("a7") = 7;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2), "r"(a7)
        : "memory"
    );
    return a0;
}

static inline long sys_read_raw(int fd, char *buf)
{
    register int   a0 __asm__("a0") = fd;
    register char *a1 __asm__("a1") = buf;
    register int   a2 __asm__("a2") = 1;
    register int   a3 __asm__("a3") = 1;
    register int   a7 __asm__("a7") = 5;
    __asm__ volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2), "r"(a3), "r"(a7)
        : "memory"
    );
    return a0;
}

#endif
