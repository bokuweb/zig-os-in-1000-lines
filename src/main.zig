const std = @import("std");

const c = @cImport({
    @cInclude("kernel.h");
});

extern const __bss: *u8;
extern const __bss_end: *u8;
extern const __stack_top: *u8;
extern const __free_ram: *u8;
extern const __free_ram_end: *u8;
extern const __kernel_base: *u8;

const SATP_SV32 = 1 << 31;
const PAGE_V = 1 << 0;
const PAGE_R = 1 << 1;
const PAGE_W = 1 << 2;
const PAGE_X = 1 << 3;
const PAGE_U = 1 << 4;

const SSTATUS_SPIE = (1 << 5);

const SCAUSE_ECALL = 8;

const paddr_t = u32;
const vaddr_t = u32;
const size_t = u32;

const PAGE_SIZE: u32 = 4096;

const USER_BASE = 0x100_0000;

const PROCS_MAX = 8;
const PROC_UNUSED = 0;
const PROC_RUNNABLE = 1;
const PROC_EXITED = 2;

const STACK_LEN = 2038;

// process
const Process = struct {
    pid: i32,
    state: i32,
    sp: vaddr_t,
    page_table: *u32,
    stack: [STACK_LEN]u32,
};

var procs: [PROCS_MAX]Process = undefined;

pub fn create_process(image: ?*u8, image_size: u32) ?*Process {
    var proc: ?*Process = null;
    var i: usize = 0;
    while (i < PROCS_MAX) {
        if (procs[i].state == PROC_UNUSED) {
            proc = &procs[i];
            break;
        }
        i += 1;
    }

    if (proc == null) {
        _panic("no free process slots");
    }

    var sp: *u32 = &proc.?.stack[STACK_LEN - 1];

    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s11
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s10
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s9
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s8
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s7
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s6
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s5
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s4
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s3
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s2
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s1
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = 0; // s0
    sp = @ptrFromInt(@intFromPtr(sp) - 4);
    sp.* = @intFromPtr(&user_entry);

    var page_table = alloc_pages(1);

    var paddr: u32 = @intCast(@intFromPtr(&__kernel_base));
    const end: u32 = @as(u32, @intCast(@intFromPtr(&__free_ram_end)));
    while (paddr < end) {
        map_page(@as([*]u32, @ptrFromInt(page_table)), paddr, paddr, PAGE_R | PAGE_W | PAGE_X);
        paddr += PAGE_SIZE;
    }

    const p: u32 = @intFromPtr(image);

    var off: u32 = 0;
    while (off < image_size) {
        const page = alloc_pages(1);
        _ = memcpy(@ptrFromInt(page), @ptrFromInt(p + off), PAGE_SIZE);
        map_page(@as([*]u32, @ptrFromInt(page_table)), USER_BASE + off, page, PAGE_U | PAGE_R | PAGE_W | PAGE_X);
        off += PAGE_SIZE;
    }

    const pid: i32 = @as(i32, @intCast(i)) + 1;
    if (image == null) {
        proc.?.pid = -1;
    } else {
        proc.?.pid = pid;
    }

    proc.?.state = PROC_RUNNABLE;
    proc.?.sp = @as(vaddr_t, @intFromPtr(sp));
    proc.?.page_table = @ptrFromInt(page_table);
    return proc;
}

var current_proc: ?*Process = null;
var idle_proc: ?*Process = null;

fn yield() void {
    var next: ?*Process = idle_proc;
    var i: usize = 0;
    var index: usize = 0;
    while (true) {
        if (i >= PROCS_MAX) {
            break;
        }

        if (current_proc.?.pid == -1) {
            index = i;
        } else {
            const pid: usize = @intCast(current_proc.?.pid);
            index = (pid + i) % PROCS_MAX;
        }

        const proc = &procs[index];
        if (proc.state == PROC_RUNNABLE and proc.pid > 0) {
            next = proc;
            break;
        }
        i += 1;
    }

    if (next == current_proc) {
        return;
    }

    const prev = current_proc;
    current_proc = next;

    _ = asm volatile (
        \\ sfence.vma
        \\ csrw satp, %[satp]
        \\ sfence.vma
        \\ csrw sscratch, %[sscratch]
        :
        : [satp] "r" (SATP_SV32 | (@intFromPtr(next.?.page_table) / PAGE_SIZE)),
          [sscratch] "r" (&next.?.stack[STACK_LEN - 1]),
    );

    c.switch_context(&prev.?.sp, &next.?.sp);
}

