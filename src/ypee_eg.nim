import glm
import sdl2

#import custom_utils
import glrenderer

export sdl2

type
    ProgramIndex = enum
        piBase
    ScreenMode* = enum
        smNoFrame
        smFixed
        smStretch
        smAdjustWidth
    SpriteSheet* = ref object
        shape*: GLShape
        image*: GLImage
        size: (uint, uint)
        width: uint
    Sprite* = ref object
        sheet: SpriteSheet
        offset*: (uint, uint)
    MonoText* = ref object
        sheet: SpriteSheet
        instances: GLInstanceSeq
        pos: Vec3f
        str: string
        width*: float
        changed: bool
    Camera* = ref object
        pos: Vec3f
        rot: Vec3f
        viewMat: Mat4x4f
    FrameCounter = ref object
        frameCount: int
        prevTime: float
        frameTimer: float
        elapsed*: float
    Input* = enum
        inKeyUp
        inKeyDown
        inKeyLeft
        inKeyRight
        inNone
    YpeeEg* = ref object
        running: bool
        window*: WindowPtr
        winSize*: (int, int)
        screenSize*: (int, int)
        screenMode: ScreenMode
        projectionCalc: proc(width, height: float32): Mat4x4f
        renderer*: GLRenderer
        frameCounter*: FrameCounter
        delta*: float
        inputs*: array[Input, bool]

const
    defaultScreenSize = (256, 224)
    defaultScreenMode = smFixed
    defaultScale = 3

proc newSpriteSheet*(size: (uint, uint); program: GLProgram; bmpStr: string): SpriteSheet =
    result = new SpriteSheet

    result.shape = newShape(program, squareVertices)
    result.image = newImage(bmpStr)
    result.size =
        if size[0] == 0 or size[1] == 0:
            (result.image.size[0].uint, result.image.size[1].uint)
        else:
            size
    result.width = result.image.size[0].uint div result.size[0]

proc at*(sheet: SpriteSheet; x, y: uint): GLRect =
    let
        x = x.float
        y = y.float
        w = sheet.size[0].float
        h = sheet.size[1].float
    rect(x * w, y * h, w, h)

proc newSprite*(sheet: SpriteSheet; offset: (uint, uint)): Sprite =
    result = new Sprite

    result.sheet = sheet
    result.offset = offset

proc draw*(sprite: Sprite; eg: YpeeEg; pos: Vec3f) =
    let inst =
        instance(vec4f(1.0, 1.0, 1.0, 1.0)) +
        sprite.sheet.at(sprite.offset[0], sprite.offset[1]) +
        mat4f().translate(pos).scale(sprite.sheet.size[0].float, sprite.sheet.size[1].float, 1.0)
    eg.renderer.draw(sprite.sheet.shape, sprite.sheet.image, inst)

proc newMonoText*(size: (uint, uint); program: GLProgram; bmpStr: string): MonoText =
    result = new MonoText

    result.sheet = newSpriteSheet(size, program, bmpStr)
    result.instances = newInstanceSeq(program, 4)
    result.width = 0.0

proc setContent*(text: var MonoText; str: string) =
    if str != text.str:
        text.str = str
        text.width = text.sheet.size[0].float * (str.len() - 1).float
        text.changed = true

proc setPos*(text: MonoText; pos: Vec3f) =
    if pos != text.pos:
        text.pos = pos
        text.changed = true

proc draw*(text: MonoText; eg: YpeeEg) =
    if text.changed:
        text.instances.clear()
        for i, c in text.str:
            let
                asc = c.uint - 32
                inst =
                    instance(vec4f(1.0, 1.0, 1.0, 1.0)) +
                    text.sheet.at(asc mod text.sheet.width, asc div text.sheet.width) +
                    mat4f()
                        .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                        .scale(text.sheet.size[0].float, text.sheet.size[1].float, 0.0)
            text.instances.add(inst)
        text.changed = false
    eg.renderer.draw(text.sheet.shape, text.sheet.image, text.instances)

proc newFrameCounter(): FrameCounter =
    result = new FrameCounter

    result.frameCount = 0
    result.prevTime = 0.0
    result.frameTimer = 0.0
    result.elapsed = 0.0

proc tick(fc: FrameCounter): float =
    fc.frameCount += 1
    let
        time = sdl2.getTicks().float / 1000.0
        delta = time - fc.prevTime
    fc.frameTimer += delta
    fc.prevTime = time
    if fc.frameTimer >= 1.0:
        fc.frameTimer -= 1.0
        fc.elapsed += 1.0
    return delta

