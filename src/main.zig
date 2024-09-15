const delve = @import("delve");
const app = delve.app;
const input = delve.platform.input;
const graphics = delve.platform.graphics;
const spatial = delve.spatial;
const math = delve.math;
const audio = delve.platform.audio;
const std = @import("std");
const physics = @import("./physics.zig");
const utils = @import("./utils.zig");

const Body = struct {
    rect: spatial.Rect,
};

const Text = struct {
    const Self = @This();
    const TextError = error{FontNotLoaded};

    pos: math.Vec2,
    size: u32,
    color: delve.colors.Color,
    font: *delve.fonts.LoadedFont,
    text: []const u8,
    text_fn: ?*const fn () anyerror![]const u8,

    fn init(
        text: []const u8,
        text_fn: ?*const fn () anyerror![]const u8,
        pos: math.Vec2,
        size: u32,
        cl: delve.colors.Color,
        font_name: []const u8,
    ) !Self {
        const loaded_font = delve.fonts.getLoadedFont(font_name);
        if (loaded_font) |font| {
            return Self{
                .pos = pos,
                .size = size,
                .color = cl,
                .font = font,
                .text = text,
                .text_fn = text_fn,
            };
        } else {
            return Self.TextError.FontNotLoaded;
        }
    }

    fn initStatic(
        text: []const u8,
        pos: math.Vec2,
        size: u32,
        cl: delve.colors.Color,
        font_name: []const u8,
    ) !Self {
        return Self.init(text, null, pos, size, cl, font_name);
    }

    fn initDynamic(
        text_fn: *const fn () anyerror![]const u8,
        pos: math.Vec2,
        size: u32,
        cl: delve.colors.Color,
        font_name: []const u8,
    ) !Self {
        return Self.init("", text_fn, pos, size, cl, font_name);
    }

    pub fn getText(self: *const Self) []const u8 {
        if (self.text_fn) |text_fn| {
            return text_fn() catch {
                std.debug.print("Error rendering score to buffer\n", .{});
                return "##";
            };
        } else {
            return self.text;
        }
    }
};

