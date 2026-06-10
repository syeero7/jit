const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const Config = struct {
    repositoryformatversion: u1 = undefined,
    filemode: bool = undefined,
    bare: bool = undefined,

    pub fn read(allocator: Allocator, io: Io, path: []const u8) !Config {
        const file = try Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        const file_size = (try file.stat(io)).size;
        const buffer = try allocator.alloc(u8, file_size);
        _ = try file.readPositionalAll(io, buffer, 0);

        return Config.parse(buffer);
    }

    // pub fn write(self: Config, allocator: Allocator, io: Io, path: []const u8) !void {}

    pub fn parse(buffer: []const u8) !Config {
        var config: Config = .{};
        var iterator = std.mem.splitScalar(u8, buffer, '\n');

        while (iterator.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, &std.ascii.whitespace);
            if (line.len == 0 or line[0] == '#' or line[0] == ';') continue;

            const fields = @typeInfo(@This()).@"struct".fields;
            inline for (fields) |field| {
                if (std.mem.startsWith(u8, line, field.name)) {
                    try config.setField(line, field);
                    break;
                }
            }
        }

        return config;
    }

    pub fn setField(self: *Config, line: []const u8, field: std.builtin.Type.StructField) !void {
        const idx = std.mem.indexOfScalar(u8, line, '=') orelse unreachable;
        const value = std.mem.trim(u8, line[idx + 1 ..], &std.ascii.whitespace);

        switch (field.type) {
            bool => @field(self, field.name) = std.mem.eql(u8, value, "true"),
            u1 => @field(self, field.name) = try std.fmt.parseInt(u1, value, 2),
            else => unreachable,
        }
    }
};

const Repository = struct {
    worktree: []const u8 = undefined,
    gitdir: []const u8 = undefined,
    config: *Config = undefined,
};

// pub fn create(allocator: Allocator) !void {}

test "parse git config" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const cfg = try Config.read(allocator, io, ".git/config");

    try std.testing.expect(cfg.repositoryformatversion == 0);
    try std.testing.expect(cfg.bare == false);
}
