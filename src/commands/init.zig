const std = @import("std");

const cli = @import("../libs/cli.zig");
const repository = @import("../libs/repo.zig");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const print = std.fmt.allocPrint;

pub fn init(allocator: Allocator, io: std.Io, args: cli.Args) Allocator.Error!cli.Output {
    const path = if (args.len >= 1) args[0] else ".";
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
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = testing.io;

    const args = [_][]const u8{"/tmp/.jit_test/init_cmd"};
    try std.Io.Dir.cwd().deleteTree(io, args[0]);

    var output = try init(alloc, io, &args);
    try testing.expect(output.status == .Ok);

    output = try init(alloc, io, &args);
    try testing.expect(output.status == .Error);
}
