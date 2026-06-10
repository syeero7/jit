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
        var iterator = std.mem.splitScalar(u8, buffer, '\n');

        var config: Config = .{};

        while (iterator.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, &std.ascii.whitespace);
            if (line.len == 0 or line[0] == '#' or line[0] == ';') continue;

            inline for (std.meta.fields(@This())) |field| {
                if (std.mem.startsWith(u8, line, field.name)) {
                    const idx = std.mem.indexOfScalar(u8, line, '=') orelse unreachable;
                    const value = std.mem.trim(u8, line[idx + 1 ..], &std.ascii.whitespace);

                    switch (field.type) {
                        bool => @field(config, field.name) = std.mem.eql(u8, value, "true"),
                        u1 => @field(config, field.name) = try std.fmt.parseInt(u1, value, 2),
                        else => unreachable,
                    }

                    break;
                }
            }
        }

        return config;
    }

    // pub fn write(self: Config, allocator: Allocator, io: Io, path: []const u8) !void {}

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
