const std = @import("std");
const c = @cImport(@cInclude("sqlite3.h"));

fn tableManeger(comptime _dataType: type) type {
    return struct {
        const Self = @This();
        const dataType: type = _dataType;
        const tableName: []const u8 = @typeName(_dataType);
        const createSql = sqlCreate(_dataType);

        fn create(pdb: ?*c.sqlite3) c_int {
            return c.sqlite3_exec(pdb, @ptrCast(Self.createSql), null, null, null);
        }
    };
}

fn typeSql(comptime t: type) []const u8 {
    comptime var result: []const u8 = undefined;
    switch (t) {
        u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128 => {
            result = "INTEGER";
        },
        f16, f32, f64, f80, f128 => {
            result = "REAL";
        },
        []const u8 => {
            result = "TEXT";
        },
        []u8 => {
            result = "BLOB";
        },
        else => {
            result = "ANY";
        },
    }
    return result;
}

fn sqlCreate(comptime s: type) []const u8 {
    comptime var result: []const u8 = std.fmt.comptimePrint("CREATE TABLE IF NOT EXISTS \"{s}\"(", .{@typeName(s)});
    comptime var flag = true;
    inline for (@typeInfo(s).Struct.fields) |field| {
        if (flag) {
            flag = false;
        } else {
            result = std.fmt.comptimePrint("{s},", .{result});
        }
        result = std.fmt.comptimePrint("{s}\"{s}\" {s}", .{ result, field.name, comptime typeSql(field.type) });
    }
    result = std.fmt.comptimePrint("{s}) STRICT;", .{result});
    return result;
}

fn sqlDrop(comptime s: type) []const u8 {
    return std.fmt.comptimePrint("DROP TABLE IF EXISTS \"{s}\"", .{@typeName(s)});
}

fn sqlInsert(comptime s: type) []const u8 {
    comptime var result: []const u8 = std.fmt.comptimePrint("INSERT INTO \"{s}\"(", .{@typeName(s)});
    comptime var flag = true;
    inline for (@typeInfo(s).Struct.fields) |field| {
        if (flag) {
            flag = false;
        } else {
            result = std.fmt.comptimePrint("{s},", .{result});
        }
        result = std.fmt.comptimePrint("{s}\"{s}\"", .{ result, field.name });
    }
    result = std.fmt.comptimePrint("{s}) VALUES (", .{result});
    flag = true;
    inline for (@typeInfo(s).Struct.fields) |_| {
        if (flag) {
            flag = false;
        } else {
            result = std.fmt.comptimePrint("{s},", .{result});
        }
        result = std.fmt.comptimePrint("{s}?", .{result});
    }
    result = std.fmt.comptimePrint("{s});", .{result});
    return result;
}

const ts = struct { a: u8, b: []const u8 };

pub fn main() !void {
    const s = tableManeger(ts);
    var pdb: ?*c.sqlite3 = undefined;
    _ = c.sqlite3_open("test.sqlite3", &pdb);
    _ = s.create(pdb);
    _ = c.sqlite3_close(pdb);
}
