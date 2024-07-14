const std = @import("std");
const network = @import("network");

const BUF_SIZE = 1024;

const Status = enum {
    OK,
    NOT_FOUND,
};

const HTTPServer = struct {
    port: u16 = 8080,
    headers: []u8 = "",

    pub fn start(self: HTTPServer) !void {
        var sock = try network.Socket.create(.ipv4, .tcp);
        defer sock.close();

        try sock.bindToPort(self.port);

        try sock.listen();

        while (true) {
            var client = try sock.accept();
            defer client.close();

            std.debug.print("Client connected: {any}.\n", .{try client.getLocalEndPoint()});

            var recv_buf: [BUF_SIZE]u8 = undefined;
            const len = try client.receive(&recv_buf);

            if (len == 0) continue;

            try handle_request(client, &recv_buf);
        }
    }

    fn handle_request(client: network.Socket, data: []u8) !void {
        std.debug.print("{s}\n", .{std.mem.sliceTo(data[0..], 0)});

        const allocator = std.heap.page_allocator;

        const response_line = try get_response_line(Status.OK);

        const headers =
            \\Server: zig-http
            \\Content-Type: text/html
        ;

        const response_body =
            \\<html>
            \\<body>
            \\<h1>Request Received!</h1>
            \\</body>
            \\</html>
        ;

        const response = try std.fmt.allocPrint(allocator, "{s}{s}\r\n\r\n{s}", .{ response_line, headers, response_body });

        _ = try client.send(response);

        std.debug.print("Sending response: \n{s}\n", .{response});
    }

    fn get_response_line(status: Status) ![]u8 {
        const allocator = std.heap.page_allocator;

        const http_prefix = "HTTP/1.1";
        const status_str = switch (status) {
            Status.OK => "200 OK",
            Status.NOT_FOUND => "404 Not Found",
        };

        const response_line = try std.fmt.allocPrint(allocator, "{s} {s}\r\n", .{ http_prefix, status_str });

        return response_line;
    }
};

pub fn main() !void {
    try network.init();
    defer network.deinit();

    const serv = HTTPServer{};
    try serv.start();
}
