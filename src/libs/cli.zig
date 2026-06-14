const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const Error = error{
    NoArgs,
    MissingRequiredArgs,
    UnkownCommand,
    CommandFailed,
    WriteFailed,
};

const OutputStatus = enum { Ok, Error };

pub const Output = struct {
    status: OutputStatus = undefined,
    msg: []u8 = undefined,
};

pub const Args = []const []const u8;

pub const Command = struct {
    name: []const u8,
    func: *const fn (Allocator, Io, Args) Allocator.Error!Output,
};

pub fn start(allocator: Allocator, io: Io, args: Args, commands: []const Command) !void {
    if (args.len < 2) return Error.NoArgs;

    const cmd: Command = for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, args[1])) break cmd;
    } else return Error.UnkownCommand;

    const output = try cmd.func(allocator, io, args[1..]);
    const file_descriptor = switch (output.status) {
        .Ok => Io.File.stdout(),
        .Error => Io.File.stderr(),
    };

    var buffer: [1024]u8 = undefined;
    var writer = file_descriptor.writer(io, &buffer);
    const w = &writer.interface;

    _ = try w.write(output.msg);
    try w.flush();
}