const Entity = struct {
    const Self = @This();

    body: Body,
    physics_body: physics.PhysicsBody,
    color: delve.colors.Color,
    is_circle: bool,
    apply_physics: bool,

    fn init(
        opt_physics_body: ?physics.PhysicsBody,
        rect: spatial.Rect,
        cl: delve.colors.Color,
        is_circle: bool,
    ) Self {
        const has_physics = opt_physics_body != null;
        return Self{
            .body = .{ .rect = rect },
            .physics_body = if (has_physics) opt_physics_body.? else undefined,
            .color = cl,
            .is_circle = is_circle,
            .apply_physics = has_physics,
        };
    }

    pub fn initVisual(rect: spatial.Rect, cl: delve.colors.Color) Self {
        return Self.init(null, rect, cl, false);
    }

    pub fn initStatic(rect: spatial.Rect, cl: delve.colors.Color) Self {
        return Self.init(physics.createStaticBody(rect), rect, cl, false);
    }

    pub fn initDynamic(rect: spatial.Rect, cl: delve.colors.Color) Self {
        return Self.init(physics.createDynamicBody(rect), rect, cl, false);
    }

    pub fn initDynamicCircle(rect: spatial.Rect, cl: delve.colors.Color) Self {
        return Self.init(physics.createBodyCircle(rect), rect, cl, true);
    }

    pub fn initKinetic(rect: spatial.Rect, cl: delve.colors.Color) Self {
        return Self.init(physics.createKineticBody(rect), rect, cl, false);
    }

    // pub fn getQuad(self: *const Self) [4]math.Vec2 {
    //     const body = physics.zb.b2Shape_GetBody(self.physics_body.shape);
    //
    //     const rect = self.getRect();
    //
    //     var verts = [4]math.Vec2{
    //         rect.getBottomLeft(),
    //         rect.getBottomRight(),
    //         rect.getTopRight(),
    //         rect.getTopLeft(),
    //     };
    //
    //     const rotation = physics.zb.b2Body_GetRotation(body);
    //     const sinRotation = rotation.s;
    //     const cosRotation = rotation.c;
    //     const x = rect.x;
    //     const y = rect.y;
    //     const dx = 0;
    //     const dy = 0;
    //
    //     verts[0].x = x + dx * cosRotation - dy * sinRotation;
    //     verts[0].y = y + dx * sinRotation + dy * cosRotation;
    //
    //     verts[1].x = x + (dx + rect.width) * cosRotation - dy * sinRotation;
    //     verts[1].y = y + (dx + rect.width) * sinRotation + dy * cosRotation;
    //
    //     verts[2].x = x + dx * cosRotation - (dy + rect.height) * sinRotation;
    //     verts[2].y = y + dx * sinRotation + (dy + rect.height) * cosRotation;
    //
    //     verts[3].x = x + (dx + rect.width) * cosRotation - (dy + rect.height) * sinRotation;
    //     verts[3].y = y + (dx + rect.width) * sinRotation + (dy + rect.height) * cosRotation;
    //
    //     return verts;
    // }

    pub fn getRect(self: *const Self) spatial.Rect {
        if (self.apply_physics) {
            const size = self.body.rect.getSize();
            const body = physics.zb.b2Shape_GetBody(self.physics_body.shape);
            const pos = physics.zb.b2Body_GetWorldPoint(
                body,
                physics.zb.b2Vec2{ .x = -size.x / 2, .y = -size.y / 2 },
            );

            return spatial.Rect.fromSize(size).setPosition(.{ .x = pos.x, .y = pos.y });
        } else {
            return self.body.rect;
        }
    }

    /// Recturns Rect struct optimized to be passed to the `Batcher.addCricle`
    /// method.
    pub fn getCircleRect(self: *const Self) spatial.Rect {
        const rect = self.getRect();
        return spatial.Rect.new(
            math.Vec2.new(rect.width / 2, rect.height / 2),
            rect.getSize(),
        );
    }

    pub fn getVelocity(self: *const Self) math.Vec2 {
        const vel = physics.zb.b2Body_GetLinearVelocity(self.physics_body.body);
        return .{ .x = vel.x, .y = vel.y };
    }

    pub fn place(self: *const Self, pos: math.Vec2) void {
        const body = self.physics_body.body;
        physics.zb.b2Body_SetTransform(
            body,
            .{ .x = pos.x, .y = pos.y },
            physics.zb.b2Body_GetRotation(body),
        );
    }

    pub fn move(self: *const Self, diff: math.Vec2) void {
        const body = self.physics_body.body;
        physics.zb.b2Body_SetLinearVelocity(body, .{ .x = diff.x, .y = diff.y });
    }

    /// Stop an entity. Basically, reset its linear velocity to zero.
    pub fn stop(self: *const Self) void {
        const body = self.physics_body.body;
        physics.zb.b2Body_SetLinearVelocity(body, .{ .x = 0, .y = 0 });
        physics.zb.b2Body_SetLinearDamping(body, 0);
    }

    /// Freeze an entity's linear velocity to a certain target value.
    pub fn freezeVelocity(self: *const Self, target: f32, aspect_ratio: f32) void {
        const body = self.physics_body.body;
        const velocity = physics.zb.b2Body_GetLinearVelocity(body);
        const vx = @abs(velocity.x);
        const vy = @abs(velocity.y);

        // Leave velocity, if both X and Y are zero.
        if (vx == 0 and vy == 0) {
            return;
        }

        // Initialize corrected velocity based on current velocity.
        var corrected = physics.zb.b2Vec2{ .x = velocity.x, .y = velocity.y };

        // Fix X velocity, if necessary.
        if (vx != target) {
            corrected.x = target * std.math.sign(velocity.x);
        }

        // Fix Y velocity, if necessary.
        // Using the aspect ratio to potentially make target velocity lower than
        // the one of X.
        if (vy != target / aspect_ratio) {
            corrected.y = target / aspect_ratio * std.math.sign(velocity.y);
        }

        // Set corrected velocity.
        physics.zb.b2Body_SetLinearVelocity(body, corrected);
    }
};

