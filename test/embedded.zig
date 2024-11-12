const std = @import("std");
const Interface = @import("interface").Interface;

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

test "interface embedding" {
    // Base interfaces
    const Logger = Interface(.{
        .log = fn (anytype, []const u8) void,
        .getLogLevel = fn (anytype) u8,
    }, null);

    const Metrics = Interface(.{
        .increment = fn (anytype, []const u8) void,
        .getValue = fn (anytype, []const u8) u64,
    }, .{Logger});

    // Complex interface that embeds both Logger and Metrics
    const MonitoredRepository = Interface(.{
        .create = fn (anytype, User) anyerror!u32,
        .findById = fn (anytype, u32) anyerror!?User,
        .update = fn (anytype, User) anyerror!void,
        .delete = fn (anytype, u32) anyerror!void,
    }, .{Metrics});

    // Implementation that satisfies all interfaces
    const TrackedRepository = struct {
        allocator: std.mem.Allocator,
        users: std.AutoHashMap(u32, User),
        next_id: u32,
        log_level: u8,
        metrics: std.StringHashMap(u64),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .users = std.AutoHashMap(u32, User).init(allocator),
                .next_id = 1,
                .log_level = 0,
                .metrics = std.StringHashMap(u64).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.metrics.deinit();
            self.users.deinit();
        }

        // Logger interface implementation
        pub fn log(self: Self, message: []const u8) void {
            _ = self;
            _ = message;
            // In real code: actual logging
        }

        pub fn getLogLevel(self: Self) u8 {
            return self.log_level;
        }

        // Metrics interface implementation
        pub fn increment(self: *Self, key: []const u8) void {
            if (self.metrics.get(key)) |value| {
                self.metrics.put(key, value + 1) catch {};
            } else {
                self.metrics.put(key, 1) catch {};
            }
        }

        pub fn getValue(self: Self, key: []const u8) u64 {
            return self.metrics.get(key) orelse 0;
        }

        // Repository interface implementation
        pub fn create(self: *Self, user: User) !u32 {
            self.log("Creating new user");
            self.increment("users.created");

            var new_user = user;
            new_user.id = self.next_id;
            try self.users.put(self.next_id, new_user);
            self.next_id += 1;
            return new_user.id;
        }

        pub fn findById(self: *Self, id: u32) !?User {
            self.increment("users.lookup");
            return self.users.get(id);
        }

        pub fn update(self: *Self, user: User) !void {
            self.log("Updating user");
            self.increment("users.updated");

            if (!self.users.contains(user.id)) {
                return error.UserNotFound;
            }
            try self.users.put(user.id, user);
        }

        pub fn delete(self: *Self, id: u32) !void {
            self.log("Deleting user");
            self.increment("users.deleted");

            if (!self.users.remove(id)) {
                return error.UserNotFound;
            }
        }
    };

    // Test that our implementation satisfies all interfaces
    comptime MonitoredRepository.satisfiedBy(TrackedRepository);
    comptime Logger.satisfiedBy(TrackedRepository);
    comptime Metrics.satisfiedBy(TrackedRepository);

    // Test the actual implementation
    var repo = try TrackedRepository.init(std.testing.allocator);
    defer repo.deinit();

    // Create a user and verify metrics
    const user = User{ .id = 0, .name = "Test User", .email = "test@example.com" };
    const id = try repo.create(user);
    try std.testing.expectEqual(@as(u64, 1), repo.getValue("users.created"));

    // Look up the user and verify metrics
    const found = try repo.findById(id);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(u64, 1), repo.getValue("users.lookup"));

    // Test logging level
    try std.testing.expectEqual(@as(u8, 0), repo.getLogLevel());
}

test "interface embedding with conflicts" {
    // Two interfaces with conflicting method names
    const BasicLogger = Interface(.{
        .log = fn (anytype, []const u8) void,
    }, null);

    const MetricLogger = Interface(.{
        .log = fn (anytype, []const u8, u64) void,
    }, null);

    // This should fail to compile due to conflicting 'log' methods
    const ConflictingLogger = Interface(.{
        .write = fn (anytype, []const u8) void,
    }, .{ BasicLogger, MetricLogger });

    // Implementation that tries to satisfy both
    const BadImplementation = struct {
        pub fn write(self: @This(), message: []const u8) void {
            _ = self;
            _ = message;
        }

        pub fn log(self: @This(), message: []const u8) void {
            _ = self;
            _ = message;
        }
    };

    // This should fail compilation with an ambiguous method error
    comptime {
        if (ConflictingLogger.incompatibilities(BadImplementation).len == 0) {
            @compileError("Should have detected conflicting 'log' methods");
        }
    }
}

test "nested interface embedding" {
    // Base interface
    const Closer = Interface(.{
        .close = fn (anytype) void,
    }, null);

    // Mid-level interface that embeds Closer
    const Writer = Interface(.{
        .write = fn (anytype, []const u8) anyerror!void,
    }, .{Closer});

    // Top-level interface that embeds Writer
    const FileWriter = Interface(.{
        .flush = fn (anytype) anyerror!void,
    }, .{Writer});

    // Implementation that satisfies all interfaces
    const Implementation = struct {
        pub fn close(self: @This()) void {
            _ = self;
        }

        pub fn write(self: @This(), data: []const u8) !void {
            _ = self;
            _ = data;
        }

        pub fn flush(self: @This()) !void {
            _ = self;
        }
    };

    // Should satisfy all interfaces
    comptime FileWriter.satisfiedBy(Implementation);
    comptime Writer.satisfiedBy(Implementation);
    comptime Closer.satisfiedBy(Implementation);
}
