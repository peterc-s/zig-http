const std = @import("std");
const network = @import("network");

const BUF_SIZE = 1024;

/// Enum of HTTP status codes.
const Status = enum {
    /// 200
    OK,
    /// 404
    NOT_FOUND,
    /// 501
    NOT_IMPLEMENTED,
};

/// Contains methods for running a HTTP server
/// on a specified port.
const HTTPServer = struct {
    /// The port to run the server on.
    port: u16 = 8080,
    /// The headers currently being sent with responses.
    headers: std.StringHashMap([]u8),

    /// Initialises a server struct with the specified port.
    pub fn init(port: u16) HTTPServer {
        var _port = port;
        if (_port == undefined) {
            _port = 8080;
        }

        const headers = std.StringHashMap([]u8).init(std.heap.page_allocator);

        return HTTPServer{
            .port = _port,
            .headers = headers,
        };
    }

    /// Starts running the server.
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

            try self.handle_request(client, &recv_buf);
        }
    }

    /// Handle an incoming request from a client
    fn handle_request(self: HTTPServer, client: network.Socket, data: []u8) !void {
        std.debug.print("{s}\n", .{std.mem.sliceTo(data[0..], 0)});

        const allocator = std.heap.page_allocator;

        const response_line = try get_response_line(Status.OK);

        const headers = try self.get_headers_str();

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

    /// Adds or modifies a header, just a wrapper around self.headers.put().
    pub fn addHeader(self: *HTTPServer, key: []const u8, value: []const u8) !void {
        try self.headers.put(key, @constCast(value));
    }

    /// Compiles a string of the headers in the correct format for a HTTP
    /// response.
    pub fn get_headers_str(self: HTTPServer) ![]u8 {
        var iter = self.headers.iterator();
        var headers_str = std.ArrayList(u8).init(std.heap.page_allocator);
        defer headers_str.deinit();

        while (iter.next()) |entry| {
            try headers_str.appendSlice(entry.key_ptr.*);
            try headers_str.appendSlice(": ");
            try headers_str.appendSlice(entry.value_ptr.*);
            try headers_str.appendSlice("\r\n");
        }

        return try headers_str.toOwnedSlice();
    }

    /// Compiles a response line for the given status.
    fn get_response_line(status: Status) ![]u8 {
        const allocator = std.heap.page_allocator;

        const http_prefix = "HTTP/1.1";
        const status_str = switch (status) {
            Status.OK => "200 OK",
            Status.NOT_FOUND => "404 Not Found",
            Status.NOT_IMPLEMENTED => "501 Not Implemented",
        };

        const response_line = try std.fmt.allocPrint(allocator, "{s} {s}\r\n", .{ http_prefix, status_str });

        return response_line;
    }
};

pub fn main() !void {
    try network.init();
    defer network.deinit();

    var serv = HTTPServer.init(8080);

    try serv.addHeader("Server", "zig-http");
    try serv.addHeader("Content-Type", "text/html");

    try serv.start();
}
