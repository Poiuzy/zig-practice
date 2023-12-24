const std = @import("std");
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const NodeType = enum { mistake, null, int, float, bool, string, array, map };

fn NodeValue(comptime intType: type, comptime floatType: type) type {
    return union { int: intType, float: floatType, bool: bool, string: []const u8, array: ArrayList(Node(intType, floatType)), map: StringHashMap(Node(intType, floatType)) };
}

fn Node(comptime intType: type, comptime floatType: type) type {
    return struct {
        const Self = @This();
        type: NodeType = NodeType.mistake,
        data: NodeValue(intType, floatType) = undefined,

        pub fn readFromString(json: []const u8, allocator: std.mem.Allocator) @This() {
            var index: usize = 0;
            return @This().readItem(json, &index, allocator);
        }

        pub fn clearAndFree(self: *Self) void {
            var tmp: Self = undefined;
            switch (self.type) {
                NodeType.array => {
                    for (self.data.array.items) |node| {
                        tmp = node;
                        tmp.clearAndFree();
                    }
                    self.data.array.clearAndFree();
                },
                else => {},
            }
        }

        fn readItem(json: []const u8, index: *usize, allocator: std.mem.Allocator) @This() {
            while (index.* < json.len) {
                switch (json[index.*]) {
                    '{' => {
                        // 读取嵌套字典
                        return @This().readMap(json, index, allocator);
                    },
                    '[' => {
                        // 读取嵌套数组
                        return @This().readArray(json, index, allocator);
                    },
                    '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                        // 读取数字
                        return @This().readNumber(json, index);
                    },
                    't', 'f' => {
                        // 读取布尔值
                        return @This().readBool(json, index);
                    },
                    'n' => {
                        return @This().readNull(json, index);
                    },
                    '"' => {
                        // 读取字符串
                        return @This().readString(json, index);
                    },
                    else => {
                        // 忽略掉无关字符串
                        index.* += 1;
                    },
                }
            }
            return @This(){};
        }

        fn readNumber(json: []const u8, index: *u64) @This() {
            // 读取数字（整数或小数），入口应为 -，0..9，出口应为','、']'或'}'。
            for (json[index.*..]) |c| {
                switch (c) {
                    ']', '}', ',' => {
                        // 若到达出口时仍未遇到小数点，则从人口开始读取整数
                        return @This().readInt(json, index);
                    },
                    '.' => {
                        // 若到达出口前遇到小数点，则从人口开始读取小数
                        return @This().readFloat(json, index);
                    },
                    else => {},
                }
            }
            return @This(){};
        }

        fn readInt(json: []const u8, index: *usize) @This() {
            // 读取整数值，入口应为 -，0..9，出口应为','、']'或'}'。
            var result = @This(){ .type = NodeType.int, .data = NodeValue(intType, floatType){ .int = 0 } };
            var sign = false;
            while (index.* < json.len) {
                switch (json[index.*]) {
                    '-' => {
                        // 记录该整数为负数
                        sign = true;
                    },
                    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                        result.data.int = result.data.int * 10 + (json[index.*] - '0');
                    },
                    ']', '}', ',' => {
                        // 到达出口时添加负号（若为负数）
                        if (sign) {
                            result.data.int = result.data.int * -1;
                        }
                        return result;
                    },
                    else => {},
                }
                index.* += 1;
            }
            return @This(){};
        }

        fn readFloat(json: []const u8, index: *usize) @This() {
            // 读取小数值，入口应为 -，0..9，出口应为','、']'或'}'。
            var result = @This(){ .type = NodeType.float, .data = NodeValue(intType, floatType){ .float = 0.0 } };
            var sign: bool = false;
            var flag: bool = true;
            var point: floatType = 1.0;
            while (index.* < json.len) {
                switch (json[index.*]) {
                    '-' => {
                        sign = true;
                    },
                    '.' => {
                        flag = false;
                    },
                    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => {
                        if (flag) {
                            result.data.float = result.data.float * 10.0 + @as(floatType, @floatFromInt(json[index.*] - '0'));
                        } else {
                            point = point * 0.1;
                            result.data.float = result.data.float + point * @as(floatType, @floatFromInt(json[index.*] - '0'));
                        }
                    },
                    ']', '}', ',' => {
                        if (sign) {
                            result.data.float = result.data.float * -1.0;
                        }
                        return result;
                    },
                    else => {},
                }
                index.* += 1;
            }
            return @This(){};
        }

        fn readBool(json: []const u8, index: *u64) @This() {
            // 读取bool值，入口应为bool值开头（t或者f），出口为bool值的下一个字符。
            var result = @This(){ .type = NodeType.bool, .data = NodeValue(intType, floatType){ .bool = undefined } };
            if (json[index.*] == 't') {
                for ("true") |c| {
                    if (c != json[index.*]) {
                        return @This(){};
                    }
                    index.* += 1;
                }
                result.data.bool = true;
            } else {
                for ("false") |c| {
                    if (c != json[index.*]) {
                        return @This(){};
                    }
                    index.* += 1;
                }
                result.data.bool = false;
            }
            // 忽略值后的无关字符串
            @This()._skipEmpty(json, index);
            return result;
        }

        fn readNull(json: []const u8, index: *u64) @This() {
            // 读取bool值，入口应为null值开头（n），出口为null值的下一个字符。
            for ("null") |c| {
                if (c != json[index.*]) {
                    return @This(){};
                }
                index.* += 1;
            }
            // 忽略值后的无关字符串
            @This()._skipEmpty(json, index);
            return @This(){ .type = NodeType.null, .data = undefined };
        }

        fn _readString(json: []const u8, index: *u64) []const u8 {
            // 读取字符串，入口应为'"'，出口应为'"'。
            var result: []const u8 = "";
            index.* += 1; // 跳过初始'"'
            const start = index.*;
            while (index.* < json.len) {
                switch (json[index.*]) {
                    '"' => {
                        result = json[start..index.*];
                        // 忽略值后的无关字符串
                        @This()._skipEmpty(json, index);
                        return result;
                    },
                    '\\' => {
                        // 忽略转义字符 \"
                        if (index.* < json.len) {
                            index.* += 1;
                        }
                    },
                    else => {},
                }
                index.* += 1;
            }
            return result;
        }

        fn readString(json: []const u8, index: *u64) @This() {
            // 读取字符串，入口应为'"'，出口应为'"'。
            return @This(){ .type = NodeType.string, .data = NodeValue(intType, floatType){ .string = @This()._readString(json, index) } };
        }

        fn _skipEmpty(json: []const u8, index: *u64) void {
            // 忽略值后的无关字符串
            blk: while (index.* < json.len) {
                switch (json[index.*]) {
                    ',', ']', '}', ':' => {
                        break :blk;
                    },
                    else => {
                        index.* += 1;
                    },
                }
            }
            return;
        }

        fn readArray(json: []const u8, index: *u64, allocator: std.mem.Allocator) @This() {
            // 读取字符串，入口应为'['，出口应为']'。
            var result = @This(){ .type = NodeType.array, .data = NodeValue(intType, floatType){ .array = ArrayList(@This()).init(allocator) } };
            index.* += 1; // 跳过初始的'['
            while (index.* < json.len) {
                switch (json[index.*]) {
                    ']' => {
                        index.* += 1; // 跳过该']'
                        // 忽略值后的无关字符串
                        @This()._skipEmpty(json, index);
                        return result;
                    },
                    else => {
                        // 读取数据
                        result.data.array.append(@This().readItem(json, index, allocator)) catch {};
                    },
                }
            }
            // 未找到数组结尾，返回空
            return @This(){};
        }

        fn readMap(json: []const u8, index: *u64, allocator: std.mem.Allocator) @This() {
            // 读取字符串，入口应为'{'，出口应为'}'。
            var result = @This(){ .type = NodeType.map, .data = NodeValue(intType, floatType){ .map = StringHashMap(@This()).init(allocator) } };
            index.* += 1; // 跳过初始'{'
            while (index.* < json.len) {
                switch (json[index.*]) {
                    '}' => {
                        // 到达字典结尾
                        index.* += 1; // 跳过该'}'
                        // 忽略值后的无关字符串
                        @This()._skipEmpty(json, index);
                        return result;
                    },
                    '"' => {
                        // 读取并记录键值对
                        result.data.map.put(@This()._readString(json, index), @This().readItem(json, index, allocator)) catch {};
                    },
                    else => {
                        index.* += 1;
                    },
                }
            }
            // 未找到字典结尾，返回空
            return @This(){};
        }
    };
}

