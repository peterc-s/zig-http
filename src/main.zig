const std = @import("std");
const network = @import("network");

pub fn main() !void {
    try network.init();
}
