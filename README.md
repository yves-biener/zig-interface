# Zig Interfaces & Validation

A compile-time interface checker for Zig that enables interface-based design
with comprehensive type checking and detailed error reporting.

## Features

This library provides a way to define and verify interfaces in Zig at compile
time. It supports:

- Type-safe interface definitions with detailed error reporting
- Interface embedding (composition)
- Complex type validation including structs, enums, arrays, and slices
- Comprehensive compile-time error messages with helpful hints
- Flexible error union compatibility with `anyerror`

## Install

Add or update this library as a dependency in your zig project run the following command:

```sh
zig fetch --save git+https://github.com/nilslice/zig-interface
```

Afterwards add the library as a dependency to any module in your _build.zig_:

```zig
// ...
const interface_dependency = b.dependency("interface", .{
    .target = target,
    .optimize = optimize,
});

const exe = b.addExecutable(.{
    .name = "main",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});
// import the exposed `interface` module from the dependency
exe.root_module.addImport("interface", interface_dependency.module("interface"));
// ...
```

In the end you can import the `interface` module. For example:

```zig
const Interface = @import("interface").Interface;

const Repository = Interface(.{
    .create = fn(anytype, User) anyerror!u32,
    .findById = fn(anytype, u32) anyerror!?User,
    .update = fn(anytype, User) anyerror!void,
    .delete = fn(anytype, u32) anyerror!void,
}, null);
```

## Usage

1. Define an interface with required method signatures:

```zig
const Repository = Interface(.{
    .create = fn(anytype, User) anyerror!u32,
    .findById = fn(anytype, u32) anyerror!?User,
    .update = fn(anytype, User) anyerror!void,
    .delete = fn(anytype, u32) anyerror!void,
}, null);
```

2. Implement the interface methods in your type:

```zig
const InMemoryRepository = struct {
    allocator: std.mem.Allocator,
    users: std.AutoHashMap(u32, User),
    next_id: u32,

    pub fn create(self: *InMemoryRepository, user: User) !u32 {
        var new_user = user;
        new_user.id = self.next_id;
        try self.users.put(self.next_id, new_user);
        self.next_id += 1;
        return new_user.id;
    }

    // ... other Repository methods
};
```

3. Verify the implementation at compile time:

```zig
// In functions that accept interface implementations:
fn createUser(repo: anytype, name: []const u8, email: []const u8) !User {
    comptime Repository.satisfiedBy(@TypeOf(repo));
    // ... rest of implementation
}

// Or verify directly:
comptime Repository.satisfiedBy(InMemoryRepository);
```

## Interface Embedding

Interfaces can embed other interfaces to combine their requirements:

```zig
const Logger = Interface(.{
    .log = fn(anytype, []const u8) void,
    .getLogLevel = fn(anytype) u8,
}, null);

const Metrics = Interface(.{
    .increment = fn(anytype, []const u8) void,
    .getValue = fn(anytype, []const u8) u64,
}, .{ Logger });  // Embeds Logger interface

// Now implements both Metrics and Logger methods
const MonitoredRepository = Interface(.{
    .create = fn(anytype, User) anyerror!u32,
    .findById = fn(anytype, u32) anyerror!?User,
}, .{ Metrics });
```

> Note: you can embed arbitrarily many interfaces!

## Error Reporting

The library provides detailed compile-time errors when implementations don't
match:

```zig
// Wrong parameter type ([]u8 vs []const u8)
const BadImpl = struct {
    pub fn writeAll(self: @This(), data: []u8) !void {
        _ = self;
        _ = data;
    }
};

// Results in compile error:
// error: Method 'writeAll' parameter 1 has incorrect type:
//    └─ Expected: []const u8
//    └─ Got: []u8
//       └─ Hint: Consider making the parameter type const
```

## Complex Types

The interface checker supports complex types including:

```zig
const ComplexTypes = Interface(.{
    .process = fn(
        anytype,
        struct { config: Config, points: []const DataPoint },
        enum { ready, processing, error },
        []const struct {
            timestamp: i64,
            data: ?[]const DataPoint,
            status: Status,
        }
    ) anyerror!?ProcessingResult,
}, null);
```
