const std = @import("std");
const cli = @import("cli.zig");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    const commands = [_]cli.Command{
        cli.Command{
            .name = undefined,
            .func = undefined,
        },
    };

    try cli.start(allocator, init.io, args, &commands);
}
