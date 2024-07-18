const std = @import("std");
const network = @import("network");
const String = @import("string").String;

const BUF_SIZE = 1024;

/// Enum of HTTP status codes.
const Status = enum(u16) {
    OK = 200,
    NOT_FOUND = 404,
    NOT_IMPLEMENTED = 501,
};

/// Enum of supported HTTP methods.
const Method = enum {
    GET,
    /// For any time there either isn't a method or it isn't supported.
    UNKNOWN,
};

/// Defines the current config for a response.
const Config = struct {
    method: Method = Method.UNKNOWN,
    uri: []const u8 = "",
    http_vers: []const u8 = "HTTP/1.1",
};

/// Contains methods for running a HTTP server
/// on a specified port.
const HTTPServer = struct {
    /// The port to run the server on.
    port: u16 = 8080,
    /// The headers currently being sent with responses.
    headers: std.StringHashMap([]u8) = undefined,

    /// Initialises a server struct with the specified port.
    pub fn init(port: u16) HTTPServer {
        var server = HTTPServer{};

        if (port == undefined) {
            server.port = 8080;
        } else {
            server.port = port;
        }

        server.headers = std.StringHashMap([]u8).init(std.heap.page_allocator);

        return server;
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

    /// Parses a request.
    fn parse(data: []u8) !Config {
        var data_str = try String.init_with_contents(std.heap.page_allocator, data);

        const lines_arr = try data_str.lines();
        const request_line = lines_arr[0];
        const words = try request_line.splitAll(" ");

        var config = Config{};
        config.method = parse_method(words[0]);

        if (words.len > 1) {
            config.uri = words[1];
        }

        if (words.len > 2) {
            config.http_vers = words[2];
        }

        return config;
    }

    /// Parses a method slice into a variant of the Method enum.
    fn parse_method(method_str: []const u8) Method {
        if (std.mem.eql(u8, method_str, "GET")) {
            return Method.GET;
        } else {
            return Method.UNKNOWN;
        }
    }

    /// DEBUG: Print each line in a []String separately and numbered.
    fn print_lines(str_arr: []String) !void {
        for (str_arr, 0..) |line, index| {
            std.debug.print("Line {d}: {s}\n", .{ index, line.str() });
        }
    }

    /// Handle an incoming request from a client
    fn handle_request(self: HTTPServer, client: network.Socket, data: []u8) !void {
        const config = try parse(data);

        // check if method is supported or not and give
        // appropriate response
        _ = switch (config.method) {
            Method.GET => try self.handle_GET(client, config),
            Method.UNKNOWN => try self.handle_unknown(client, config),
        };
    }

    fn format_response(response_line: []u8, headers_str: []u8, response_body: []u8) ![]u8 {
        return try std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}\r\n{s}", .{ response_line, headers_str, response_body });
    }

    /// Handles a GET request.
    fn handle_GET(self: HTTPServer, client: network.Socket, config: Config) !void {
        std.debug.print("Found GET from {any}: \n{any}\n", .{ client.endpoint, config });

        const response_line = try get_response_line(Status.OK);
        const headers_str = try self.get_headers_str();

        // todo: actually get the text from file
        const response_body =
            \\<html>
            \\<body>
            \\<h1>Request Received!</h1>
            \\</body>
            \\</html>
        ;

        const response = try format_response(response_line, headers_str, @constCast(response_body));

        _ = try client.send(response);

        std.debug.print("Sending response: \n{s}\n", .{response});
    }

    /// Handles a bad request
    fn handle_unknown(self: HTTPServer, client: network.Socket, config: Config) !void {
        //todo
        std.debug.print("Unknown from {any}: \n{any}\n", .{ client.endpoint, config });

        const response_line = try get_response_line(Status.NOT_IMPLEMENTED);
        const headers_str = try self.get_headers_str();

        const response = try format_response(response_line, headers_str, "");

        _ = try client.send(response);

        std.debug.print("Sending response: \n{s}\n", .{response});
    }

    /// Adds or modifies a header, just a wrapper around self.headers.put().
    pub fn add_header(self: *HTTPServer, key: []const u8, value: []const u8) !void {
        try self.headers.put(key, @constCast(value));
    }

    /// Removes a header with specified key.
    pub fn remove_header(self: *HTTPServer, key: []const u8) bool {
        return self.headers.remove(key);
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

    try serv.add_header("Server", "zig-http");
    try serv.add_header("Content-Type", "text/html");

    try serv.start();
}
