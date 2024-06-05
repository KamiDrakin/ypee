import std/algorithm

import glm

import glrenderer

type
    Handle* = ref object
        instances: GLInstances
        fields: seq[ref int]
    Rectangle* = ref object
        shape: GLShape
        instances: GLInstances
    RectangleInst* = ref object
        rect: Rectangle
        handle: Handle
    SpriteSheet* = ref object
        shape: GLShape
        image: GLImage
        instances: GLInstances
        size: Vec2i
        width: int32
    Sprite* = ref object
        sheet: SpriteSheet
        handle: Handle
        center*: Vec2i
        pos: Vec3f
    MonoText* = ref object
        sheet: SpriteSheet
        instances: GLInstances
        handles: seq[Handle]
        pos: Vec3f
        str: string
        width*: float

proc newHandle*[T: tuple](insts: GLInstances; initFields: T): Handle =
    result = new Handle

    result.instances = insts
    for f in initFields.fields:
        result.fields.add(insts.add(f))

proc `[]=`*[T](handle: Handle; i: int; val: T) =
    handle.instances[handle.fields[i][]] = val

proc delete*(handle: Handle) =
    for f in handle.fields.reversed:
        handle.instances.del(f)

proc newRectangle*(program: GLProgram): Rectangle =
    result = new Rectangle

    result.shape = newShape(program, squareVertices)
    result.instances = newInstances(result.shape, 4)

proc delete*(rect: Rectangle) =
    rect.instances.delete()
    rect.shape.delete()

proc draw*(rect: Rectangle; renderer: GLRenderer) =
    renderer.draw(rect.shape, nil, rect.instances)

proc newInstance*(rect: Rectangle): RectangleInst =
    result = new RectangleInst

    result.rect = rect
    result.handle = newHandle(
        result.rect.instances,
        (
            vec4f(1.0),
            vec4f(0.0),
            vec4f(0.0, 0.0, 0.0, 1.0),
            mat4f()
        )
    )

proc delete*(inst: RectangleInst) =
    inst.handle.delete()

proc `color=`*(inst: RectangleInst; color: Vec3f) =
    inst.handle[2] = vec4f(color, 1.0)

proc `area=`*(inst: RectangleInst; area: Vec4f) =
    inst.handle[3] =
        mat4f()
            .translate(area.x + area.z / 2.0, area.y + area.w / 2.0, 0.0)
            .scale(area.z, area.w, 1.0)
    
proc newSpriteSheet*(size: Vec2i; program: GLProgram; bmpStr: string): SpriteSheet =
    result = new SpriteSheet

    result.shape = newShape(program, squareVertices)
    result.image = newImage(bmpStr)
    result.instances = newInstances(result.shape, 4)
    result.size =
        if size.x == 0 or size.y == 0:
            vec2i(result.image.size[0], result.image.size[1])
        else:
            size
    result.width = result.image.size[0] div result.size.x

proc delete*(sheet: SpriteSheet) =
    sheet.instances.delete()
    sheet.image.delete()
    sheet.shape.delete()

proc clearInstances*(sheet: SpriteSheet) =
    sheet.instances.clear()

proc at*(sheet: SpriteSheet; pos: Vec2i): Vec4f =
    let
        x = pos.x.float
        y = pos.y.float
        w = sheet.size.x.float
        h = sheet.size.y.float
    vec4f(x * w, y * h, w, h)

proc draw*(sheet: SpriteSheet; renderer: GLRenderer) =
    renderer.draw(sheet.shape, sheet.image, sheet.instances)

proc newSprite*(sheet: SpriteSheet; center: Vec2i): Sprite =
    result = new Sprite

    result.sheet = sheet
    result.center = center
    result.handle = newHandle(
        sheet.instances,
        (
            vec4f(1.0),
            sheet.at(vec2i(0)),
            vec4f(0.0),
            mat4f()
        )
    )

proc newSprite*(sheet: SpriteSheet): Sprite =
    result = newSprite(sheet, -sheet.size / 2)

proc delete*(sprite: Sprite) =
    sprite.handle.delete()

proc `tint=`*(sprite: Sprite; v: Vec4f) =
    sprite.handle[0] = v

proc `offset=`*(sprite: Sprite; v: Vec2i) =
    sprite.handle[1] = sprite.sheet.at(v)

proc `pos=`*(sprite: var Sprite; pos: Vec3f) =
    sprite.pos = pos
    var pixelPos = sprite.pos
    pixelPos.xy = pixelPos.xy.floor
    sprite.handle[3] =
        mat4f()
            .translate(sprite.pos - vec3f(vec2f(sprite.center), 0.0))
            .scale(sprite.sheet.size.x.float, sprite.sheet.size.y.float, 1.0)

proc newMonoText*(sheet: SpriteSheet): MonoText =
    result = new MonoText

    result.sheet = sheet
    result.instances = newInstances(sheet.shape, 4)
    result.width = 0.0

proc delete*(text: MonoText) =
    text.instances.delete()
    text.sheet.delete()

proc `content=`*(text: MonoText; str: string) =
    if str != text.str:
        text.str = str
        text.width = text.sheet.size[0].float * str.high.float
        text.instances.clear()
        text.handles.setLen(0)
        for i, c in text.str:
            let asc = c.int32 - 32
            text.handles.add(
                newHandle(
                    text.instances,
                    (
                        vec4f(1.0),
                        text.sheet.at(vec2i(asc mod text.sheet.width, asc div text.sheet.width)),
                        vec4f(0.0),
                        mat4f()
                            .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                            .scale(text.sheet.size.x.float, text.sheet.size.y.float, 0.0),
                    )
                )
            )

proc `pos=`*(text: MonoText; pos: Vec3f) =
    text.pos = pos
    for i, handle in text.handles:
        handle[3] =
            mat4f()
                .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                .scale(text.sheet.size[0].float, text.sheet.size[1].float, 0.0)

proc draw*(text: MonoText; renderer: GLRenderer) =
    renderer.draw(text.sheet.shape, text.sheet.image, text.instances)