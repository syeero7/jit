const std = @import("std");
const repository = @import("repo.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const Sha1 = std.crypto.hash.Sha1;
const Repository = repository.Repository;
const ArrayList = std.ArrayList;
const flate = std.compress.flate;
const testing = std.testing;

const Error = error{
    InvalidHash,
    DecompressionFaild,
    ComressionFaild,
    DecompressionInitFaild,
    ComressionInitFaild,
    MalformedObject,
};

const GitObjKind = enum {
    Commit,
    Tree,
    Blob,
    Tag,
};

pub const GitObject = struct {
    kind: GitObjKind = undefined,
    data: []const u8 = undefined,

    pub fn init(kind: GitObjKind, data: []const u8) GitObject {
        return .{ .kind = kind, .data = data };
    }

    pub fn parse() !void {}

    pub fn serialize() !void {}
};

pub fn read(allocator: Allocator, io: Io, repo: Repository, hash: []const u8) !GitObject {
    if (hash.len < 2) return Error.InvalidHash;

    const parts = [_][]const u8{ repo.gitdir, "objects", hash[0..2], hash[2..] };
    const obj_path = try std.fs.path.join(allocator, &parts);

    const file = try Io.Dir.cwd().openFile(io, obj_path, .{});
    defer file.close(io);

    var buffer: [1024 * 4]u8 = undefined;
    var file_reader = file.reader(io, &buffer);
    const reader = &file_reader.interface;

    var decomp_buf: [flate.max_window_len]u8 = undefined;
    var decompressor = flate.Decompress.init(reader, .zlib, &decomp_buf);
    const decomp_reader = &decompressor.reader;
    var output_buf: ArrayList(u8) = .empty;
    defer output_buf.deinit(allocator);

    try decomp_reader.appendRemainingUnlimited(allocator, &output_buf);
    const output = try output_buf.toOwnedSlice(allocator);

    if (std.mem.findScalar(u8, output, ' ')) |i| {
        if (std.mem.findScalarPos(u8, output, i, '\x00')) |j| {
            const size = try std.fmt.parseUnsigned(u64, output[i + 1 .. j], 10);
            if (size == output.len - j - 1) {
                const obj_kind = output[0..i];
                const obj_data = output[j + 1 ..];

                if (std.mem.eql(u8, obj_kind, "commit")) return GitObject.init(.Commit, obj_data);
                if (std.mem.eql(u8, obj_kind, "tree")) return GitObject.init(.Tree, obj_data);
                if (std.mem.eql(u8, obj_kind, "blob")) return GitObject.init(.Blob, obj_data);
                if (std.mem.eql(u8, obj_kind, "tag")) return GitObject.init(.Tag, obj_data);
            }
        }
    }

    return Error.MalformedObject;
}

pub fn write() !void {}

test "read hash" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const io = testing.io;

    const repo = try repository.retrieve(gpa, io);
    const k = try read(gpa, io, repo, "03c219041af8ef82422e94a32a787e52bb4acbdc");
    std.debug.print("{any}", .{k});
}
