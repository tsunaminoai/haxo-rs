const std = @import("std");
const testing = std.testing;
const Synth = @import("synth.zig");

pub const CommandKeys = enum(u32) {
    ChangeProgUp = 0x10000,
    ChangeProgFastUp = 0x90000,
    ChangeProgDown = 0x400000,
    ChangeProgFastDown = 0x480000,

    pub fn key2cmdKey(key: u32) CommandKeys {
        return @enumFromInt(key);
    }
};

const MIDI_CC_VOLUME: i31 = 7;

pub const Command = struct {
    synth: Synth,
    prog_number: i32,
    last_cmd_key: CommandKeys,

    pub fn init(synth: Synth, progNumber: i32) Command {
        return .{
            .synth = synth,
            .prog_number = progNumber,
            .last_cmd_key = 0,
        };
    }

    pub fn process(self: *Command, key: u32) void {
        const cmd_key = CommandKeys.key2cmdKey(key);
        if (cmd_key == self.last_cmd_key) {
            return;
        }
        switch (cmd_key) {
            .ChangeProgUp => self.change_program(1),
            .ChangeProgFastUp => self.change_program(10),
            .ChangeProgDown => self.change_program(-1),
            .ChangeProgFastDown => self.change_program(-11),
        }
    }

    fn change_program(self: *Command, change: i32) void {
        self.prog_number = @max(0, @min(127, self.prog_number + change));
        self.synth.programChange(0, self.prog_number);
        std.log.info("New MIDI program number {}", .{self.prog_number});
        self.synth.noteOn(0, 53, 60);
        self.synth.cc(0, MIDI_CC_VOLUME, 60);
        // std.Thread.
        self.synth.noteOff(0, 53);
    }
};

test "command keys" {
    try testing.expectEqual(CommandKeys.key2cmdKey(0x10000), .ChangeProgUp);
}
