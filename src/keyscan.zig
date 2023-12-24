const std = @import("std");
const GPIO = @import("zigpio");

const ROWS = &.{ 13, 12, 16, 17, 20, 22, 24 };
const COLS = &.{ 25, 26, 27 };

const ROW_PULL_DOWN_TIME_US: u64 = 10;

const Self = @This();

mapper: *GPIO.bcm2835.Bcm2385GpioMemoryMapper,

gpio: GPIO = undefined,

pub fn init() !Self {
    var mapper = try GPIO.bcm2835.Bcm2385GpioMemoryMapper.init();

    try GPIO.init(&mapper);

    for (COLS) |c| {
        GPIO.setMode(c, .Input);
    }
    for (ROWS) |r| {
        GPIO.setMode(r, .Output);
        GPIO.setLevel(r, .High);
    }
    return .{
        .gpio = &GPIO,
    };
}

fn get_bit_at(input: u32, n: u8) bool {
    if (n < 32) {
        input & (1 << n) != 0;
    } else {
        false;
    }
}

fn set_bit_at(output: *u32, n: u8) void {
    if (n < 32) {
        output.* |= 1 << n;
    }
}

fn clear_bit_at(output: *u32, n: u8) void {
    if (n < 32) {
        output.* &= !(1 << n);
    }
}

pub fn scan(self: *Self) !void {
    var key_idx: u8 = 0;
    var keymap: u32 = 0;
    for (ROWS) |r| {
        try self.gpio.setLevel(r, .Low);
        std.time.sleep(ROW_PULL_DOWN_TIME_US);

        for (COLS) |c| {
            const is_pressed = try self.gpio.getLevel(c) == .Low;

            if (get_bit_at(keymap, key_idx) != is_pressed) {
                if (is_pressed)
                    self.set_bit_at(&keymap, key_idx)
                else
                    clear_bit_at(&keymap, key_idx);
            }
            key_idx += 1;
        }
        try self.gpio.setLevel(r, .High);
    }
}

pub fn debug_print(self: *Self, keys: u32) void {
    std.debug.print("\n", .{});
    for (COLS) |_| {
        std.debug.print("==", .{});
    }
    std.debug.print("\n", .{});
    for (COLS, 0..) |_, i|
        std.debug.print("{} ", .{i});

    std.debug.print("\n", .{});
    for (COLS) |_| {
        std.debug.print("==", .{});
    }
    std.debug.print("\n", .{});
    for (ROWS, 0..) |_, i| {
        for (COLS, 0..) |_, j| {
            if (j == 0)
                std.debug.print("{} ", .{i});
            var key = self.get_bit_at(keys, i * COLS.len + j);
            std.debug.print("{c} ", .{if (key) 'x' else 'o'});
        }
        std.debug.print("{} ", .{i});
    }
}
