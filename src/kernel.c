
#include "kernel.h"

struct sbiret __attribute__((section(".kernel"))) sbi_call(long arg0, long arg1, long arg2, long arg3, long arg4,
                                                           long arg5, long fid, long eid)
{
    register long a0 __asm__("a0") = arg0;
    register long a1 __asm__("a1") = arg1;
    register long a2 __asm__("a2") = arg2;
    register long a3 __asm__("a3") = arg3;
    register long a4 __asm__("a4") = arg4;
    register long a5 __asm__("a5") = arg5;
    register long a6 __asm__("a6") = fid;
    register long a7 __asm__("a7") = eid;

    __asm__ __volatile__("ecall"
                         : "=r"(a0), "=r"(a1)
                         : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5),
                           "r"(a6), "r"(a7)
                         : "memory");
    return (struct sbiret){.err = a0, .value = a1};
}

void __attribute__((section(".kernel"))) putchar(char ch)
{
    sbi_call(ch, 0, 0, 0, 0, 0, 0, 1);
}

long __attribute__((section(".kernel"))) getchar(void)
{
    struct sbiret ret = sbi_call(0, 0, 0, 0, 0, 0, 0, 2);
    return ret.err;
}

unsigned int __attribute__((section(".kernel"))) read_scause()
{
    return READ_CSR(scause);
}

unsigned int __attribute__((section(".kernel"))) read_stval()
{
    return READ_CSR(stval);
}

unsigned int __attribute__((section(".kernel"))) read_sepc()
{
    return READ_CSR(sepc);
}

void __attribute__((section(".kernel"))) write_sepc(uint32_t v)
{
    WRITE_CSR(sepc, v);
}

__attribute__((naked, section(".kernel"))) void switch_context(uint32_t *prev_sp,
                                                               uint32_t *next_sp)
{
    __asm__ __volatile__(
        "addi sp, sp, -13 * 4\n"
        "sw ra,  0  * 4(sp)\n"
        "sw s0,  1  * 4(sp)\n"
        "sw s1,  2  * 4(sp)\n"
        "sw s2,  3  * 4(sp)\n"
        "sw s3,  4  * 4(sp)\n"
        "sw s4,  5  * 4(sp)\n"
        "sw s5,  6  * 4(sp)\n"
        "sw s6,  7  * 4(sp)\n"
        "sw s7,  8  * 4(sp)\n"
        "sw s8,  9  * 4(sp)\n"
        "sw s9,  10 * 4(sp)\n"
        "sw s10, 11 * 4(sp)\n"
        "sw s11, 12 * 4(sp)\n"
        "sw sp, (a0)\n"
        "lw sp, (a1)\n"
        "lw ra,  0  * 4(sp)\n"
        "lw s0,  1  * 4(sp)\n"
        "lw s1,  2  * 4(sp)\n"
        "lw s2,  3  * 4(sp)\n"
        "lw s3,  4  * 4(sp)\n"
        "lw s4,  5  * 4(sp)\n"
        "lw s5,  6  * 4(sp)\n"
        "lw s6,  7  * 4(sp)\n"
        "lw s7,  8  * 4(sp)\n"
        "lw s8,  9  * 4(sp)\n"
        "lw s9,  10 * 4(sp)\n"
        "lw s10, 11 * 4(sp)\n"
        "lw s11, 12 * 4(sp)\n"
        "addi sp, sp, 13 * 4\n"
        "ret\n");
}
