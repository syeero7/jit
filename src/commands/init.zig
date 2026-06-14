const std = @import("std");
const libs = @import("libs");

const cli = libs.cli;
const repository = libs.repo;

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
