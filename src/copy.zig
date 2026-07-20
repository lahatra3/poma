const std = @import("std");
const c = @import("c.zig").c;

pub const PgCopyIn = struct {
    conn_handle: *c.PGconn,

    pub fn write(self: *PgCopyIn, data: []const u8) !void {
        const res = c.PQputCopyData(
            self.conn_handle,
            data.ptr,
            @intCast(data.len),
        );
        if (res != 1) {
            std.log.err("[Poma 🍎]: ❌ COPY_IN in failed (write) ...", .{});
            return error.PostgresCopyWriteFailed;
        }
    }

    pub fn end(self: *PgCopyIn) !void {
        if (c.PQputCopyEnd(self.conn_handle, null) != 1) {
            std.log.err(
                "[Poma 🍎]: ❌ COPY_IN in failed (end) ...",
                .{
                    std.mem.span(c.PQerrorMessage(self.conn_handle)),
                },
            );
            return error.PostgresCopyEndFailed;
        }

        var has_error = false;

        while (c.PQgetResult(self.conn_handle)) |res| {
            defer c.PQclear(res);

            const status = c.PQresultStatus(res);
            if (status != c.PGRES_COMMAND_OK) {
                std.log.err(
                    \\ [Poma 🍎]: ❌ COPY_IN failed at command completion ... 
                    \\  Status: {s},
                    \\  Error: {s}
                ,
                    .{
                        std.mem.span(c.PQresStatus(status)),
                        std.mem.span(c.PQresultErrorMessage(res)),
                    },
                );
                has_error = true;
            }
        }

        if (has_error) {
            return error.PostgresCopyWriteCommandFailed;
        }
    }
};

pub const PgCopyOut = struct {
    conn_handle: *c.PGconn,
    current_c_buf: ?[*c]u8 = null,

    pub fn deinit(self: *PgCopyOut) void {
        self.freeCurrentBuffer();

        while (c.PQgetResult(self.conn_handle)) |res| {
            c.PQclear(res);
        }
    }

    pub fn read(self: *PgCopyOut) !?[]const u8 {
        self.freeCurrentBuffer();

        var c_buf: [*c]u8 = null;
        const res = c.PQgetCopyData(self.conn_handle, &c_buf, 0);

        if (res > 0) {
            self.current_c_buf = c_buf;
            return c_buf[0..@intCast(res)];
        } else if (res == -1) {
            var has_error = false;

            while (c.PQgetResult(self.conn_handle)) |result| {
                defer c.PQclear(result);

                const status = c.PQresultStatus(result);
                if (status != c.PGRES_COMMAND_OK) {
                    std.log.err(
                        \\ [Poma 🍎]: ❌ COPY_OUT failed at command completion ...
                        \\  Status: {s},
                        \\  Error: {s}
                    ,
                        .{
                            std.mem.span(c.PQresStatus(status)),
                            std.mem.span(c.PQresultErrorMessage(result)),
                        },
                    );
                    has_error = true;
                }
            }

            if (has_error) {
                return error.PostgresCopyReadCommandFailed;
            }
            return null;
        } else {
            std.log.err(
                \\ [Poma 🍎]: ❌ COPY_OUT data read failed ...
                \\  Error: {s}
            ,
                .{
                    std.mem.span(c.PQerrorMessage(self.conn_handle)),
                },
            );
            return error.PostgresCopyReadFailed;
        }
    }

    fn freeCurrentBuffer(self: *PgCopyOut) void {
        if (self.current_c_buf) |buf| {
            c.PQfreemem(buf);
            self.current_c_buf = null;
        }
    }
};
