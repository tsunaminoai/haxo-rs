const std = @import("std");

const ADDR_PRESSURE_SENSOR: u16 = 0x4D;

pub const Pressure = struct {
    i2c,
    baseline: i32,
};
