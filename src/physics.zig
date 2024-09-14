const std = @import("std");
const delve = @import("delve");
pub const zb = @import("zbox2d");

pub const PhysicsConfig = struct {
    time_step: f32,
    sub_step_count: u32,
    ppm: f32,
};

pub const PhysicsBody = struct {
    shape: zb.b2ShapeId,
    body: zb.b2BodyId,
};

pub var config = PhysicsConfig{
    .ppm = 100,
    .time_step = 1.0 / 60.0,
    .sub_step_count = 6,
};
pub var world: zb.b2WorldId = undefined;

pub const module = delve.modules.Module{
    .name = "physics",
    .init_fn = init,
    .tick_fn = tick,
    .cleanup_fn = cleanup,
};

pub fn createBodyCircle(rect: delve.spatial.Rect) PhysicsBody {
    var body_def = zb.b2DefaultBodyDef();
    body_def.type = zb.b2_dynamicBody;
    body_def.position = zb.b2Vec2{ .x = rect.x, .y = rect.y };
    const body = zb.b2CreateBody(world, &body_def);
    const circle = zb.b2Circle{
        .center = .{ .x = 0, .y = 0 },
        .radius = rect.width / 2,
    };
    const shape_def = zb.b2DefaultShapeDef();
    const shape = zb.b2CreateCircleShape(body, &shape_def, &circle);

    return PhysicsBody{
        .shape = shape,
        .body = body,
    };
}

/// Create a physics body based on size and position defined by `rect` parameter.
pub fn createBody(bodyType: zb.b2BodyType, rect: delve.spatial.Rect) PhysicsBody {
    var body_def = zb.b2DefaultBodyDef();
    body_def.type = bodyType;
    body_def.position = zb.b2Vec2{ .x = rect.x, .y = rect.y };
    const body = zb.b2CreateBody(world, &body_def);
    const polygon = zb.b2MakeBox(rect.width / 2, rect.height / 2);
    const shape_def = zb.b2DefaultShapeDef();
    const shape = zb.b2CreatePolygonShape(body, &shape_def, &polygon);

    return PhysicsBody{
        .shape = shape,
        .body = body,
    };
}

pub fn createStaticBody(rect: delve.spatial.Rect) PhysicsBody {
    return createBody(zb.b2_staticBody, rect);
}

pub fn createDynamicBody(rect: delve.spatial.Rect) PhysicsBody {
    return createBody(zb.b2_dynamicBody, rect);
}

pub fn createKineticBody(rect: delve.spatial.Rect) PhysicsBody {
    return createBody(zb.b2_kinematicBody, rect);
}

fn init() !void {
    zb.b2SetLengthUnitsPerMeter(config.ppm);
    var world_def = zb.b2DefaultWorldDef();
    world_def.gravity.y = 0;
    world_def.gravity.x = 0;
    world = zb.b2CreateWorld(&world_def);
}

fn cleanup() !void {
    zb.b2DestroyWorld(world);
}

fn tick(_: f32) void {
    zb.b2World_Step(world, config.time_step, @intCast(config.sub_step_count));
}
