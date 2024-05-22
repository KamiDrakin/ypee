import glm
import sdl2

import custom_utils
import glrenderer

type
    ProgramIndex = enum
        piBase
    ScreenMode* = enum
        smNoFrame
        smFixed
        smStretch
        smAdjustWidth
    Input* = enum
        inMouseL
        inMouseR
        inMouseM
        inKeyUp
        inKeyDown
        inKeyLeft
        inKeyRight
        inKeyEsc
        inKeyF11
        inKeyM
        inNone
    MouseState = object
        prevPos: Vec2i
        rawPos*: Vec2i
        rawDelta*: Vec2i
        prevScreenPos: Vec2i
        screenPos*: Vec2i
        screenDelta*: Vec2i
    SpriteSheet* = ref object
        shape*: GLShape
        image*: GLImage
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
        pos: Vec3f
        str: string
        width*: float
        changed: bool
    Camera2D* = ref object
        baseMat: Mat4x4f
        viewMat: Mat4x4f
        pos: Vec3f
        pixelPos: Vec3f
    FrameCounter = ref object
        frameCap: int
        frameCount: int
        prevTime: float
        frameTimer: float
        elapsed*: float
    YpeeEg* = ref object
        running*: bool
        window*: WindowPtr
        winSize*: Vec2i
        unadjustedScreenSize: Vec2i
        screenSize*: Vec2i
        screenMode*: ScreenMode
        fullscreen: bool
        projectionCalc: proc(width, height: float32): Mat4x4f
        renderer*: GLRenderer
        frameCounter*: FrameCounter
        delta*: float
        time*: float
        prevInputs: array[Input, bool]
        inputs: array[Input, bool]
        mouse*: MouseState

const
    defaultScreenSize = vec2i(320, 200)
    defaultScreenMode = smFixed
    defaultScale = 3

proc toInput(key: Scancode): Input =
    case key
        of SDL_SCANCODE_UP: inKeyUp
        of SDL_SCANCODE_DOWN: inKeyDown
        of SDL_SCANCODE_LEFT: inKeyLeft
        of SDL_SCANCODE_RIGHT: inKeyRight
        of SDL_SCANCODE_ESCAPE: inKeyEsc
        of SDL_SCANCODE_F11: inKeyF11
        of SDL_SCANCODE_M: inKeyM
        else: inNone

proc toInputMouse(mb: uint8): Input =
    case mb
        of 1: inMouseL
        of 3: inMouseR
        of 2: inMouseM
        else: inNone

proc updatePos(mouse: var MouseState; rawPos: Vec2i; eg: YpeeEg) =
    mouse.rawPos = rawPos
    mouse.screenPos = mouse.rawPos * eg.screenSize / eg.winSize
    if eg.screenMode == smFixed:
        let
            screenSize = vec2f(eg.screenSize)
            winSize = vec2f(eg.winSize)
            screenPos = vec2f(vec2f(mouse.rawPos) * screenSize / winSize)
            ratio = screenSize / winSize
            higherRatio = max(ratio.x, ratio.y)
            scale = higherRatio / ratio 
            adjustedPos = screenPos * scale
            offset = screenSize * (scale - 1.0) / 2.0
        mouse.screenPos = vec2i(adjustedPos - offset)
        if not vec4i(0, 0, eg.screenSize - 1).contains(mouse.screenPos):
            let
                rawOffset = vec2i(winSize - winSize / scale) / 2
                rawPos = mouse.rawPos.clamp(rawOffset, vec2i(winSize) - rawOffset)
            eg.window.warpMouseInWindow(rawPos.x, eg.winSize.y - rawPos.y - 1)
    mouse.screenPos = vec2i(mouse.screenPos.clamp(vec2i(0), eg.screenSize - 1))

proc recalculateDeltas(mouse: var MouseState; eg: YpeeEg) =
    mouse.rawDelta = mouse.rawPos - mouse.rawPos
    mouse.prevPos = mouse.rawPos
    mouse.screenDelta = mouse.screenPos - mouse.prevScreenPos
    mouse.prevScreenPos = mouse.screenPos

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

proc remove*(inst: SpriteInst) =
    inst.sprite.instances.del(inst.modelMat)
    inst.sprite.instances.del(inst.sheetRect)
    inst.sprite.instances.del(inst.tint)

