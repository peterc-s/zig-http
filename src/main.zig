const std = @import("std");
const network = @import("network");
const String = @import("string").String;

const BUF_SIZE = 1024;

/// Enum of HTTP status codes.
const Status = enum(u16) {
    OK = 200,
    NOT_FOUND = 404,
    UNSUPPORTED_MEDIA_TYPE = 415,
    INTERNAL_SERVER_ERROR = 500,
    NOT_IMPLEMENTED = 501,

    /// Compiles a response line for the given status.
    fn response_line(self: Status) ![]u8 {
        const allocator = std.heap.page_allocator;

        const http_prefix = "HTTP/1.1";
        const status_str = switch (self) {
            Status.OK => "200 OK",
            Status.NOT_FOUND => "404 Not Found",
            Status.UNSUPPORTED_MEDIA_TYPE => "415 Unsupported Media Type",
            Status.INTERNAL_SERVER_ERROR => "500 Internal Server Error",
            Status.NOT_IMPLEMENTED => "501 Not Implemented",
        };

        const result = try std.fmt.allocPrint(allocator, "{s} {s}\r\n", .{ http_prefix, status_str });

        return result;
    }
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

/// Defines a MIME type typle.
const MIMEType = std.meta.Tuple(&[_]type{ []const u8, []const u8 });
/// Defines the MIME types as a slice of MIMEType tuples.
const MIMETypes: []const MIMEType = &[_]MIMEType{
    .{ ".aac", "audio/aac" },
    .{ ".abw", "application/x-abiword" },
    .{ ".apng", "image/apng" },
    .{ ".arc", "application/x-freearc" },
    .{ ".avif", "image/avif" },
    .{ ".avi", "video/x-msvideo" },
    .{ ".azw", "application/vnd.amazon.ebook" },
    .{ ".bin", "application/octet-stream" },
    .{ ".bmp", "image/bmp" },
    .{ ".bz", "application/x-bzip" },
    .{ ".bz2", "application/x-bzip2" },
    .{ ".cda", "application/x-cdf" },
    .{ ".csh", "application/x-csh" },
    .{ ".css", "text/css" },
    .{ ".csv", "text/csv" },
    .{ ".doc", "application/msword" },
    .{ ".docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document" },
    .{ ".eot", "application/vnd.ms-fontobject" },
    .{ ".epub", "application/epub+zip" },
    .{ ".gz", "application/gzip" },
    .{ ".gif", "image/gif" },
    .{ ".htm", "text/html" },
    .{ ".html", "text/html" },
    .{ ".ico", "image/vnd.microsoft.icon" },
    .{ ".ics", "text/calendar" },
    .{ ".jar", "application/java-archive" },
    .{ ".jpg", "image/jpeg" },
    .{ ".jpeg", "image/jpeg" },
    .{ ".js", "text/javascript " },
    .{ ".json", "application/json" },
    .{ ".jsonld", "application/ld+json" },
    .{ ".midi", "audio/midi, audio/midi" },
    .{ ".mid", "audio/midi, audio/x-midi" },
    .{ ".mjs", "text/javascript" },
    .{ ".mp3", "audio/mpeg" },
    .{ ".mp4", "video/mp4" },
    .{ ".mpeg", "video/mpeg" },
    .{ ".mpkg", "application/vnd.apple.installer+xml" },
    .{ ".odp", "application/vnd.oasis.opendocument.presentation" },
    .{ ".ods", "application/vnd.oasis.opendocument.spreadsheet" },
    .{ ".odt", "application/vnd.oasis.opendocument.text" },
    .{ ".oga", "audio/ogg" },
    .{ ".ogv", "video/ogg" },
    .{ ".ogx", "application/ogg" },
    .{ ".opus", "audio/ogg" },
    .{ ".otf", "font/otf" },
    .{ ".png", "image/png" },
    .{ ".pdf", "application/pdf" },
    .{ ".php", "application/x-httpd-php" },
    .{ ".ppt", "application/vnd.ms-powerpoint" },
    .{ ".pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation" },
    .{ ".rar", "application/vnd.rar" },
    .{ ".rtf", "application/rtf" },
    .{ ".sh", "application/x-sh" },
    .{ ".svg", "image/svg+xml" },
    .{ ".tar", "application/x-tar" },
    .{ ".tif", "image/tiff" },
    .{ ".tiff", "image/tiff" },
    .{ ".ts", "video/mp2t" },
    .{ ".ttf", "font/ttf" },
    .{ ".txt", "text/plain" },
    .{ ".vsd", "application/vnd.visio" },
    .{ ".wav", "audio/wav" },
    .{ ".weba", "audio/webm" },
    .{ ".webm", "video/webm" },
    .{ ".webp", "image/webp" },
    .{ ".woff", "font/woff" },
    .{ ".woff2", "font/woff2" },
    .{ ".xhtml", "application/xhtml+xml" },
    .{ ".xls", "application/vnd.ms-excel" },
    .{ ".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" },
    .{ ".xml", "application/xml  For instance, an Atom feed is application/atom+xml, but application/xml serves as a valid default." },
    .{ ".xul", "application/vnd.mozilla.xul+xml" },
    .{ ".zip", "application/zip is the standard, but beware that Windows uploads .zip with MIME type application/x-zip-compressed." },
    .{ ".7z", "application/x-7z-compressed" },
    .{ ".aac", "audio/aac" },
    .{ ".abw", "application/x-abiword" },
};

/// A StringHashMap containing all the elements of MIMETypes, should be populated before use.
var MIMETypesMap = std.StringHashMap([]const u8).init(std.heap.page_allocator);

/// Populates the MIMETypesMap StringHashMap.
/// (Would ideally be done at compile time, but I can't find
/// a way to do that).
fn populate_MIME_map() void {
    for (MIMETypes) |entry| {
        MIMETypesMap.put(entry[0], entry[1]) catch unreachable;
    }
}

/// Defines a header tuple.
const Header = std.meta.Tuple(&[_]type{ []const u8, []const u8 });

/// Contains methods for running a HTTP server
/// on a specified port.
const HTTPServer = struct {
    /// The port to run the server on.
    port: u16 = 8080,
    /// The headers currently being sent with responses.
    headers: std.ArrayList(Header) = undefined,

    /// Initialises a server struct with the specified port.
    pub fn init(port: u16) HTTPServer {
        var server = HTTPServer{};

        if (port == undefined) {
            server.port = 8080;
        } else {
            server.port = port;
        }

        server.headers = std.ArrayList(Header).init(std.heap.page_allocator);

        return server;
    }

    pub fn deinit(self: HTTPServer) void {
        self.headers.deinit();
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

    /// Formats a response with the given string slices.
    fn format_response(response_line: []u8, headers_str: []u8, response_body: []u8) ![]u8 {
        return try std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}\r\n{s}", .{ response_line, headers_str, response_body });
    }

    /// Handles a GET request.
    fn handle_GET(self: HTTPServer, client: network.Socket, config: Config) !void {
        std.debug.print("Found GET from {any}: \n{any}\n", .{ client.getLocalEndPoint(), config });
        std.debug.print("Get file: {s}\n", .{config.uri});

        const allocator = std.heap.page_allocator;

        var response_line: []u8 = undefined;
        var response_body: []u8 = undefined;
        var headers_str: []u8 = undefined;

        // check if file is of supported type
        if (MIMETypesMap.get(std.fs.path.extension(config.uri))) |mime_type| {
            // read the file from the uri
            const file_content = read_file(allocator, config.uri);

            if (file_content) |result| {
                response_line = try Status.OK.response_line();
                response_body = result;
                headers_str = try self.get_headers_str(&[_]Header{.{ "Content-Type", mime_type }});
            } else |err| {
                response_line = switch (err) {
                    std.fs.File.OpenError.FileNotFound => try Status.NOT_FOUND.response_line(),
                    else => try Status.INTERNAL_SERVER_ERROR.response_line(),
                };
                response_body = &[_]u8{};
                headers_str = try self.get_headers_str(&[_]Header{});
            }
        } else {
            response_line = try Status.UNSUPPORTED_MEDIA_TYPE.response_line();
            headers_str = try self.get_headers_str(&[_]Header{.{ "Content-Type", "text/html" }});
            response_body = &[_]u8{};
        }

        const response = try format_response(response_line, headers_str, response_body);

        defer allocator.free(response_body);

        _ = try client.send(response);

        std.debug.print("Sending response: \n{s}\n", .{response});
    }

    /// Reads a file and outputs it's contents.
    fn read_file(allocator: std.mem.Allocator, relative_path: []const u8) ![]u8 {
        const open_flags = std.fs.File.OpenFlags{
            .mode = .read_only,
        };

        const file = try std.fs.cwd().openFile(relative_path[1..], open_flags);

        const max_size = std.math.maxInt(usize);
        const data = try file.readToEndAlloc(allocator, max_size);

        return data;
    }

    /// Gets the file's MIME type.
    fn get_MIME_type(path: []const u8) ?[]const u8 {
        const extension = std.fs.path.extension(path);
        return MIMETypesMap.get(extension);
    }

    /// Handles a bad request
    fn handle_unknown(self: HTTPServer, client: network.Socket, config: Config) !void {
        //todo
        std.debug.print("Unknown from {any}: \n{any}\n", .{ client.endpoint, config });

        const response_line = try Status.NOT_IMPLEMENTED.response_line();
        const headers_str = try self.get_headers_str(&[_]Header{});

        const response = try format_response(response_line, headers_str, "");

        _ = try client.send(response);

        std.debug.print("Sending response: \n{s}\n", .{response});
    }

    /// Adds or modifies a header, just a wrapper around self.headers.append.
    pub fn add_header(self: *HTTPServer, key: []const u8, value: []const u8) !void {
        try self.headers.append(.{ key, value });
    }

    /// Compiles a string of the headers in the correct format for a HTTP
    /// response.
    fn get_headers_str(self: HTTPServer, extra_headers: []const Header) ![]u8 {
        var headers_str = std.ArrayList(u8).init(std.heap.page_allocator);
        defer headers_str.deinit();

        for (self.headers.items) |entry| {
            try headers_str.appendSlice(entry[0]);
            try headers_str.appendSlice(": ");
            try headers_str.appendSlice(entry[1]);
            try headers_str.appendSlice("\r\n");
        }

        for (extra_headers) |entry| {
            try headers_str.appendSlice(entry[0]);
            try headers_str.appendSlice(": ");
            try headers_str.appendSlice(entry[1]);
            try headers_str.appendSlice("\r\n");
        }

        return try headers_str.toOwnedSlice();
    }
};

pub fn main() !void {
    // populate MIME hashmap.
    populate_MIME_map();
    // check that at least HTML was added correctly,
    // likelihood is the rest of the hashmap was populated
    // correctly too.
    std.debug.assert(std.mem.eql(u8, MIMETypesMap.get(".html").?, "text/html"));

    try network.init();
    defer network.deinit();

    var serv = HTTPServer.init(8080);
    defer serv.deinit();

    try serv.add_header("Server", "zig-http");
    try serv.add_header("Content-Type", "text/html");

    try serv.start();
}
