import glm
import glfw

import event_procs
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
    YpeeEg* = object
        window*: glfw.Window
        renderer*: GLRenderer
        frameCounter*: FrameCounter
        delta*: float
        screenSize: (int, int)
        screenMode: ScreenMode
        projectionCalc: proc(width, height: float32): Mat4x4f

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
        time = glfw.getTime()
        delta = time - fc.prevTime
    fc.frameTimer += delta
    fc.prevTime = time
    if fc.frameTimer >= 1.0:
        fc.frameTimer -= 1.0
        fc.elapsed += 1.0
    return delta

proc getFps*(fc: var FrameCounter): float =
    result = fc.frameCount.float / fc.elapsed
    fc.init()
        
proc refreshProjection*(eg: var YpeeEg) =
    var mat: Mat4x4f
    let winSize = eg.window.size()
    if winSize[0] <= 0 or winSize[1] <= 0:
        return
    case eg.screenMode
        of smNoFrame:
            let
                width = winSize[0].float
                height = winSize[1].float
            mat = ortho[float32](0.0, width, 0.0, height, 100.0, -100.0)
        of smFixed:
            let
                width = eg.screenSize[0].float
                height = eg.screenSize[1].float
            mat = ortho[float32](0.0, width, 0.0, height, 100.0, -100.0)
            mat = perspective[float32](90.0, height / width, 0.1, 1000.0)
        of smStretch:
            discard # todo
        of smAdjustWidth:
            let winSize = eg.window.size()
            eg.screenSize[0] = eg.screenSize[1] * winSize[0] div winSize[1]
            let
                width = eg.screenSize[0].float
                height = eg.screenSize[1].float
            mat = eg.projectionCalc(width, height)
            eg.renderer.frame.resize(eg.screenSize)
    eg.renderer.setUniform("projMat", mat)

proc init*(
    eg: var YpeeEg,
    screenSize: (int, int) = defaultScreenSize,
    screenMode: ScreenMode = defaultScreenMode,
) =
    glfw.initialize()

    eg.screenSize = screenSize
    eg.screenMode = screenMode
    eg.projectionCalc =
        proc(width, height: float32): Mat4x4f = ortho[float32](0.0, width, 0.0, height, -1000.0, 1000.0)
        #proc(width, height: float32): Mat4x4f = perspective[float32](90.0, height / width, 0.1, 1000.0)

    var cfg = DefaultOpenglWindowConfig
    cfg.size = screenSize * defaultScale
    cfg.title = "YPEE"
    cfg.resizable = true
    cfg.version = glfw.glv33
    cfg.forwardCompat = true
    cfg.profile = glfw.opCoreProfile

    eg.window = glfw.newWindow(cfg)

    eg.renderer.init()
    const
        vShaderSrc = staticRead("shaders/ypee.vs")
        fShaderSrc = staticRead("shaders/ypee.fs")
    var progBase: GLProgram
    progBase.init(vShaderSrc, fShaderSrc)
    progBase.setAttributes(
        @[("vPos", 3), ("vColor", 3), ("vTexCoords", 2)],
        @[("iColor", 3), ("texRect", 4), ("modelMat", 16)]
    )
    progBase.setUniforms(@[("texSize", 2), ("viewMat", 16), ("projMat", 16)])
    eg.renderer.addProgram(piBase.uint, progBase)
    eg.renderer.setUniform("viewMat", mat4f())
    #eg.renderer.setUniform("viewMat", mat4f().translate(-128.0, -120.0, 50.0))
    eg.refreshProjection()
    
    eg.window.registerWindowCallbacks()
    glfw.swapInterval(1)

    eg.frameCounter.init()

    eg.renderer.clearColor = (0.1, 0.0, 0.1)
    eg.renderer.frame.init(screenSize)

proc destroy*(eg: var YpeeEg) =
    eg.window.destroy()
    glfw.terminate()
    
proc nextFrame*(eg: var YpeeEg): bool =
    eg.delta = eg.frameCounter.tick()
    glfw.swapBuffers(eg.window)
    if windowSizeChanged:
        eg.refreshProjection()
        windowSizeChanged = false
    return not eg.window.shouldClose()

proc processEvents*(eg: YpeeEg) =
    glfw.pollEvents()