pub fn main() !void {
    const NodeA = Node(i32, f64);

    var index: usize = 0;
    const node: NodeA = NodeA.readInt("123456,", &index);
    std.debug.print("int -> {d}\n", .{node.data.int});
}

test "测试不同结尾下的整数识别" {
    const targets = [_][]const u8{ " 123,", "-123 ]", "0}" };
    const results = [_]i32{ 123, -123, 0 };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets, results) |target, result| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.int);
        try std.testing.expect(node.data.int == result);
    }
}

test "测试不同结尾下的小数识别" {
    const targets = [_][]const u8{ " 123.456,", "-123.456 ]", "0.0}" };
    const results = [_]f64{ 123.456, -123.456, 0.0 };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets, results) |target, result| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.float);
        try std.testing.expect(node.data.float == result);
    }
}

test "测试不同结尾下的布尔值识别" {
    const targets = [_][]const u8{ "true,", "false ]", "true}" };
    const results = [_]bool{ true, false, true };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets, results) |target, result| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.bool);
        try std.testing.expect(node.data.bool == result);
    }
}

test "测试不同结尾下的null识别" {
    const targets = [_][]const u8{ "null,", "null ]", "null}" };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets) |target| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.null);
    }
}

test "测试不同结尾下的字符串识别" {
    const targets = [_][]const u8{ "\"true\",", "\"false\" ]", "\"tr\\\"ue\"}" };
    const results = [_][]const u8{ "true", "false", "tr\\\"ue" };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets, results) |target, result| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.string);
        try std.testing.expectEqualStrings(node.data.string, result);
    }
}

