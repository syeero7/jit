const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const Config = struct {
    repositoryformatversion: u1 = undefined,
    filemode: bool = undefined,
    bare: bool = undefined,

    pub fn read(allocator: Allocator, io: Io, path: []const u8) !Config {
        const file = try Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        const file_size = (try file.stat(io)).size;
        const buffer = try allocator.alloc(u8, file_size);
        _ = try file.readPositionalAll(io, buffer, 0);

        return Config.parse(buffer);
    }

    pub fn write(self: Config, io: Io, path: []const u8) !void {
        const file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
        defer file.close(io);

        var buffer: [1024]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        const writer = &file_writer.interface;

        _ = try writer.write("[core]\n");
        const fields = @typeInfo(@This()).@"struct".fields;
        inline for (fields) |field| {
            const value = @field(self, field.name);
            try writer.print("{s} = {any}\n", .{ field.name, value });
        }

        try writer.flush();
    }

    pub fn parse(buffer: []const u8) !Config {
        var config: Config = .{};
        var iterator = std.mem.splitScalar(u8, buffer, '\n');

        while (iterator.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, &std.ascii.whitespace);
            if (line.len == 0 or line[0] == '#' or line[0] == ';') continue;

            const fields = @typeInfo(@This()).@"struct".fields;
            inline for (fields) |field| {
                if (std.mem.startsWith(u8, line, field.name)) {
                    try config.setField(line, field);
                    break;
                }
            }
        }

        return config;
    }

    pub fn setField(self: *Config, line: []const u8, field: std.builtin.Type.StructField) !void {
        const idx = std.mem.indexOfScalar(u8, line, '=') orelse unreachable;
        const value = std.mem.trim(u8, line[idx + 1 ..], &std.ascii.whitespace);

        switch (field.type) {
            bool => @field(self, field.name) = std.mem.eql(u8, value, "true"),
            u1 => @field(self, field.name) = try std.fmt.parseInt(u1, value, 2),
            else => unreachable,
        }
    }
};

const Repository = struct {
    worktree: []const u8 = undefined,
    gitdir: []const u8 = undefined,
    config: Config = undefined,

    pub fn init(allocator: Allocator, path: []const u8) !Repository {
        return .{
            .worktree = path,
            .gitdir = try std.fs.path.join(allocator, &[_][]const u8{ path, ".git" }),
            .config = Config{
                .bare = false,
                .filemode = false,
                .repositoryformatversion = 0,
            },
        };
    }
};

pub fn create(allocator: Allocator, io: Io, path: []const u8) !Repository {
    var repo = try Repository.init(allocator, path);
    const cwd = Io.Dir.cwd();

    var worktree_exists = true;
    cwd.access(io, repo.worktree, .{}) catch |err| {
        worktree_exists = false;

        switch (err) {
            error.FileNotFound => try cwd.createDirPath(io, repo.worktree),
            else => return err,
        }
    };

    if (worktree_exists) {
        const gitdir = try cwd.openDir(io, repo.gitdir, .{ .iterate = true });
        defer gitdir.close(io);

        var iterator = gitdir.iterate();
        if (try iterator.next(io) != null) return error.NotEmpty;
    }

    try createPath(allocator, io, &[_][]const u8{ repo.gitdir, "branches" });
    try createPath(allocator, io, &[_][]const u8{ repo.gitdir, "objects" });
    try createPath(allocator, io, &[_][]const u8{ repo.gitdir, "refs", "heads" });
    try createPath(allocator, io, &[_][]const u8{ repo.gitdir, "refs", "tags" });

    const head_path = try std.fs.path.join(allocator, &[_][]const u8{ repo.gitdir, "HEAD" });
    const file = try cwd.createFile(io, head_path, .{});
    defer file.close(io);

    var buffer: [1024]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    const writer = &file_writer.interface;
    _ = try writer.write("ref: refs/heads/main\n"); // TODO: get default branch name from .gitconfig
    try writer.flush();

    const config_path = try std.fs.path.join(allocator, &[_][]const u8{ repo.gitdir, "config" });
    try repo.config.write(io, config_path);

    return repo;
}

pub fn retrieve(allocator: Allocator, io: Io) !Repository {
    var path = try Io.Dir.cwd().realPathFileAlloc(io, ".", allocator);

    while (true) {
        const gitdir = try std.fs.path.join(allocator, &[_][]const u8{ path, ".git" });
        Io.Dir.accessAbsolute(io, gitdir, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                if (std.fs.path.dirname(path)) |parent| {
                    const tmp_path = try allocator.dupeSentinel(u8, parent, 0);
                    path = tmp_path;
                    continue;
                } else return error.GitDirNotFound;
            },
            else => return err,
        };

        break;
    }

    var repo = try Repository.init(allocator, path);
    const config_path = try std.fs.path.join(allocator, &[_][]const u8{ repo.gitdir, "config" });
    repo.config = try Config.read(allocator, io, config_path);
    return repo;
}

fn createPath(allocator: Allocator, io: Io, path: []const []const u8) !void {
    const dir_path = try std.fs.path.join(allocator, path);
    try Io.Dir.cwd().createDirPath(io, dir_path);
}

test "parse git config" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const cfg = try Config.read(allocator, io, ".git/config");

    try std.testing.expect(cfg.repositoryformatversion == 0);
    try std.testing.expect(cfg.bare == false);
}

test "serialize git config" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const tmp_cfg: Config = .{
        .bare = false,
        .filemode = false,
        .repositoryformatversion = 0,
    };

    try tmp_cfg.write(io, ".tmp_files/config");
    const cfg = try Config.read(allocator, io, ".tmp_files/config");

    try std.testing.expect(cfg.repositoryformatversion == tmp_cfg.repositoryformatversion);
    try std.testing.expect(cfg.filemode == tmp_cfg.filemode);
    try std.testing.expect(cfg.bare == tmp_cfg.bare);
}

test "create git repo" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    _ = try create(allocator, io, "test_git/");
}

test "retrieve git repo" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const repo = try retrieve(allocator, io);

    try std.testing.expectEqualStrings(repo.worktree, std.fs.path.dirname(repo.gitdir).?);
    try std.testing.expect(repo.config.bare == false);
}