proc draw*(sprite: Sprite; eg: YpeeEg) =
    eg.renderer.draw(sprite.sheet.shape, sprite.sheet.image, sprite.instances)

proc `tint=`*(inst: SpriteInst; v: Vec4f) =
    inst.sprite.instances[inst.tint[]] = v

proc `offset=`*(inst: SpriteInst; v: Vec2i) =
    inst.sprite.instances[inst.sheetRect[]] = inst.sprite.sheet.at(v)

proc pos*(inst: SpriteInst): Vec3f = inst.pos

proc `pos=`*(inst: var SpriteInst; pos: Vec3f) =
    inst.pos = pos
    inst.sprite.instances[inst.modelMat[]] =
        mat4f()
            .translate(floor(inst.pos) - vec3f(vec2f(inst.sprite.center), 0.0))
            .scale(inst.sprite.sheet.size.x.float, inst.sprite.sheet.size.y.float, 1.0)

proc newMonoText*(size: Vec2i; program: GLProgram; bmpStr: string): MonoText =
    result = new MonoText

    result.sheet = newSpriteSheet(size, program, bmpStr)
    result.instances = newInstances(program, 4)
    result.width = 0.0

proc setContent*(text: var MonoText; str: string) =
    if str != text.str:
        text.str = str
        text.width = text.sheet.size[0].float * (str.len() - 1).float
        text.changed = true

proc draw*(
    text: MonoText;
    eg: YpeeEg;
) = # update this
    if text.changed:
        text.instances.clear()
        for i, c in text.str:
            let asc = c.int32 - 32
            discard text.instances.add(vec4f(1.0, 1.0, 1.0, 1.0))
            discard text.instances.add(text.sheet.at(vec2i(asc mod text.sheet.width, asc div text.sheet.width)))
            discard text.instances.add(
                mat4f()
                    .translate(text.pos + vec3f(text.sheet.size[0].float * i.float, 0.0, 0.0))
                    .scale(text.sheet.size[0].float, text.sheet.size[1].float, 0.0)
            )
        text.changed = false
    eg.renderer.draw(text.sheet.shape, text.sheet.image, text.instances)

proc draw*(
    text: MonoText;
    eg: YpeeEg;
    pos: Vec3f;
) =
    if pos != text.pos:
        text.pos = pos
        text.changed = true
    text.draw(eg)

proc newCamera2D*(viewMat: Mat4x4f): Camera2D =
    result = new Camera2D

    result.baseMat = viewMat
    result.viewMat = viewMat
    result.pos = vec3f(0.0)
    result.pixelPos = vec3f(0.0)

proc translate*(cam: Camera2D; vec: Vec3f) =
    cam.pos += vec
    cam.pixelPos = cam.pos.floor()

proc relative*(cam: Camera2D; vec: Vec3f): Vec3f =
    vec - cam.pos

proc unrelative*(cam: Camera2D; vec: Vec3f): Vec3f =
    vec + cam.pos

proc newFrameCounter(): FrameCounter =
    result = new FrameCounter

    result.frameCap = 0
    result.frameCount = 0
    result.prevTime = 0.0
    result.frameTimer = 0.0
    result.elapsed = 0.0

proc tick(fc: FrameCounter): float =
    fc.frameCount += 1
    var delta = getTicks().float / 1000.0 - fc.prevTime
    if fc.frameCap > 0:
        let delayTime = 1.0 / fc.frameCap.float - delta
        if delayTime > 0.0:
            delta += delayTime
            delay((delayTime * 1000.0).uint32)
    fc.frameTimer += delta
    fc.prevTime += delta
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

proc inpHeld*(eg: YpeeEg; key: Input): bool =
    eg.inputs[key]

proc inpPressed*(eg: YpeeEg; key: Input): bool =
    not eg.prevInputs[key] and eg.inputs[key]

proc inpReleased*(eg: YpeeEg; key: Input): bool =
    eg.prevInputs[key] and not eg.inputs[key]
        
proc refreshProjection*(eg: YpeeEg; winSize: Vec2i) =
    var
        width: float
        height: float
    if winSize.x <= 0 or winSize.y <= 0:
        return
    eg.winSize = winSize
    case eg.screenMode
        of smNoFrame:
            eg.screenSize = eg.winSize
        of smFixed, smStretch:
            eg.screenSize = eg.unadjustedScreenSize
        of smAdjustWidth:
            eg.screenSize.x = eg.screenSize.y * winSize.x div winSize.y
    width = eg.screenSize.x.float
    height = eg.screenSize.y.float
    eg.renderer.frame.resize(eg.screenSize)
    eg.renderer.setUniform("projMat", eg.projectionCalc(width, height))

