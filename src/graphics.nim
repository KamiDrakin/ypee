import glm

import glrenderer

type
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
        tint: ref int
        sheetRect: ref int
        modelMat: ref int
        pos: Vec3f
    MonoText* = ref object
        sheet: SpriteSheet
        instances: GLInstances
        modelMats: seq[ref int]
        pos: Vec3f
        str: string
        width*: float

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

proc addInstance*(sprite: Sprite): SpriteInst =
    result = new SpriteInst

    result.sprite = sprite
    result.tint = sprite.instances.add(vec4f(1.0))
    result.sheetRect = sprite.instances.add(sprite.sheet.at(vec2i(0)))
    result.modelMat = sprite.instances.add(mat4f())

proc clearInstances*(sprite: Sprite) =
    sprite.instances.clear()

proc draw*(sprite: Sprite; renderer: GLRenderer) =
    renderer.draw(sprite.sheet.shape, sprite.sheet.image, sprite.instances)

proc delete*(inst: SpriteInst) =
    inst.sprite.instances.del(inst.modelMat)
    inst.sprite.instances.del(inst.sheetRect)
    inst.sprite.instances.del(inst.tint)

proc `tint=`*(inst: SpriteInst; v: Vec4f) =
    inst.sprite.instances[inst.tint[]] = v

proc `offset=`*(inst: SpriteInst; v: Vec2i) =
    inst.sprite.instances[inst.sheetRect[]] = inst.sprite.sheet.at(v)

proc pos*(inst: SpriteInst): Vec3f = inst.pos

proc `pos=`*(inst: var SpriteInst; pos: Vec3f) =
    if inst.pos == pos: return
    inst.pos = pos
    var pixelPos = inst.pos
    pixelPos.xy = pixelPos.xy.floor()
    inst.sprite.instances[inst.modelMat[]] =
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
        text.width = text.sheet.size[0].float * (str.len() - 1).float
        text.modelMats.setLen(0)
        text.instances.clear()
        for i, c in text.str:
            let asc = c.int32 - 32
            discard text.instances.add(vec4f(1.0, 1.0, 1.0, 1.0))
            discard text.instances.add(text.sheet.at(vec2i(asc mod text.sheet.width, asc div text.sheet.width)))
            text.modelMats.add(
                text.instances.add(
                    mat4f()
                        .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                        .scale(text.sheet.size.x.float, text.sheet.size.y.float, 0.0)
                )
            )

proc `pos=`*(text: MonoText; pos: Vec3f) =
    if text.pos == pos: return
    text.pos = pos
    for i, mat in text.modelMats:
        text.instances[mat[]] =
            mat4f()
                .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                .scale(text.sheet.size[0].float, text.sheet.size[1].float, 0.0)

proc draw*(text: MonoText; renderer: GLRenderer) =
    renderer.draw(text.sheet.shape, text.sheet.image, text.instances)