/// Game config struct
const Config = struct {
    const Self = @This();

    width: i32,
    height: i32,
    ball_speed: f32,
    ball_size: f32,
    paddle_speed: f32,
    /// Height of the paddle in relation to the height of the playing field.
    paddle_height_percent: f32,
    paddle_width_percent: f32,
    wall_size: f32,
    score_board_size: f32,

    pub fn getWidth(self: *const Self) f32 {
        return @floatFromInt(self.width);
    }

    pub fn getHeight(self: *const Self) f32 {
        return @floatFromInt(self.height);
    }

    pub fn getAspectRatio(self: *const Self) f32 {
        return self.getWidth() / self.getHeight();
    }

    pub fn getPlayWidth(self: *const Self) f32 {
        return self.getWidth() - self.wall_size * 2;
    }

    pub fn getPlayHeight(self: *const Self) f32 {
        return self.getHeight() - self.wall_size + self.score_board_size;
    }

    pub fn getBallSize(self: *const Self) f32 {
        return self.ball_size * self.getPlayWidth() * 0.001;
    }

    pub fn getBallSpeed(self: *const Self) f32 {
        return self.ball_speed * self.getPlayWidth() * 0.1;
    }

    pub fn getPaddleWidth(self: *const Self) f32 {
        return self.getPlayWidth() * self.paddle_width_percent / 100;
    }

    pub fn getPaddleHeight(self: *const Self) f32 {
        return self.getPlayHeight() * self.paddle_height_percent / 100;
    }

    pub fn getPaddleSpeed(self: *const Self) f32 {
        return self.paddle_speed * self.getPlayHeight() * 0.1;
    }
};

/// Game state struct
const State = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    config: Config,
    /// List of renderable entities.
    entities: std.ArrayList(Entity),
    /// List of renderable texts.
    texts: std.ArrayList(Text),
    debug_mode: bool,
    audio_enabled: bool,

    // Pointers to important entities.
    paddle_player1: *Entity,
    paddle_player2: *Entity,
    ball: *Entity,
    player1_score_area: *Entity,
    player2_score_area: *Entity,

    player1_score: u32,
    player1_score_text: []u8,
    player2_score: u32,
    player2_score_text: []u8,
    /// Next serve indicates in which direction the ball will move in the next
    /// round.
    /// Value will be either `1` or `-1`. When moving the ball the X velocity
    /// will be multiplied by this factor.
    /// The initial value is determined randomly.
    next_serve: f32,

    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        const random_next_serve = std.math.sign(std.crypto.random.int(i8));
        return Self{
            .allocator = allocator,
            .config = config,
            .entities = std.ArrayList(Entity).init(allocator),
            .texts = std.ArrayList(Text).init(allocator),
            .debug_mode = false,
            .audio_enabled = true,
            .paddle_player1 = undefined,
            .paddle_player2 = undefined,
            .ball = undefined,
            .player1_score_area = undefined,
            .player2_score_area = undefined,
            .player1_score = 0,
            .player1_score_text = try allocator.alloc(u8, 64),
            .player2_score = 0,
            .player2_score_text = try allocator.alloc(u8, 64),
            .next_serve = if (random_next_serve == 0) 1 else @floatFromInt(random_next_serve),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.player1_score_text);
        self.allocator.free(self.player2_score_text);
        self.entities.deinit();
        self.texts.deinit();
    }

    pub fn addAndReturnEntity(self: *Self, entity: Entity) !*Entity {
        try self.entities.append(entity);
        return &self.entities.items[self.entities.items.len - 1];
    }

    pub fn addEntity(self: *Self, entity: Entity) !void {
        _ = try self.addAndReturnEntity(entity);
    }

    pub fn scorePlayer1(self: *Self) void {
        self.player1_score += 1;
        self.next_serve = -1; // Initiate ball movemnt to left side next round.
    }

    pub fn scorePlayer2(self: *Self) void {
        self.player2_score += 1;
        self.next_serve = 1; // Initiate ball movemnt to right side next round.
    }
};