var next_paddr: paddr_t = 0;

pub fn alloc_pages(n: u32) paddr_t {
    if (next_paddr == 0) {
        next_paddr = @intFromPtr(&__free_ram);
    }
    const paddr = next_paddr;
    next_paddr += n * PAGE_SIZE;

    const free_end: paddr_t = @intFromPtr(&__free_ram_end);

    if (next_paddr > free_end) {
        _panic("out of memory");
    }

    _ = memset(@ptrFromInt(paddr), 0, n * PAGE_SIZE);
    return paddr;
}

pub fn memset(buf: *u8, b: u8, n: size_t) *u8 {
    var p = buf;
    var count = n;
    while (count > 0) : (count -= 1) {
        p.* = b;
        p = @ptrFromInt(@intFromPtr(p) + 1);
    }
    return buf;
}

pub fn memcpy(dst: *u8, src: *const u8, n: size_t) *u8 {
    var d = dst;
    var s = src;
    var count = n;
    while (count > 0) : (count -= 1) {
        d.* = s.*;
        d = @ptrFromInt(@intFromPtr(d) + 1);
        s = @ptrFromInt(@intFromPtr(s) + 1);
    }

    return dst;
}

pub fn _panic(fmt: [*c]const u8) noreturn {
    const src = @src();
    const file = src.file;
    c.printf("PANIC: %s %s %d", fmt, @as([*c]const u8, file), src.line);
    while (true) {}
}

pub export fn boot() callconv(.Naked) void {
    _ = asm volatile (
        \\ mv sp, %[stack_top]
        \\ j kernel_main
        :
        : [stack_top] "r" (&__stack_top),
    );
}

pub export fn user_entry() callconv(.Naked) void {
    _ = asm volatile (
        \\ csrw sepc, %[sepc]
        \\ csrw sstatus, %[sstatus]
        \\ sret
        :
        : [sepc] "r" (USER_BASE),
          [sstatus] "r" (SSTATUS_SPIE),
    );
}

pub fn kernel_entry() align(4) callconv(.Naked) void {
    asm volatile (
        \\ csrrw sp, sscratch, sp
        \\ addi sp, sp, -4 * 31
        \\ sw ra,  4 * 0(sp)
        \\ sw gp,  4 * 1(sp)
        \\ sw tp,  4 * 2(sp)
        \\ sw t0,  4 * 3(sp)
        \\ sw t1,  4 * 4(sp)
        \\ sw t2,  4 * 5(sp)
        \\ sw t3,  4 * 6(sp)
        \\ sw t4,  4 * 7(sp)
        \\ sw t5,  4 * 8(sp)
        \\ sw t6,  4 * 9(sp)
        \\ sw a0,  4 * 10(sp)
        \\ sw a1,  4 * 11(sp)
        \\ sw a2,  4 * 12(sp)
        \\ sw a3,  4 * 13(sp)
        \\ sw a4,  4 * 14(sp)
        \\ sw a5,  4 * 15(sp)
        \\ sw a6,  4 * 16(sp)
        \\ sw a7,  4 * 17(sp)
        \\ sw s0,  4 * 18(sp)
        \\ sw s1,  4 * 19(sp)
        \\ sw s2,  4 * 20(sp)
        \\ sw s3,  4 * 21(sp)
        \\ sw s4,  4 * 22(sp)
        \\ sw s5,  4 * 23(sp)
        \\ sw s6,  4 * 24(sp)
        \\ sw s7,  4 * 25(sp)
        \\ sw s8,  4 * 26(sp)
        \\ sw s9,  4 * 27(sp)
        \\ sw s10, 4 * 28(sp)
        \\ sw s11, 4 * 29(sp)
        \\ csrr a0, sscratch
        \\ sw a0,  4 * 30(sp)
        \\ addi a0, sp, 4 * 31
        \\ csrw sscratch, a0
        \\ mv a0, sp
        \\ call handle_trap
        \\ lw ra,  4 * 0(sp)
        \\ lw gp,  4 * 1(sp)
        \\ lw tp,  4 * 2(sp)
        \\ lw t0,  4 * 3(sp)
        \\ lw t1,  4 * 4(sp)
        \\ lw t2,  4 * 5(sp)
        \\ lw t3,  4 * 6(sp)
        \\ lw t4,  4 * 7(sp)
        \\ lw t5,  4 * 8(sp)
        \\ lw t6,  4 * 9(sp)
        \\ lw a0,  4 * 10(sp)
        \\ lw a1,  4 * 11(sp)
        \\ lw a2,  4 * 12(sp)
        \\ lw a3,  4 * 13(sp)
        \\ lw a4,  4 * 14(sp)
        \\ lw a5,  4 * 15(sp)
        \\ lw a6,  4 * 16(sp)
        \\ lw a7,  4 * 17(sp)
        \\ lw s0,  4 * 18(sp)
        \\ lw s1,  4 * 19(sp)
        \\ lw s2,  4 * 20(sp)
        \\ lw s3,  4 * 21(sp)
        \\ lw s4,  4 * 22(sp)
        \\ lw s5,  4 * 23(sp)
        \\ lw s6,  4 * 24(sp)
        \\ lw s7,  4 * 25(sp)
        \\ lw s8,  4 * 26(sp)
        \\ lw s9,  4 * 27(sp)
        \\ lw s10, 4 * 28(sp)
        \\ lw s11, 4 * 29(sp)
        \\ lw sp,  4 * 30(sp)
        \\ sret
    );
}

