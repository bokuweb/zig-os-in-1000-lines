#pragma once

#define va_list __builtin_va_list
#define va_start __builtin_va_start
#define va_end __builtin_va_end
#define va_arg __builtin_va_arg

#define SYS_PUTCHAR 1
#define SYS_GETCHAR 2
#define SYS_EXIT    3

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef uint32_t size_t;
typedef uint32_t paddr_t;
typedef uint32_t vaddr_t;

#define true 1
#define false 0

void printf(const char *fmt, ...);

int __attribute__((section(".common"))) syscall(int sysno, int arg0, int arg1, int arg2);
