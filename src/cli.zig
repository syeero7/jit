const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Error = error{
    NoArgs,
    MissingRequiredArgs,
    UnkownCommand,
    CommandFailed,
};

pub const Args = []const []const u8;

pub const Command = struct {
    name: []const u8,
    func: *const fn (Allocator, *Io.Writer, Args) Error!void,
};

pub fn start(allocator: Allocator, io: Io, args: Args, commands: []const Command) !void {
    if (args.len < 2) return Error.NoArgs;

    const cmd: Command = for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, args[1])) break cmd;
    } else return Error.UnkownCommand;

    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_writer.interface;

    try cmd.func(allocator, stdout, args[1..]);
}
