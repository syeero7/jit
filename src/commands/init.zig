const std = @import("std");

const cli = @import("../libs/cli.zig");
const repository = @import("../libs/repo.zig");

const Allocator = std.mem.Allocator;
const print = std.fmt.allocPrint;

pub fn init(allocator: Allocator, io: std.Io, args: cli.Args) Allocator.Error!cli.Output {
    const path = if (args.len >= 2) args[1] else ".";
    var output: cli.Output = .{ .status = .Error };

    const repo = repository.create(allocator, io, path) catch |err| {
        output.msg = switch (err) {
            error.RepositoryNotEmpty => try print(allocator, "Repository is not empty\n", .{}),
            else => try print(allocator, "An unexpected error occurred: {any}\n", .{err}),
        };

        return output;
    };

    output.status = .Ok;
    output.msg = try print(allocator, "Initialized empty Git repository in {s}\n", .{repo.gitdir});
    return output;
}

test "init command" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const args = [_][]const u8{ "init", ".tmp_files/init_cmd" };
    try std.Io.Dir.cwd().deleteTree(io, args[1]);

    const allocator = arena.allocator();
    var output = try init(allocator, io, &args);
    try std.testing.expect(output.status == .Ok);

    output = try init(allocator, io, &args);
    try std.testing.expect(output.status == .Error);
}
