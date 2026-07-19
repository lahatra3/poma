const std = @import("std");
const c = @import("c.zig").c;
const copy = @import("copy.zig");
const PgCopyIn = copy.PgCopyIn;
const PgCopyOut = copy.PgCopyOut;
const PgConfig = @import("config.zig").PgConfig;

pub const PgClient = struct {
    handle: *c.PGconn,

    pub fn init(config: PgConfig) !PgClient {
        const conn = c.PQconnectdb(config.conn_info) orelse {
            std.log.err("[Postgresql]: ❌ PGconn structure allocation failed ...", .{});
            return error.PostgresAllocationError;
        };

        if (c.PQstatus(conn) != c.CONNECTION_OK) {
            std.log.err(
                \\ [Postgresql]: ❌ Connection failed ..., 
                \\  Error: {s}
            ,
                .{
                    std.mem.span(c.PQerrorMessage(conn)),
                },
            );
            return error.PostgresConnectionFailed;
        }
        std.log.info("[Postgresql]: ✅ Connection ready ...", .{});

        return PgClient{
            .handle = conn,
        };
    }

    pub fn deinit(self: *PgClient) !void {
        std.log.info("[Postgresql]: Closing connection ...", .{});
        c.PQfinish(self.handle);
    }

    pub fn beginCopyIn(self: *PgClient, query: [:0]const u8) !PgCopyIn {
        try prepareCopy(query, c.PGRES_COPY_IN);

        return PgCopyIn{
            .conn_handle = self.handle,
        };
    }

    pub fn beginCopyOut(self: *PgClient, query: [:0]const u8) !PgCopyOut {
        try prepareCopy(query, c.PGRES_COPY_OUT);

        return PgCopyOut{
            .conn_handle = self.handle,
            .current_c_buf = null,
        };
    }

    fn prepareCopy(
        self: *PgClient,
        query: [:0]const u8,
        expected_status: c.ExecStatusType,
    ) !void {
        const res = c.PQexec(self.handle, query) orelse {
            std.log.err(
                \\ [Postgresql]: ❌ PQexec NULL pointer ...
                \\  Error: {s}
            ,
                .{
                    std.mem.span(c.PQerrorMessage(self.handle)),
                },
            );
            return error.PostgresQueryAllocationFailed;
        };
        defer c.PQclear(res);

        const res_status = c.PQresultStatus(res);
        if (res_status != expected_status) {
            std.log.err(
                \\ [Postgresql]: ❌ Unexpected COPY status ...
                \\  Expected: {s}
                \\  Got: {s},
                \\  Error: {s}
            ,
                .{
                    std.mem.span(c.PQresStatus(expected_status)),
                    std.mem.span(c.PQresStatus(res_status)),
                    std.mem.span(c.PQresultErrorMessage(res)),
                },
            );
            return error.PostgresUnexpectedCopyStatus;
        }
    }
};
