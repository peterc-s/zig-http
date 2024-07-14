const std = @import("std");
const network = @import("network");

const BUF_SIZE = 1000;

pub fn main() !void {
    try network.init();
    defer network.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    const exe_name = args_iter.next() orelse return error.MissingArgument;
    defer allocator.free(exe_name);

    const port_num = 8080;

    var sock = try network.Socket.create(.ipv4, .tcp);
    defer sock.close();

    try sock.bindToPort(port_num);

    try sock.listen();

    while (true) {
        var client = try sock.accept();
        defer client.close();

        std.debug.print("Client connected: {any}.\n", .{try client.getLocalEndPoint()});

        echoClient(client) catch |err| {
            std.debug.print("Client {any} disconnect: {any}", .{
                try client.getLocalEndPoint(),
                @errorName(err),
            });
            continue;
        };

        std.debug.print("Client {any} disconnected.\n", .{try client.getLocalEndPoint()});
    }
}

fn echoClient(client: network.Socket) !void {
    while (true) {
        var buf: [BUF_SIZE]u8 = undefined;

        const len = try client.receive(&buf);

        if (len == 0) break;

        const str = std.mem.sliceTo(buf[0..], 0);

        std.debug.print("{s}\n", .{str});
    }
}
