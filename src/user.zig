const std = @import("std");

extern const __stack_top: *u8;

const c = @cImport({
    @cInclude("user.h");
});

pub export fn start() callconv(.Naked) void {
    _ = asm volatile (
        \\ mv sp, %[stack_top]
        \\ call main
        \\ call exit
        :
        : [stack_top] "r" (&__stack_top),
    );
}

pub export fn main() noreturn {
    var cmdline: [128]u8 = undefined;

    while (true) {
        c.printf("> ");
        var i: usize = 0;
        prompt: {
            while (true) {
                const ch: u8 = @intCast(c.getchar());
                c.putchar(ch);
                if (i == cmdline.len - 1) {
                    c.printf("command line too long\n", .{});
                    break :prompt;
                } else if (ch == '\r') {
                    c.printf("\n");
                    cmdline[i] = 0;
                    break;
                } else {
                    cmdline[i] = ch;
                }
                i += 1;
            }
        }

        if (std.mem.eql(u8, "hello", cmdline[0..i])) {
            c.printf("Hello world from shell!\n");
        } else if (std.mem.eql(u8, "exit", cmdline[0..i])) {
            c.exit();
        } else {
            c.printf("unknown command: %s\n");
        }
    }
}