test "测试数组识别" {
    const targets = [_][]const u8{ "[1, 2, 3, 4],", "[5,6,7,8]]", "[9,10,11,12]}" };
    const results = [_][4]i32{ .{ 1, 2, 3, 4 }, .{ 5, 6, 7, 8 }, .{ 9, 10, 11, 12 } };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets, results) |target, result| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.array);
        for (node.data.array.items, result) |tt, rt| {
            try std.testing.expect(tt.data.int == rt);
        }
    }
}

test "测试字典识别" {
    const targets = [_][]const u8{ "{\"a\":1,\"b\":2},", "{\"a\":1,\"b\":2}]", "{\"a\":1,\"b\":2}}" };
    var node: Node(i32, f64) = undefined;
    var index: usize = undefined;
    for (targets) |target| {
        index = 0;
        node = Node(i32, f64).readItem(target, &index, std.heap.page_allocator);
        try std.testing.expect(node.type == NodeType.map);
        try std.testing.expect(node.data.map.get("a").?.data.int == @as(i32, 1));
        try std.testing.expect(node.data.map.get("b").?.data.int == @as(i32, 2));
    }
}

test "测试json字符串" {
    const T = Node(i32, f64);
    const target = "{\"a\":[1, 2.0, false, [3]], \"b\":\"Hello world!\", \"c\":{\"d\":null}}";
    var result = T.readFromString(target, std.heap.page_allocator);
    try std.testing.expect(result.type == NodeType.map);
    const a: T = result.data.map.get("a").?;
    try std.testing.expect(a.data.array.items[0].data.int == 1);
    try std.testing.expect(a.data.array.items[1].data.float == 2.0);
    try std.testing.expect(a.data.array.items[2].data.bool == false);
    try std.testing.expect(a.data.array.items[3].data.array.items[0].data.int == 3);
    const b: T = result.data.map.get("b").?;
    try std.testing.expectEqualStrings(b.data.string, "Hello world!");
    const c: T = result.data.map.get("c").?;
    const cc: T = c.data.map.get("d").?;
    try std.testing.expect(cc.type == NodeType.null);

    result.clearAndFree();
}
