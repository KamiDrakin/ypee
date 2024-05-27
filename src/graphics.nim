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
        size: Vec2i
        width: int32
    Sprite* = ref object
        sheet: SpriteSheet
        instances: GLInstances
        center*: Vec2i
    SpriteInst* = ref object
        sprite: Sprite
        handle: Handle
        pos: Vec3f # get rid of this
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
    result.instances = newInstances(program, 4)

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
    result.size =
        if size.x == 0 or size.y == 0:
            vec2i(result.image.size[0], result.image.size[1])
        else:
            size
    result.width = result.image.size[0] div result.size.x

proc at*(sheet: SpriteSheet; pos: Vec2i): GLRect =
    let
        x = pos.x.float
        y = pos.y.float
        w = sheet.size.x.float
        h = sheet.size.y.float
    rect(x * w, y * h, w, h)

proc newSprite*(sheet: SpriteSheet; center: Vec2i): Sprite =
    result = new Sprite

    result.sheet = sheet
    result.instances = newInstances(sheet.shape.program, 4)
    result.center = center

proc newSprite*(sheet: SpriteSheet): Sprite =
    result = newSprite(sheet, -sheet.size / 2)

proc clearInstances*(sprite: Sprite) =
    sprite.instances.clear()

proc draw*(sprite: Sprite; renderer: GLRenderer) =
    renderer.draw(sprite.sheet.shape, sprite.sheet.image, sprite.instances)

proc newInstance*(sprite: Sprite): SpriteInst =
    result = new SpriteInst

    result.sprite = sprite
    result.handle = newHandle(
        result.sprite.instances,
        (
            vec4f(1.0),
            sprite.sheet.at(vec2i(0)),
            vec4f(0.0),
            mat4f()
        )
    )

proc delete*(inst: SpriteInst) =
    inst.handle.delete()

proc `tint=`*(inst: SpriteInst; v: Vec4f) =
    inst.handle[0] = v

proc `offset=`*(inst: SpriteInst; v: Vec2i) =
    inst.handle[1] = inst.sprite.sheet.at(v)

proc pos*(inst: SpriteInst): Vec3f =
    inst.pos

proc `pos=`*(inst: var SpriteInst; pos: Vec3f) =
    if inst.pos == pos: return
    inst.pos = pos
    var pixelPos = inst.pos
    pixelPos.xy = pixelPos.xy.floor()
    inst.handle[3] =
        mat4f()
            .translate(inst.pos - vec3f(vec2f(inst.sprite.center), 0.0))
            .scale(inst.sprite.sheet.size.x.float, inst.sprite.sheet.size.y.float, 1.0)

proc newMonoText*(size: Vec2i; program: GLProgram; bmpStr: string): MonoText =
    result = new MonoText

    result.sheet = newSpriteSheet(size, program, bmpStr)
    result.instances = newInstances(program, 4)
    result.width = 0.0

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
    if text.pos == pos: return
    text.pos = pos
    for i, handle in text.handles:
        handle[3] =
            mat4f()
                .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                .scale(text.sheet.size[0].float, text.sheet.size[1].float, 0.0)

proc draw*(text: MonoText; renderer: GLRenderer) =
    renderer.draw(text.sheet.shape, text.sheet.image, text.instances)