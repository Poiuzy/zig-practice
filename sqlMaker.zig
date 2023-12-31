const std = @import("std");
const t2 = @import("test2.zig");

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
    std.debug.print("{s}\n", .{sqlCreate(ts)});
    std.debug.print("{s}\n", .{sqlDrop(ts)});
    std.debug.print("{s}\n", .{sqlInsert(ts)});
}
