# Poma 🍎

**Poma** is a modern, idiomatic Zig (version 0.16.0) library that provides a type-safe and efficient wrapper around `libpq` (PostgreSQL), with a strong focus on high-performance `COPY IN` and `COPY OUT` streaming operations.

Unlike traditional C bindings, **Poma** eliminates raw C boilerplate and transforms PostgreSQL data streams into strongly-typed Zig structures, making invalid states unrepresentable at compile time.

## ✨ Features

* **Explicit, Type-Safe API:** Separate structures for `COPY IN` (writing) and `COPY OUT` (reading) to catch protocol errors at compile time rather than runtime.
* **Transparent Memory Management:** Automatic cleanup of C-allocated buffers (`libpq`'s `malloc`) during `COPY OUT` row iterations, preventing memory leaks seamlessly.
* **Zero Boilerplate:** Centralized `libpq` error checking, logging, and automatic `PGresult` cleanup.

---

## 📦 Installation

Poma uses the official Zig package manager.

### 1. Add the Dependency
Run the following command at the root of your main project:

```bash
zig fetch --save git+https://github.com/lahatra3/poma.git#main
```

### 2. Usage example

```zig
// build.zig

const poma_dep = b.dependency("poma", .{
    .target = target,
    .optimize = optimize,
});

const poma_mod = poma_dep.module("poma");
exe.root_module.addImport("poma", poma_mod);
```

```zig
// main.zig

const std = @import("std");
const poma = @import("poma");

pub fn main(init: std.process.Init) !void {
    const client = try poma.PgClient.init(.{
        .conn_info = "host=localhost port=5432 dbname=ldf user=lahatra3 password=lahatrad",
    });
    defer client.deinit();
}
```

```zig
// COPY IN (Writing Data)
var copy_in = try client.beginCopyIn("COPY app.users(id, username) FROM STDIN WITH CSV;");

// Write data chunks
try copy_in.write("1, lahatra3\n");
try copy_in.write("2, Jesoa\n");

// Finalize the stream to commit the transaction
try copy_in.end();
```

```zig
// COPY OUT (Reading Data)
var copy_out = try client.beginCopyOut("COPY app.users(id, username) TO STDOUT WITH CSV;");
defer copy_out.deinit();

while (try copy_out.read()) |row| {
    std.debug.print("Received row: {s}", .{row});
}
```
