#include "user.h"

int __attribute__((section(".user"))) syscall(int sysno, int arg0, int arg1, int arg2)
{
  register int a0 __asm__("a0") = arg0;
  register int a1 __asm__("a1") = arg1;
  register int a2 __asm__("a2") = arg2;
  register int a3 __asm__("a3") = sysno;

  __asm__ __volatile__("ecall"
                       : "=r"(a0)
                       : "r"(a0), "r"(a1), "r"(a2), "r"(a3)
                       : "memory");

  return a0;
}

void __attribute__((section(".user"))) putchar(char ch)
{
  syscall(SYS_PUTCHAR, ch, 0, 0);
}

int __attribute__((section(".user"))) getchar(void)
{
  return syscall(SYS_GETCHAR, 0, 0, 0);
}

__attribute__((noreturn, section(".user"))) void exit(void)
{
  syscall(SYS_EXIT, 0, 0, 0);
  for (;;)
    ;
}