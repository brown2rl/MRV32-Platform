#ifndef KERNEL_TYPES_H
#define KERNEL_TYPES_H

#define UART_TX_BUF   (*(volatile char *)(1795*4))
#define UART_TRIG  (*(volatile int  *)(1797*4))
#define UART_RX_BUF  (*(volatile int  *)(1798*4))
#define UART_1997  (*(volatile int  *)(1997*4))

#define MAX_FILENAME 32
#define MAX_FDS 16
#define MAX_FILES 8

#define FT_NONE 0
#define FT_FILE 1
#define FT_TTY  2

#define SYS_WRITE 	6
#define SYS_SD_READ	7
#define SYS_SD_WRITE	8
#define SYS_READ  	5
#define SYS_EXECVE 	1
#define SYS_EXIT  	2
#define SYS_OPEN 	3
#define SYS_CLOSE	4

typedef unsigned int    uint32_t;
typedef signed int      int32_t;
typedef unsigned short  uint16_t;
typedef signed short    int16_t;
typedef unsigned char   uint8_t;
typedef signed char     int8_t;
typedef unsigned int    size_t;
typedef signed int      ssize_t;

typedef struct {
	char        name[MAX_FILENAME];
	uint32_t    starting_addr;
	uint32_t    size;
	uint8_t     used;
} directory_entry_t;

typedef struct file_object {
	uint32_t        position;
	int             type;
	directory_entry_t *entry;
} file_t;

typedef struct {
	file_t *number[MAX_FDS];
} fd_table;

typedef struct {
    uint32_t regs[32];
    uint32_t pc;
} context_t;


#endif