proc newYpeeEg*(
    screenSize: Vec2i = defaultScreenSize;
    screenMode: ScreenMode = defaultScreenMode;
    fpsCap: int = -1;
): YpeeEg =
    result = new YpeeEg

    result.running = true
    result.unadjustedScreenSize = screenSize
    result.screenSize = screenSize
    result.screenMode = screenMode
    result.projectionCalc =
        proc(width, height: float32): Mat4x4f = ortho[float32](0.0, width, 0.0, height, -1000.0, 1000.0)
        #proc(width, height: float32): Mat4x4f = perspective[float32](90.0, height / width, 0.1, 1000.0)

    discard sdl2.init(INIT_EVERYTHING)

    result.window = createWindow(
        "YPEE",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        (screenSize.x * defaultScale).cint, (screenSize.y * defaultScale).cint,
        SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE
    )
    discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
    discard glCreateContext(result.window)

    var fpsCap = fpsCap
    if fpsCap == -1:
        if glSetSwapInterval(1) == -1:
            fpsCap = 60

    result.renderer = newRenderer()
    const
        vShaderSrc = staticRead("shaders/ypee/ypee.vs")
        fShaderSrc = staticRead("shaders/ypee/ypee.fs")
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
    result.frameCounter.frameCap = fpsCap

    result.renderer.clearColor = (0.0, 0.0, 0.0)
    result.renderer.frame = newFrame(screenSize)
    let winSize = result.window.getSize()
    result.refreshProjection(cast[Vec2i](winSize))

    result.mouse.screenPos = screenSize / 2
    showCursor(false)
    discard setRelativeMouseMode(true.Bool32)

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
                    eg.refreshProjection(vec2i(newWidth.int32, newHeight.int32))
            of KeyDown:
                let key = toInput(evt.key().keysym.scancode)
                eg.inputs[key] = true
            of KeyUp:
                let key = toInput(evt.key().keysym.scancode)
                eg.inputs[key] = false
            of MouseButtonDown:
                let button = toInputMouse(evt.button().button)
                eg.inputs[button] = true
            of MouseButtonUp:
                let button = toInputMouse(evt.button().button)
                eg.inputs[button] = false
            of MouseMotion:
                let motion = evt.evMouseMotion()
                eg.mouse.updatePos(vec2i(motion.x.int32, eg.winSize.y - motion.y.int32 - 1), eg)
            else:
                discard
    
proc nextFrame*(eg: YpeeEg): bool =
    eg.delta = eg.frameCounter.tick()
    eg.time = eg.frameCounter.prevTime
    case eg.screenMode
        of smNoFrame:
            discard
        of smFixed, smAdjustWidth:
            eg.renderer.renderFrame(eg.winSize, true)
        of smStretch:
            eg.renderer.renderFrame(eg.winSize, false)
    eg.window.glSwapWindow()
    case eg.screenMode
        of smNoFrame:
            eg.renderer.clear()
        of smFixed, smAdjustWidth, smStretch:
            eg.renderer.clearFrame()
    eg.prevInputs = eg.inputs
    eg.processEvents()
    eg.mouse.recalculateDeltas(eg)
    return eg.running

proc layer*(eg: YpeeEg) =
    case eg.screenMode
        of smNoFrame:
            eg.renderer.layer(eg.winSize)
        of smFixed, smAdjustWidth:
            eg.renderer.layerFramed()
        of smStretch:
            eg.renderer.layerFramed()

proc beginCamera*(eg: YpeeEg; cam: Camera2D) =
    cam.viewMat = cam.baseMat.translate(cam.pixelPos)
    eg.renderer.setUniform("viewMat", cam.viewMat)

proc endCamera*(eg: YpeeEg) =
    eg.renderer.setUniform("viewMat", mat4f())

proc toggleFullscreen*(eg: YpeeEg) =
    eg.fullscreen = not eg.fullscreen
    discard eg.window.setFullscreen(if eg.fullscreen: SDL_WINDOW_FULLSCREEN_DESKTOP else: 0)