const std = @import("std");

const cli = @import("../libs/cli.zig");
const repository = @import("../libs/repo.zig");

const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn init(allocator: Allocator, io: std.Io, args: cli.Args) anyerror!void {
    const path = if (args.len >= 1) args[0] else ".";
    const repo = repository.create(allocator, io, path) catch |err| {
        switch (err) {
            error.RepositoryNotEmpty => try cli.printErr(io, "Repository is not empty\n", .{}),
            else => try cli.printErr(io, "An unexpected error occurred: {any}\n", .{err}),
        }

        return err;
    };

    try cli.printOut(io, "Initialized empty Git repository in {s}\n", .{repo.gitdir});
}

test "init command" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const io = testing.io;

    const args = [_][]const u8{"/tmp/.jit_test/init_cmd"};
    try std.Io.Dir.cwd().deleteTree(io, args[0]);

    try init(allocator, io, &args);
    if (init(allocator, io, &args)) {} else |_| return error.TestUnexpectedResult;
}
