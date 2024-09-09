const Color = @import("delve").colors.Color;

pub fn colorFromInt(value: u32) Color {
    const r_byte: u32 = (value & 0xFF000000) >> 24;
    const g_byte: u32 = (value & 0x00FF0000) >> 16;
    const b_byte: u32 = (value & 0x0000FF00) >> 8;
    const a_byte: u32 = (value & 0x000000FF);

    const r: f32 = @as(f32, @floatFromInt(r_byte)) / 255.0;
    const g: f32 = @as(f32, @floatFromInt(g_byte)) / 255.0;
    const b: f32 = @as(f32, @floatFromInt(b_byte)) / 255.0;
    const a: f32 = @as(f32, @floatFromInt(a_byte)) / 255.0;

    return Color.new(r, g, b, a);
}
