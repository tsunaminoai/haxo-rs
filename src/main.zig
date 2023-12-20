const std = @import("std");
const synth = @import("synth.zig");

pub fn main() !void {
    var s = try synth.init("./FluidR3_GM.sf2", 1);
    defer s.deinit();
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
