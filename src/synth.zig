const std = @import("std");
const C = @cImport(@cInclude("fluidsynth.h"));
const AudioConfig = @import("audio");

synth: *C.struct__fluid_synth_t,
settings: *C.struct__fluid_hashtable_t,
driver: *C.fluid_audio_driver_t,

const Self = @This();

pub fn init(sf2File: []const u8, bank: i32) !Self {
    var settings = if (C.new_fluid_settings()) |s| s else return error.FailedToCreateSettings;

    if (C.fluid_settings_setstr(settings, "audio.driver", AudioConfig.audio_driver.ptr) == C.FLUID_FAILED) return error.Settings;
    if (C.fluid_settings_setint(settings, "audio.periods", 3) == C.FLUID_FAILED) return error.Settings;
    if (C.fluid_settings_setint(settings, "audio.period-size", 64) == C.FLUID_FAILED) return error.Settings;
    if (C.fluid_settings_setint(settings, "audio.realtime-prio", 99) == C.FLUID_FAILED) return error.Settings;

    var syn = if (C.new_fluid_synth(settings)) |s| s else return error.FailedToCreateSynth;
    C.fluid_synth_set_gain(syn, 1.0);

    var adriver = if (C.new_fluid_audio_driver(settings, syn)) |d| d else return error.FailedToLoadDriver;

    if (C.fluid_is_soundfont(sf2File.ptr) == 1) {
        if (C.fluid_synth_sfload(syn, sf2File.ptr, 1) == C.FLUID_FAILED)
            return error.SoundFont;
    }
    if (C.fluid_synth_set_polyphony(syn, 16) == C.FLUID_FAILED)
        return error.Polyphony;
    if (C.fluid_synth_program_change(syn, 0, 0) == C.FLUID_FAILED)
        return error.ProgramChange;

    var player = if (C.new_fluid_player(syn)) |p| p else return error.FailedToCreatePlayer;
    defer C.delete_fluid_player(player);

    const midiFile = "./midi/startup/Startup_Haxophone.mid";
    if (C.fluid_is_midifile(midiFile) == 1)
        _ = C.fluid_player_add(player, midiFile)
    else
        std.debug.print("Invalid midifile: {s}\n", .{midiFile});
    if (C.fluid_player_play(player) == C.FLUID_FAILED)
        return error.Player;

    _ = C.fluid_player_join(player);

    if (C.fluid_synth_set_polyphony(syn, 1) == C.FLUID_FAILED)
        return error.Polyphony;
    if (C.fluid_synth_program_change(syn, 0, bank) == C.FLUID_FAILED)
        return error.ProgramChange;

    return .{
        .synth = syn,
        .settings = settings,
        .driver = adriver,
    };
}

pub fn deinit(self: *Self) void {
    C.delete_fluid_audio_driver(self.driver);
    C.delete_fluid_synth(self.synth);
    C.delete_fluid_settings(self.settings);
}

pub fn programChange(self: *Self, channel: i32, program: i32) void {
    _ = C.fluid_synth_program_change(self.synth, channel, program);
}

pub fn noteOn(self: *Self, channel: i32, key: i32, vel: i32) void {
    _ = C.fluid_synth_noteon(self.synth, channel, key, vel);
}

pub fn cc(self: *Self, channel: i32, number: i32, value: i32) void {
    _ = C.fluid_synth_cc(self.synth, channel, number, value);
}

pub fn noteOff(self: *Self, channel: i32, key: i32) void {
    _ = C.fluid_synth_noteoff(self.synth, channel, key);
}

test "synth" {
    var d = try init("FluidR3_GM.sf2", 1);
    defer d.deinit();
}
