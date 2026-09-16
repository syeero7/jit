const std = @import("std");

const cli = @import("../libs/cli.zig");
const repository = @import("../libs/repo.zig");
const git_object = @import("../libs/git_object.zig");
const Allocator = std.mem.Allocator;

pub fn catFile(allocator: Allocator, io: std.Io, args: cli.Args) !void {
    _ = objk: {
        if (args.len >= 1) {
            inline for (std.enums.values(git_object.GitObjKind)) |kind| {
                if (std.mem.eql(u8, args[0], kind.toString())) break :objk kind;
            }

            try cli.printErr(io, "invalid argument: {s}.\n<type> must be one of 'blob', 'tree', 'commit' or 'tag'\n", .{args[0]});
            return error.InvalidArgument;
        }

        try cli.printOut(io, "usage: jit cat-file <type> <object>\n", .{});
        return;
    };

    const object_hash = objh: {
        if (args.len == 2) {
            if (args[1].len == 40) break :objh args[1];

            try cli.printErr(io, "fatal: Not a valid object name {x}\n", .{args[1]});
            return error.InvalidArgument;
        }

        try cli.printOut(io, "usage: jit cat-file <type> <object>\n", .{});
        return;
    };

    const repo = repository.retrieve(allocator, io) catch |err| {
        switch (err) {
            error.GitDirNotFound => try cli.printErr(io, "fatal: not a git repository\n", .{}),
            else => try cli.printErr(io, "An unexpected error occurred: {any}\n", .{err}),
        }

        return err;
    };

    const obj = git_object.read(allocator, io, repo, object_hash) catch |err| {
        switch (err) {
            error.MalformedObject => try cli.printErr(io, "fatal: malformed git object\n", .{}),
            else => try cli.printErr(io, "An unexpected error occurred: {any}\n", .{err}),
        }

        return err;
    };

    try cli.printOut(io, "{s}\n", .{try obj.serialize()});
}
