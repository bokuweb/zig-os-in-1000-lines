#pragma once

#include "common.h"

#define READ_CSR(reg)                         \
    ({                                        \
        unsigned long __tmp;                  \
        __asm__ __volatile__("csrr %0, " #reg \
                             : "=r"(__tmp));  \
        __tmp;                                \
    })

#define WRITE_CSR(reg, value)                                   \
    do                                                          \
    {                                                           \
        uint32_t __tmp = (value);                               \
        __asm__ __volatile__("csrw " #reg ", %0" ::"r"(__tmp)); \
    } while (0)

struct sbiret
{
    long err;
    long value;
};

extern char _binary_user_bin_start[];
extern char _binary_user_bin_end[];
extern uint32_t _binary_user_bin_size;

struct sbiret sbi_call(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid);

void putchar(char ch);
long getchar(void);

unsigned int read_scause();
unsigned int read_stval();
unsigned int read_sepc();

void write_sepc(uint32_t v);

void switch_context(uint32_t *prev_sp,
                    uint32_t *next_sp);

#define PAGE_SIZE 4096
