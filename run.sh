#!/bin/bash
set -xue

QEMU=qemu-system-riscv32

$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait \
    -d unimp,guest_errors,int,cpu_reset -D qemu.log \
    -drive id=drive0,file=lorem.txt,format=raw \
    -device virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0 \
    -kernel zig-out/bin/kernel