proc getFps*(fc: FrameCounter): float =
    result = fc.frameCount.float / fc.elapsed
    result = result.round(1)
    fc.frameCount = 0
    fc.frameTimer = 0.0
    fc.elapsed = 0.0

proc toInput(key: Scancode): Input =
    case key
        of SDL_SCANCODE_UP: inKeyUp
        of SDL_SCANCODE_DOWN: inKeyDown
        of SDL_SCANCODE_LEFT: inKeyLeft
        of SDL_SCANCODE_RIGHT: inKeyRight
        else: inNone
        
proc refreshProjection*(eg: YpeeEg; winSize: (int, int)) =
    var
        width: float
        height: float
    if winSize[0] <= 0 or winSize[1] <= 0:
        return
    eg.winSize = winSize
    case eg.screenMode
        of smNoFrame:
            width = winSize[0].float
            height = winSize[1].float
        of smFixed:
            width = eg.screenSize[0].float
            height = eg.screenSize[1].float
        of smStretch:
            discard # todo
        of smAdjustWidth:
            eg.screenSize[0] = eg.screenSize[1] * winSize[0] div winSize[1]
            width = eg.screenSize[0].float
            height = eg.screenSize[1].float
            eg.renderer.frame.resize(eg.screenSize)
    eg.renderer.setUniform("projMat", eg.projectionCalc(width, height))

proc newYpeeEg*(
    screenSize: (int, int) = defaultScreenSize,
    screenMode: ScreenMode = defaultScreenMode,
): YpeeEg =
    result = new YpeeEg

    result.running = true
    result.screenSize = screenSize
    result.screenMode = screenMode
    result.projectionCalc =
        proc(width, height: float32): Mat4x4f = ortho[float32](0.0, width, 0.0, height, -1000.0, 1000.0)
        #proc(width, height: float32): Mat4x4f = perspective[float32](90.0, height / width, 0.1, 1000.0)

    discard sdl2.init(INIT_EVERYTHING)

    result.window = createWindow(
        "YPEE",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        (screenSize[0] * defaultScale).cint, (screenSize[1] * defaultScale).cint,
        SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE
    )
    #var context = eg.window.glCreateContext()
    discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
    discard glCreateContext(result.window)
    discard glSetSwapInterval(1)

    result.renderer = newRenderer()
    const
        vShaderSrc = staticRead("shaders/ypee.vs")
        fShaderSrc = staticRead("shaders/ypee.fs")
    var progBase = newProgram(vShaderSrc, fShaderSrc)
    progBase.setAttributes(
        @[("vPos", 3), ("vColor", 3), ("vTexCoords", 2)],
        @[("iColor", 4), ("texRect", 4), ("modelMat", 16)]
    )
    progBase.setUniforms(@[("texSize", 2), ("viewMat", 16), ("projMat", 16)])
    result.renderer.addProgram(piBase.uint, progBase)
    result.renderer.setUniform("viewMat", mat4f())
    #eg.renderer.setUniform("viewMat", mat4f().translate(-128.0, -120.0, 50.0))

    result.frameCounter = newFrameCounter()

    result.renderer.clearColor = (0.1, 0.0, 0.1)
    result.renderer.frame = newFrame(screenSize)
    let winSize = result.window.getSize()
    result.refreshProjection((winSize[0].int, winSize[1].int))

proc destroy*(eg: YpeeEg) =
    eg.window.destroy()

proc processEvents*(eg: YpeeEg) =
    var evt = sdl2.defaultEvent
    while pollEvent(evt):
        case evt.kind
            of QuitEvent:
                eg.running = false
                break
            of WindowEvent:
                var windowEvent = cast[WindowEventPtr](addr(evt))
                if windowEvent.event == WindowEvent_Resized:
                    let newWidth = windowEvent.data1
                    let newHeight = windowEvent.data2
                    eg.refreshProjection((newWidth.int, newHeight.int))
            of KeyDown:
                eg.inputs[toInput(evt.key.keysym.scancode)] = true
            of KeyUp:
                eg.inputs[toInput(evt.key.keysym.scancode)] = false
            else:
                discard
    
proc nextFrame*(eg: YpeeEg): bool =
    eg.delta = eg.frameCounter.tick()
    eg.window.glSwapWindow()
    eg.processEvents()
    return eg.running