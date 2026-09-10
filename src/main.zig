const std = @import("std");

const cli = @import("libs/cli.zig");
const cmd_init = @import("commands/init.zig");
const cmd_cat_file = @import("commands/cat-file.zig");
const x = @import("libs/git_object.zig"); // temp import for testing

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    _ = x;
    const allocator = arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    const commands = [_]cli.Command{
        cli.Command{
            .name = "init",
            .func = &cmd_init.init,
        },
        cli.Command{
            .name = "cat-file",
            .func = &cmd_cat_file.catFile,
        },
    };

    try cli.start(allocator, init.io, args, &commands);
}

test {
    std.testing.refAllDecls(@This());
}
