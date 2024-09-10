const delve = @import("delve");
const app = delve.app;
const input = delve.platform.input;
const graphics = delve.platform.graphics;
const spatial = delve.spatial;
const math = delve.math;
const std = @import("std");
const utils = @import("./utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const color = .{
    .background = utils.colorFromInt(0x000000ff),
    .primary = utils.colorFromInt(0x181e2aff),
    .secondary = utils.colorFromInt(0xffffffff),
    .player1 = delve.colors.cyan,
    .player2 = delve.colors.pink,
};

var time: f32 = 0.0;
const width = 1024;
const height = 768;
const paddle_speed: f32 = 7.5;
const player_paddle_height = 150;
const player_paddle_width = 20;
const wall_size = 50;

var shader_default: graphics.Shader = undefined;
const texture_region_default = delve.graphics.sprites.TextureRegion.default();
var sprite_batch: delve.graphics.batcher.SpriteBatcher = undefined;

var player1_paddle = spatial.Rect.fromSize(math.Vec2.new(player_paddle_width, player_paddle_height))
    .setPosition(.{ .x = wall_size, .y = height / 2 - player_paddle_height / 2 });
var player2_paddle = spatial.Rect.fromSize(math.Vec2.new(player_paddle_width, player_paddle_height))
    .setPosition(.{ .x = width - wall_size - player_paddle_width, .y = height / 2 - player_paddle_height / 2 });
const arena = &[_]spatial.Rect{
    spatial.Rect.fromSize(math.Vec2.new(width, wall_size)).setPosition(.{ .x = 0, .y = 0 }),
    spatial.Rect.fromSize(math.Vec2.new(width, wall_size)).setPosition(.{ .x = 0, .y = height - wall_size }),
    spatial.Rect.fromSize(math.Vec2.new(wall_size, height)).setPosition(.{ .x = 0, .y = 0 }),
    spatial.Rect.fromSize(math.Vec2.new(wall_size, height)).setPosition(.{ .x = width - wall_size, .y = 0 }),
};

pub fn main() !void {
    const main_module = delve.modules.Module{
        .name = "main",
        .init_fn = init,
        .tick_fn = tick,
        .draw_fn = draw,
    };

    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        try delve.init(gpa.allocator());
    }

    try delve.modules.registerModule(main_module);

    try app.start(app.AppConfig{
        .title = "zig-pong",
        .width = width,
        .height = height,
        .target_fps = 60,
    });
}

pub fn init() !void {
    sprite_batch = delve.graphics.batcher.SpriteBatcher.init(.{}) catch {
        delve.debug.showErrorScreen("Fatal error during batch init!");
        return;
    };
    shader_default = graphics.Shader.initDefault(.{});
    delve.platform.graphics.setClearColor(color.background);
}

pub fn tick(delta: f32) void {
    time += delta;

    if (input.isKeyJustPressed(.ESCAPE) or input.isKeyJustPressed(.Q)) {
        delve.platform.app.exit();
    }

    if (input.isKeyPressed(.J)) {
        player1_paddle.y += paddle_speed;
    }
    if (input.isKeyPressed(.K)) {
        player1_paddle.y -= paddle_speed;
    }
    if (input.isKeyPressed(.SPACE)) {
        // TODO: Spawn ball.
    }
}

pub fn draw() void {
    sprite_batch.reset();

    sprite_batch.useShader(shader_default);
    sprite_batch.useTexture(graphics.tex_white);

    // Add entities to be rendered.
    for (arena) |entity| {
        sprite_batch.addRectangle(entity, texture_region_default, color.primary);
    }
    sprite_batch.addRectangle(player1_paddle, texture_region_default, color.player1);
    sprite_batch.addRectangle(player2_paddle, texture_region_default, color.player2);

    sprite_batch.apply();

    // Setup view and projection.
    const view = math.Mat4.lookat(
        .{ .x = 0, .y = 0, .z = 1 },
        math.Vec3.zero,
        math.Vec3.up,
    );
    const projection = graphics.getProjectionOrtho(-1, 1, true);

    // Draw sprite batch.
    sprite_batch.draw(.{ .view = view, .proj = projection }, math.Mat4.identity);
}
