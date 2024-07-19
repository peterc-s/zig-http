const std = @import("std");

/// Defines a MIME type typle.
pub const MIMEType = std.meta.Tuple(&[_]type{ []const u8, []const u8 });

/// Defines the MIME types as a slice of MIMEType tuples.
const MIMETypes: []const MIMEType = &[_]MIMEType{
    // give empty string plain type to stop 415 and instead 404 in
    // specific case with files that don't have an extension
    .{ "", "text/plain" },
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
    .{ ".xml", "application/xml" },
    .{ ".xul", "application/vnd.mozilla.xul+xml" },
    .{ ".zip", "application/zip" },
    .{ ".7z", "application/x-7z-compressed" },
    .{ ".aac", "audio/aac" },
    .{ ".abw", "application/x-abiword" },
};

/// A StringHashMap containing all the elements of MIMETypes.
var MIMETypesMap = std.StringHashMap([]const u8).init(std.heap.page_allocator);
var map_populated = false;

/// Populates the MIMETypesMap StringHashMap.
/// (Would ideally be done at compile time, but I can't find
/// a way to do that).
fn populate_MIME_map() void {
    for (MIMETypes) |entry| {
        MIMETypesMap.put(entry[0], entry[1]) catch unreachable;
    }
    map_populated = true;
}

/// Gets the MIME type of the file with the specified path.
pub fn get_type(path: []const u8) ?[]const u8 {
    if (!map_populated) {
        populate_MIME_map();
    }

    const extension = std.fs.path.extension(path);
    return MIMETypesMap.get(extension);
}
