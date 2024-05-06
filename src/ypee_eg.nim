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
    SpriteSheet* = object
        shape*: GLShape
        image*: GLImage
        size: (uint, uint)
    Camera* = object
        pos: Vec3f
        rot: Vec3f
        viewMat: Mat4x4f
    FrameCounter = object
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
    YpeeEg* = object
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

proc init*(sheet: var SpriteSheet; size: (uint, uint); program: GLProgram; bmpStr: string) =
    sheet.shape.init(program, squareVertices)
    sheet.image.init(bmpStr)
    sheet.size = size

proc at*(sheet: SpriteSheet; x, y: int): GLRect =
    let
        x = x.float
        y = y.float
        w = sheet.size[0].float
        h = sheet.size[1].float
    rect(x * w, y * h, w, h)

proc init(fc: var FrameCounter) =
    fc.frameCount = 0
    fc.frameTimer = 0.0
    fc.elapsed = 0.0

proc tick(fc: var FrameCounter): float =
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

proc getFps*(fc: var FrameCounter): float =
    result = fc.frameCount.float / fc.elapsed
    result = result.round(1)
    fc.init()

proc toInput(key: Scancode): Input =
    case key
        of SDL_SCANCODE_UP: inKeyUp
        of SDL_SCANCODE_DOWN: inKeyDown
        of SDL_SCANCODE_LEFT: inKeyLeft
        of SDL_SCANCODE_RIGHT: inKeyRight
        else: inNone
        
proc refreshProjection*(eg: var YpeeEg; winSize: (int, int)) =
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

proc init*(
    eg: var YpeeEg,
    screenSize: (int, int) = defaultScreenSize,
    screenMode: ScreenMode = defaultScreenMode,
) =
    eg.running = true
    eg.screenSize = screenSize
    eg.screenMode = screenMode
    eg.projectionCalc =
        proc(width, height: float32): Mat4x4f = ortho[float32](0.0, width, 0.0, height, -1000.0, 1000.0)
        #proc(width, height: float32): Mat4x4f = perspective[float32](90.0, height / width, 0.1, 1000.0)

    discard sdl2.init(INIT_EVERYTHING)

    eg.window = createWindow(
        "YPEE",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        (screenSize[0] * defaultScale).cint, (screenSize[1] * defaultScale).cint,
        SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE
    )
    #var context = eg.window.glCreateContext()
    discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3)
    discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
    discard eg.window.glCreateContext()
    discard glSetSwapInterval(1)

    eg.renderer.init()
    const
        vShaderSrc = staticRead("shaders/ypee.vs")
        fShaderSrc = staticRead("shaders/ypee.fs")
    var progBase: GLProgram
    progBase.init(vShaderSrc, fShaderSrc)
    progBase.setAttributes(
        @[("vPos", 3), ("vColor", 3), ("vTexCoords", 2)],
        @[("iColor", 4), ("texRect", 4), ("modelMat", 16)]
    )
    progBase.setUniforms(@[("texSize", 2), ("viewMat", 16), ("projMat", 16)])
    eg.renderer.addProgram(piBase.uint, progBase)
    eg.renderer.setUniform("viewMat", mat4f())
    #eg.renderer.setUniform("viewMat", mat4f().translate(-128.0, -120.0, 50.0))
    let winSize = eg.window.getSize()
    eg.refreshProjection((winSize[0].int, winSize[1].int))

    eg.frameCounter.init()

    eg.renderer.clearColor = (0.1, 0.0, 0.1)
    eg.renderer.frame.init(screenSize)

proc destroy*(eg: var YpeeEg) =
    eg.window.destroy()

proc processEvents*(eg: var YpeeEg) =
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
    
proc nextFrame*(eg: var YpeeEg): bool =
    eg.delta = eg.frameCounter.tick()
    eg.window.glSwapWindow()
    eg.processEvents()
    return eg.running