import std/sequtils

import glm
import glfw

import event_procs
import custom_utils
import glrenderer

type
    Programs* = enum
        prBase
    ScreenMode* = enum
        smNormal
        smFixed
        smAdjustWidth
        smAdjustWidthHeight
    FrameCounter = object
        frameCounts: seq[int]
        prevTime: float
        frameTimer: float
        elapsed*: float
    Sprite* = object
    YpeeEg* = object
        window: glfw.Window
        renderer*: GLRenderer
        frameCounter*: FrameCounter
        delta*: float
        screenSize: (int, int)
        screenMode: ScreenMode

const
    defaultScreenSize = (256, 240)
    defaultScreenMode = smFixed
    defaultScale = 3

proc init(fc: var FrameCounter) =
    fc.frameCounts = @[0]
    fc.frameTimer = 0.0
    fc.elapsed = 0.0

proc tick(fc: var FrameCounter): float =
    fc.frameCounts[fc.frameCounts.len() - 1] += 1
    let
        time = glfw.getTime()
        delta = time - fc.prevTime
    fc.frameTimer += delta
    fc.prevTime = time
    if fc.frameTimer >= 1.0:
        fc.frameTimer -= 1.0
        fc.elapsed += 1.0
        fc.frameCounts.add(0)
    if fc.elapsed >= 100.0:
        fc.init()
    return delta

proc getFps*(fc: var FrameCounter): float =
    let frameSum = fc.frameCounts.foldl(a + b)
    result = frameSum.float / fc.elapsed
    fc.init()
        
proc refreshProjection*(eg: var YpeeEg) =
    var mat: Mat4x4f
    case eg.screenMode
        of smNormal:
            let
                winSize = eg.window.size
                width = winSize[0].float
                height = winSize[1].float
            mat = ortho[float32](0.0, width, 0.0, height, -100.0, 100.0)
        of smFixed:
            let
                width = eg.screenSize[0].float
                height = eg.screenSize[1].float
            mat = ortho[float32](0.0, width, 0.0, height, -100.0, 100.0)
        of smAdjustWidth:
            discard # todo
        of smAdjustWidthHeight:
            discard # todo
    eg.renderer.setProjMat(mat)

proc init*(eg: var YpeeEg, screenSize: (int, int) = defaultScreenSize) =
    glfw.initialize()

    eg.screenSize = screenSize
    eg.screenMode = defaultScreenMode

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
    eg.renderer.addProgram(prBase.uint, vShaderSrc, fShaderSrc)
    eg.renderer.setViewMat(mat4f())
    eg.refreshProjection()
    
    eg.window.registerWindowCallbacks()
    glfw.swapInterval(1)

    eg.frameCounter.init()

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