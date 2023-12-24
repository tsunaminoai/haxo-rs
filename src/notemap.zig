const std = @import("std");

usingnamespace @import("midinotes.zig");

const JLine = struct {
    key: i32,
};
pub const NoteMap = struct {
    recording: bool,
    recoding_index: usize,
    last_keys: u32,
    last_recorded: u32,
    record_next: bool,
    filename: []const u8,
    notemap: std.json.Parsed(std.json.Value),
    alloc: std.mem.Allocator,
    contents: []u8,

    pub fn init(noteMapFile: []const u8, alloc: std.mem.Allocator) !NoteMap {
        const mapfile = std.fs.cwd().openFile(noteMapFile, .{}) catch |err| blk: {
            switch (@TypeOf(err)) {
                std.fs.File.OpenError => {
                    std.log.warn("Failed to load {s}, createing a blank notemap.", .{noteMapFile});
                    break :blk null;
                },
                else => return err,
            }
        };
        const contents = if (mapfile) |m| try m.readToEndAlloc(alloc, 100_100) else try alloc.alloc(u8, 2);
        // defer alloc.free(contents);

        if (contents.len == 2) {
            @memcpy(contents, "{}");
        }

        const tree = try std.json.parseFromSlice(std.json.Value, alloc, contents, .{});
        return NoteMap{
            .recording = false,
            .recoding_index = 0,
            .last_keys = 0,
            .last_recorded = 0,
            .record_next = false,
            .filename = noteMapFile,
            .notemap = tree,
            .alloc = alloc,
            .contents = contents,
        };
    }
    pub fn deinit(self: *NoteMap) void {
        self.alloc.free(self.contents);
        self.notemap.deinit();
    }

    pub fn save(self: *NoteMap) !void {
        const notemap_json = try std.json.stringifyAlloc(
            self.alloc,
            self.notemap,
            .{ .whitespace = .indent_2 },
        );
        try std.fs.cwd().writeFile("./zig-out/tmp.json", notemap_json);
    }

    pub fn get(self: *NoteMap, key: []const u8) !?i64 {
        // var buffer = [_]u8{0} ** 10;
        // const str = try std.fmt.bufPrint(&buffer, "{s}", .{key});
        const val = self.notemap.value.object.get(key);
        std.debug.print("{any}\n", .{val});
        return if (val) |v|
            v.integer
        else
            null;
    }

    pub fn start_recording(self: *NoteMap) void {
        self.recording = true;
    }
    pub fn is_recording(self: *NoteMap) bool {
        return self.recording;
    }
    pub fn record(self: *NoteMap, keys: u32, pressure: i32) !void {
        _ = self;
        _ = keys;
        _ = pressure;
    }
    pub fn insert(self: *NoteMap, key: u32, value: i32) !void {
        _ = self;
        _ = key;
        _ = value;
    }
};

test "notemap" {
    var n = try NoteMap.init("notemap.json", std.testing.allocator);
    defer n.deinit();

    try std.testing.expectEqual(n.get("13444224"), 44);
    try n.save();
}
