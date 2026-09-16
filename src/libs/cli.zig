const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Args = []const []const u8;
pub const Command = struct {
    name: []const u8,
    func: *const fn (Allocator, Io, Args) anyerror!void,
};

pub fn start(allocator: Allocator, io: Io, args: Args, commands: []const Command) !void {
    const cmd = findCommand(args, commands) catch |err| {
        switch (err) {
            error.NoArgs => try printErr(io, "usage: jit <command>\n", .{}),
            error.UnkownCommand => try printErr(io, "unknown command: {s}\n", .{args[1]}),
        }

        return err;
    };

    try cmd.func(allocator, io, args[2..]);
}

pub fn print(io: Io, file: Io.File, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    const writer = &file_writer.interface;

    try writer.print(fmt, args);
    try writer.flush();
}

pub fn printOut(io: Io, comptime fmt: []const u8, args: anytype) !void {
    try print(io, Io.File.stdout(), fmt, args);
}

pub fn printErr(io: Io, comptime fmt: []const u8, args: anytype) !void {
    try print(io, Io.File.stderr(), fmt, args);
}

fn findCommand(args: Args, commands: []const Command) !Command {
    if (args.len < 2) return error.NoArgs;

    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, args[1])) return cmd;
    }

    return error.UnkownCommand;
}
