const std = @import("std");

const cli = @import("../libs/cli.zig");
const repository = @import("../libs/repo.zig");
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
