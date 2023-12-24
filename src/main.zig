const std = @import("std");
const Synth = @import("synth.zig");
const Commands = @import("commands.zig");
const Keyscan = @import("keyscan.zig");
const Notemap = @import("notemap.zig");
const Midinotes = @import("midinotes.zig");

const Opt = struct {
    record: bool,
    sf2_file: []const u8,
    prog_number: i32,
    notemap_file: []const u8,
};

const Mode = enum {
    Play,
    Control,
};

fn shutdown() noreturn {
    std.debug.print("Bye...\n", .{});
    std.process.exit(0);
}

fn beep(synth: *Synth, note: i32, vol: i32) !void {
    const MIDI_CC_VOLUME: i32 = 7;
    synth.noteOn(0, note, vol);
    synth.cc(0, MIDI_CC_VOLUME, vol);
    std.time.sleep(std.time.ns_per_ms * 100);
    synth.noteOff(0, vol);
}

const TICK_uSECS: u32 = 2_000;
const GPIO_UART_RXD: u8 = 15;
const GPIO_UART_TXD: u8 = 14;

pub fn main() !void {
    var s = try Synth.init("./FluidR3_GM.sf2", 1);
    defer s.deinit();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    std.debug.print("Starting Haxophone\n", .{});

    var synth = try Synth.init(".sf2", 0);
    defer synth.deinit();

    var ks = try Keyscan.init();
    defer ks.gpio.deinit();

    var nm = try Notemap.NoteMap.init("notemap.json", alloc);

    var last_note: i32 = 0;
    var mode = Mode.Play;
    var cmd = Commands.Command.init(&synth, 0);
    while (true) {
        std.time.sleep(TICK_uSECS * std.time.ns_per_us);

        var keys = try ks.scan();
        var vol: i32 = 50;
        const MIDI_CC_VOLUME: i32 = 7;
        synth.cc(0, MIDI_CC_VOLUME, vol);

        if (mode == .Control) {
            cmd.process(keys);

            // All three left hand palm keys pressed at once
            if (keys == 0x124) {
                beep(&synth, 70, 50);
                mode = .Play;
            }
            continue;
        }

        if (try nm.get(&keys)) |note| {
            if (last_note != note) {
                std.debug.print("Note: {} Pressure: N/A Key {b:032}: {}\n", .{
                    Midinotes.getName(note) orelse "Unknown?",
                    keys,
                    keys,
                });
                if (vol > 0) {
                    if (last_note > 0) {
                        synth.cc(0, MIDI_CC_VOLUME, 0);
                        synth.noteOff(0, last_note);
                        synth.cc(0, MIDI_CC_VOLUME, vol);
                    }
                    synth.noteOn(0, note, 127);
                    last_note = note;
                    std.debug.print("last_note changed to {}\n", .{last_note});
                }
            }
            if (vol <= 0 and last_note > 0) {
                synth.noteOff(0, last_note);
                last_note = 0;
            }

            //todo: pressure stuff

        }
    }
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
