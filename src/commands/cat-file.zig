const std = @import("std");

const cli = @import("../libs/cli.zig");
const repository = @import("../libs/repo.zig");
const git_object = @import("../libs/git_object.zig");
const init_cmd = @import("init.zig");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const print = std.fmt.allocPrint;

pub fn catFile(alloc: Allocator, io: std.Io, args: cli.Args) Allocator.Error!cli.Output {
    var output: cli.Output = .{ .status = .err };

    _ = objk: {
        if (args.len >= 1) {
            inline for (std.enums.values(git_object.GitObjKind)) |kind| {
                if (std.mem.eql(u8, args[0], kind.toString())) break :objk kind;
            }

            output.msg = try print(alloc, "unknown argument: {s}.\n<type> must be one of 'blob', 'tree', 'commit' or 'tag'\n", .{args[0]});
            return output;
        }

        output.msg = try print(alloc, "usage: jit cat-file <type> <object>\n", .{});
        return output;
    };

    const object_hash = objh: {
        if (args.len == 2) {
            if (args[1].len == 40) break :objh args[1];

            output.msg = try print(alloc, "fatal: Not a valid object name {x}\n", .{args[1]});
            return output;
        }

        output.msg = try print(alloc, "usage: jit cat-file <type> <object>\n", .{});
        return output;
    };

    const repo = repository.retrieve(alloc, io) catch |err| {
        output.msg = switch (err) {
            error.GitDirNotFound => try print(alloc, "fatal: not a git repository\n", .{}),
            else => try print(alloc, "An unexpected error occurred: {any}\n", .{err}),
        };

        return output;
    };

    const obj = git_object.read(alloc, io, repo, object_hash) catch |err| {
        output.msg = switch (err) {
            error.MalformedObject => try print(alloc, "fatal: malformed git object\n", .{}),
            else => try print(alloc, "An unexpected error occurred: {any}\n", .{err}),
        };

        return output;
    };

    output.status = .ok;
    output.msg = try print(alloc, "{s}\n", .{try obj.serialize()});
    return output;
}

test "cat-file command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const io = testing.io;

    _ = try init_cmd.init(alloc, io, &[_][]const u8{ "init", "/tmp/.jit_test/cat-file_cmd" });
    var args = [_][]const u8{ "blob", "012f77ae437960213c076c5bdd1003c20e58b0a4" };
    var output = try catFile(alloc, io, &args);
    try testing.expect(output.status == .ok);

    args[0] = "bob";
    output = try catFile(alloc, io, &args);
    try testing.expect(output.status == .err);

    args[1] = "xyz";
    output = try catFile(alloc, io, &args);
    try testing.expect(output.status == .err);
}