const color = .{
    .background = utils.colorFromInt(0x000000ff),
    .primary = utils.colorFromInt(0x181e2aff),
    .secondary = utils.colorFromInt(0xffffffff),
    .player1 = delve.colors.cyan,
    .player2 = delve.colors.pink,
};

var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var batcher: delve.graphics.batcher.Batcher = undefined;
var sprite_batcher: delve.graphics.batcher.SpriteBatcher = undefined;
var shader: graphics.Shader = undefined;
var state: State = undefined;

pub fn main() !void {
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // TODO: Ignore memory leaks for now.
    // defer _ = gpa.deinit();

    const main_module = delve.modules.Module{
        .name = "main",
        .init_fn = init,
        .tick_fn = tick,
        .draw_fn = draw,
        .cleanup_fn = cleanup,
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

    try delve.modules.registerModule(physics.module);
    try delve.modules.registerModule(main_module);

    // The scale will scale up the screen size.
    // All other values are dependent on the screen size, so they will be
    // calculated automatically according to the screen size.
    const scale = 2;
    state = try State.init(
        gpa.allocator(),
        .{
            .width = 1024 * scale,
            .height = 768 * scale,
            .ball_speed = 8,
            .ball_size = 14,
            .paddle_speed = 12,
            .paddle_height_percent = 20,
            .paddle_width_percent = 2.5,
            .wall_size = 20 * scale,
            .score_board_size = 60 * scale,
        },
    );

    defer state.deinit();

    try app.start(app.AppConfig{
        .title = "zig-pong",
        .width = state.config.width,
        .height = state.config.height,
        .target_fps = 60,
        .enable_audio = true,
    });
}

fn init() !void {
    batcher = delve.graphics.batcher.Batcher.init(.{}) catch {
        delve.debug.showErrorScreen("Fatal error during batch init!");
        return;
    };
    sprite_batcher = delve.graphics.batcher.SpriteBatcher.init(.{}) catch {
        delve.debug.showErrorScreen("Fatal error during sprite batch init!");
        return;
    };
    // shader = graphics.Shader.initDefault(.{ .blend_mode = graphics.BlendMode.BLEND });
    shader = graphics.Shader.initDefault(.{});
    _ = try delve.fonts.loadFont("default", "assets/fonts/Mecha.ttf", 1024, 200);
    _ = try delve.fonts.loadFont("default_bold", "assets/fonts/Mecha_Bold.ttf", 1024, 200);

    delve.platform.graphics.setClearColor(color.background);

    const config = state.config;
    const width = state.config.getWidth();
    const height = state.config.getHeight();

    // Add arena entites.
    // Top score board
    try state.addEntity(Entity.initStatic(
        spatial.Rect.fromSize(math.Vec2.new(width, config.score_board_size))
            .setPosition(.{ .x = width / 2, .y = config.score_board_size / 2 }),
        color.primary,
    ));
    // Bottom
    try state.addEntity(Entity.initStatic(
        spatial.Rect.fromSize(math.Vec2.new(width, config.wall_size))
            .setPosition(.{ .x = width / 2, .y = height - config.wall_size / 2 }),
        color.primary,
    ));
    // Left wall
    state.player2_score_area = try state.addAndReturnEntity(Entity.initStatic(
        spatial.Rect.fromSize(math.Vec2.new(config.wall_size, height))
            .setPosition(.{ .x = config.wall_size / 2, .y = height / 2 }),
        color.primary,
    ));
    // Right wall
    state.player1_score_area = try state.addAndReturnEntity(Entity.initStatic(
        spatial.Rect.fromSize(math.Vec2.new(config.wall_size, height))
            .setPosition(.{ .x = width - config.wall_size / 2, .y = height / 2 }),
        color.primary,
    ));
    // Field line
    try state.addEntity(Entity.initVisual(
        spatial.Rect.fromSize(math.Vec2.new(10, height))
            .setPosition(.{ .x = width / 2 - 5, .y = 0 }),
        color.primary,
    ));

    // Add player1 paddle entity.
    const player1_paddle = try state.addAndReturnEntity(Entity.initDynamic(
        spatial.Rect.fromSize(math.Vec2.new(config.getPaddleWidth(), config.getPaddleHeight()))
            .setPosition(.{
            .x = config.wall_size + config.getPaddleWidth() / 2,
            .y = height / 2,
        }),
        color.player1,
    ));
    physics.zb.b2Shape_SetDensity(player1_paddle.physics_body.shape, 5);
    physics.zb.b2Shape_SetFriction(player1_paddle.physics_body.shape, 1);
    physics.zb.b2Shape_SetRestitution(player1_paddle.physics_body.shape, 1);
    physics.zb.b2Body_SetFixedRotation(player1_paddle.physics_body.body, true);
    state.paddle_player1 = player1_paddle;

    // Add player2 paddle entity.
    const player2_paddle = try state.addAndReturnEntity(Entity.initDynamic(
        spatial.Rect.fromSize(math.Vec2.new(config.getPaddleWidth(), config.getPaddleHeight()))
            .setPosition(.{
            .x = width - config.wall_size - config.getPaddleWidth() / 2,
            .y = height / 2,
        }),
        color.player2,
    ));
    physics.zb.b2Shape_SetDensity(player2_paddle.physics_body.shape, 5);
    physics.zb.b2Shape_SetFriction(player2_paddle.physics_body.shape, 1);
    physics.zb.b2Shape_SetRestitution(player2_paddle.physics_body.shape, 1);
    physics.zb.b2Body_SetFixedRotation(player2_paddle.physics_body.body, true);
    state.paddle_player2 = player2_paddle;

    // Add ball entity.
    const ball = try state.addAndReturnEntity(Entity.initDynamic(
        spatial.Rect.fromSize(math.Vec2.new(config.getBallSize(), config.getBallSize()))
            .setPosition(.{
            .x = width / 2,
            .y = height / 2,
        }),
        color.secondary,
    ));
    // NOTE: To render the ball as an actual ball, uncomment the following line:
    // ball.is_circle = true;
    physics.zb.b2Body_SetFixedRotation(ball.physics_body.body, true);
    physics.zb.b2Body_SetBullet(ball.physics_body.body, true);
    physics.zb.b2Body_SetLinearDamping(ball.physics_body.body, 0);
    physics.zb.b2Shape_SetFriction(ball.physics_body.shape, 0);
    physics.zb.b2Shape_SetDensity(ball.physics_body.shape, 1);
    physics.zb.b2Shape_SetRestitution(ball.physics_body.shape, 1);
    ball.stop();
    state.ball = ball;

    // Add scoreboard text.
    {
        const font_size = 64;
        const text_width = font_size / 2 * 2;
        const pos_y = (state.config.score_board_size - font_size) / 2;
        const offset = 180;

        try state.texts.append(try Text.initDynamic(
            player1ScoreText,
            math.Vec2.new(state.config.getWidth() / 2 - text_width - offset, pos_y),
            font_size,
            color.player1,
            "default_bold",
        ));

        try state.texts.append(try Text.initDynamic(
            player2ScoreText,
            math.Vec2.new(state.config.getWidth() / 2 + offset, pos_y),
            font_size,
            color.player2,
            "default_bold",
        ));
    }
}

fn player1ScoreText() ![]const u8 {
    _ = try std.fmt.bufPrint(state.player1_score_text, "{d:0>2}", .{state.player1_score});
    return state.player1_score_text;
}

fn player2ScoreText() ![]const u8 {
    _ = try std.fmt.bufPrint(state.player2_score_text, "{d:0>2}", .{state.player2_score});
    return state.player2_score_text;
}

fn cleanup() !void {
    shader.destroy();
    sprite_batcher.deinit();
    batcher.deinit();
}

fn tick(_: f32) void {
    // Quit game.
    if (input.isKeyJustPressed(.ESCAPE) or input.isKeyJustPressed(.Q)) {
        delve.platform.app.exit();
    }

    // Toggle debug mode.
    if (input.isKeyJustPressed(.F1)) {
        state.debug_mode = !state.debug_mode;
    }

    // Toggle audio.
    if (input.isKeyJustPressed(.F2)) {
        state.audio_enabled = !state.audio_enabled;
    }

    const config = state.config;

    // Reset paddle velocities.
    state.paddle_player1.stop();
    state.paddle_player2.stop();
    // Make sure, the ball moves at constant speed.
    state.ball.freezeVelocity(config.getBallSpeed(), config.getAspectRatio());

    // Move player 1 paddle.
    if (input.isKeyPressed(.J) or input.isKeyPressed(.DOWN)) {
        state.paddle_player1.move(.{ .x = 0, .y = config.getPaddleSpeed() });
    }
    if (input.isKeyPressed(.K) or input.isKeyPressed(.UP)) {
        state.paddle_player1.move(.{ .x = 0, .y = -config.getPaddleSpeed() });
    }

    updateEnemyPaddle();
    updateScore();

    // Reset game.
    if (input.isKeyJustPressed(.R)) {
        reset();
    }

    // Start game.
    if (input.isKeyJustPressed(.SPACE)) {
        reset();
        // Initiate ball movement.
        state.ball.move(.{
            .x = config.getBallSpeed() * state.next_serve,
            .y = 0,
        });
    }
}

fn draw() void {
    const texture_region = delve.graphics.sprites.TextureRegion.default();
    // Setup view and projection for a 2D environment.
    const view = math.Mat4.lookat(
        .{ .x = 0, .y = 0, .z = 1 },
        math.Vec3.zero,
        math.Vec3.up,
    );
    const projection = graphics.getProjectionOrtho(-1, 1, true);
    const camera = delve.platform.graphics.CameraMatrices{ .view = view, .proj = projection };
    const camera_fonts = delve.platform.graphics.CameraMatrices{
        .view = view,
        .proj = graphics.getProjectionOrtho(-1, 1, false),
    };

    batcher.reset();
    sprite_batcher.reset();
    sprite_batcher.useShader(shader);

    // Add entities to be rendered.
    for (state.entities.items) |entity| {
        if (entity.is_circle) {
            const rect = entity.getRect();
            const pos = rect.getPosition();
            batcher.addCircle(
                pos.add(math.Vec2.new(rect.width / 2, rect.height / 2)),
                rect.width / 2,
                12,
                texture_region,
                entity.color,
            );
        } else {
            batcher.addRectangle(entity.getRect(), texture_region, entity.color);
        }
    }

    // Render debug information for entities and texts.
    if (state.debug_mode) {
        for (state.entities.items) |entity| {
            batcher.addCircle(entity.getRect().getPosition(), 4, 12, texture_region, delve.colors.red);
        }
        for (state.texts.items) |text| {
            batcher.addCircle(text.pos, 4, 12, texture_region, delve.colors.blue);
            // sprite_batcher.addRectangle(spatial.Rect.fromSize(.{ .x = 10, .y = 10 }).setPosition(text.pos), texture_region, delve.colors.blue);
        }
    }

    for (state.texts.items) |text| {
        const font_size = @as(f32, @floatFromInt(text.size));
        const scale = font_size / text.font.font_size;
        var x_pos = text.pos.x / scale;
        // TODO:
        // Weird gymnastics that I need to do, because the Y-axis of
        // `camera_fonts` projection is not flipped.
        var y_pos = (-state.config.getHeight() + text.pos.y + font_size) / scale - font_size / 2;
        delve.fonts.addStringToSpriteBatch(
            text.font,
            &sprite_batcher,
            text.getText(),
            &x_pos,
            &y_pos,
            scale,
            text.color,
        );
    }

    batcher.apply();
    batcher.draw(camera, math.Mat4.identity);
    sprite_batcher.apply();
    sprite_batcher.draw(camera_fonts, math.Mat4.identity);
}

fn reset() void {
    // Stop ball and reset its position to center.
    state.ball.stop();
    state.ball.place(.{
        .x = state.config.getWidth() / 2,
        .y = state.config.getHeight() / 2,
    });
    // Stop players and reset their position.
    state.paddle_player1.stop();
    state.paddle_player1.place(.{
        .x = state.config.wall_size + state.config.getPaddleWidth() / 2,
        .y = state.config.getHeight() / 2,
    });
    state.paddle_player2.stop();
    state.paddle_player2.place(.{
        .x = state.config.getWidth() - state.config.wall_size - state.config.getPaddleWidth() / 2,
        .y = state.config.getHeight() / 2,
    });
}

/// Update player scores.
/// Check which shapes are colliding in the current frame and update scores
/// accordingly.
fn updateScore() void {
    const contact_events = physics.zb.b2World_GetContactEvents(physics.world);
    for (0..@intCast(contact_events.beginCount)) |i| {
        const event = contact_events.beginEvents[i];
        if (physics.zb.B2_ID_EQUALS(event.shapeIdA, state.ball.physics_body.shape) or
            physics.zb.B2_ID_EQUALS(event.shapeIdB, state.ball.physics_body.shape))
        {
            // Player 1 scored.
            if (physics.zb.B2_ID_EQUALS(event.shapeIdA, state.player1_score_area.physics_body.shape) or
                physics.zb.B2_ID_EQUALS(event.shapeIdB, state.player1_score_area.physics_body.shape))
            {
                state.scorePlayer1();
                reset();
                playSound("assets/score.wav");
            }
            // Player 2 scored.
            else if (physics.zb.B2_ID_EQUALS(event.shapeIdA, state.player2_score_area.physics_body.shape) or
                physics.zb.B2_ID_EQUALS(event.shapeIdB, state.player2_score_area.physics_body.shape))
            {
                state.scorePlayer2();
                reset();
                playSound("assets/score.wav");
            } else {
                const vel = state.ball.getVelocity();
                var paddle = event.shapeIdA;
                if (physics.zb.B2_ID_EQUALS(event.shapeIdA, state.ball.physics_body.shape)) {
                    paddle = event.shapeIdB;
                }
                const paddle_vel = physics.zb.b2Body_GetLinearVelocity(physics.zb.b2Shape_GetBody(paddle));

                // Initiate Y velocity on ball, when ball collides the first time.
                if (vel.y == 0) {
                    var factor = std.math.sign(paddle_vel.y);
                    if (paddle_vel.y == 0) {
                        factor = @floatFromInt(std.math.sign(std.crypto.random.int(i8)));
                    }

                    state.ball.move(.{ .x = vel.x, .y = state.config.ball_speed * factor });
                }
                // Make paddle velocity influence the ball velocity.
                else if (paddle_vel.y != 0 and std.math.sign(vel.y) != std.math.sign(paddle_vel.y)) {
                    state.ball.move(.{ .x = vel.x, .y = vel.y * -1 });
                }
                playSound("assets/hit.wav");
            }
        }
    }
}

/// Basic AI for enemy paddle (Player 2)
fn updateEnemyPaddle() void {
    // Ball: Add half sizes to position to get center point.
    const ball_rect = state.ball.getRect();
    const ball_pos = ball_rect.getPosition().add(ball_rect.getSize().scale(0.5));

    // Paddle: Add half sizes to position to get center point.
    const paddle_rect = state.paddle_player2.getRect();
    const paddle_pos = paddle_rect.getPosition().add(paddle_rect.getSize().scale(0.5));

    const delta = paddle_pos.sub(ball_pos);
    const ttc = delta.x / state.config.getBallSpeed(); // ttc = Time To Collide (on X axis).
    const threshold = paddle_rect.height / 2 * ttc;
    const normalized_speed = @min(state.config.getPaddleSpeed(), @abs(delta.y) / ttc);
    // TODO: First attempt to make AI less perfect.
    const randomized_speed = @max(0.7, std.crypto.random.float(f32)) * normalized_speed;

    if (state.ball.getVelocity().x > 0 and ttc < 1) {
        if (ball_pos.y > paddle_pos.y + threshold) {
            state.paddle_player2.move(.{ .x = 0, .y = randomized_speed });
        } else if (ball_pos.y < paddle_pos.y - threshold) {
            state.paddle_player2.move(.{ .x = 0, .y = -randomized_speed });
        }
    }
}

fn playSound(path: [:0]const u8) void {
    if (state.audio_enabled) {
        _ = audio.playSound(path, 1);
    }
}
