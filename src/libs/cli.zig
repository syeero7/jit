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
    const cmd = findCommand(args, commands) catch |err| {
        const stderr = Io.File.stderr();
        var buffer: [1024]u8 = undefined;
        var err_writer = stderr.writer(io, &buffer);
        const writer = &err_writer.interface;

        switch (err) {
            error.NoArgs => try writer.print("usage: jit <command>\n", .{}),
            error.UnkownCommand => try writer.print("unknown command: {s}\n", .{args[1]}),
            else => try writer.print("An unexpected error occurred: {any}\n", .{err}),
        }

        try writer.flush();
        return;
    };

    const output = try cmd.func(allocator, io, args[2..]);
    const file_descriptor = switch (output.status) {
        .Ok => Io.File.stdout(),
        .Error => Io.File.stderr(),
    };

    var buffer: [1024]u8 = undefined;
    var writer = file_descriptor.writer(io, &buffer);
    const w = &writer.interface;

    try w.writeAll(output.msg);
    try w.flush();
}

fn findCommand(args: Args, commands: []const Command) !Command {
    if (args.len < 2) return Error.NoArgs;

    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, args[1])) return cmd;
    }

    return Error.UnkownCommand;
}