fn write_stvec(value: u32) void {
    _ = asm volatile (
        \\ csrw stvec, %[value]
        :
        : [value] "r" (value),
    );
}

const trap_frame = packed struct {
    ra: u32,
    gp: u32,
    tp: u32,
    t0: u32,
    t1: u32,
    t2: u32,
    t3: u32,
    t4: u32,
    t5: u32,
    t6: u32,
    a0: u32,
    a1: u32,
    a2: u32,
    a3: u32,
    a4: u32,
    a5: u32,
    a6: u32,
    a7: u32,
    s0: u32,
    s1: u32,
    s2: u32,
    s3: u32,
    s4: u32,
    s5: u32,
    s6: u32,
    s7: u32,
    s8: u32,
    s9: u32,
    s10: u32,
    s11: u32,
    sp: u32,
};

fn handle_syscall(f: *trap_frame) void {
    switch (f.a3) {
        c.SYS_PUTCHAR => {
            const ch: u8 = @intCast(f.a0);
            _ = c.putchar(ch);
        },
        c.SYS_GETCHAR => {
            while (true) {
                const ch = c.getchar();
                if (ch >= 0) {
                    f.a0 = @intCast(ch);
                    break;
                }
                yield();
            }
        },
        c.SYS_EXIT => {
            c.printf("process exited\n");
            current_proc.?.state = PROC_EXITED;
            yield();
            _panic("unreachable");
        },
        else => {
            _panic("unexpected syscall");
        },
    }
}

pub export fn handle_trap(f: *trap_frame) void {
    const scause = c.read_scause();
    const stval = c.read_stval();
    _ = stval;
    var user_pc = c.read_sepc();

    if (scause == SCAUSE_ECALL) {
        handle_syscall(f);
        user_pc += 4;
    } else {
        _panic("unexpected trap\n");
    }
    c.write_sepc(user_pc);
}

fn is_aligned(addr: u32, a: u32) bool {
    return addr & (a - 1) == 0;
}

fn map_page(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) void {
    if (!is_aligned(vaddr, PAGE_SIZE)) {
        _panic("unaligned vaddr");
    }

    if (!is_aligned(paddr, PAGE_SIZE)) {
        _panic("unaligned paddr");
    }

    const vpn1 = (vaddr >> 22) & 0x3ff;
    if ((table1[vpn1] & PAGE_V) == 0) {
        const pt_paddr = alloc_pages(1);
        table1[vpn1] = ((pt_paddr / PAGE_SIZE) << 10) | PAGE_V;
    }

    const vpn0 = (vaddr >> 12) & 0x3ff;
    const table0 = @as([*]u32, @ptrFromInt((table1[vpn1] >> 10) * PAGE_SIZE));
    table0[vpn0] = ((paddr / PAGE_SIZE) << 10) | flags | PAGE_V;
}

pub export fn kernel_main() void {
    const p: u32 = @intFromPtr(&kernel_entry);
    write_stvec(p);

    idle_proc = create_process(null, 0);
    current_proc = idle_proc;

    const size: u32 = @intFromPtr(c._binary_user_bin_end) - @intFromPtr(c._binary_user_bin_start);
    _ = create_process(c._binary_user_bin_start, size);
    yield();
    _panic("switched to idle process");
}
