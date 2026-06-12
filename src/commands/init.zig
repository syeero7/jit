const std = @import("std");

const cli = @import("../cli.zig");
const repository = @import("../repo.zig");

pub fn init(allocator: std.mem.Allocator, io: std.Io, stdout: *std.Io.Writer, args: cli.Args) cli.Error!void {
    const path = if (args.len >= 2) args[1] else ".";
    const repo = repository.create(allocator, io, path) catch |err| {
        switch (err) {
            error.RepositoryNotEmpty => std.debug.print("Repository is not empty\n", .{}),
            else => std.debug.print("An unexpected error occurred: {any}\n", .{err}),
        }

        return cli.Error.CommandFailed;
    };

    try stdout.print("Initialized empty Git repository in {s}\n", .{repo.gitdir});
    try stdout.flush();
}
