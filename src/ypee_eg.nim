import std/sequtils

import glm
import glfw

import event_procs
import custom_utils
import glrenderer

const
    screenSize* = (w: 256, h: 240)
    defaultScale* = 3

type
    Programs* = enum
        prBase
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

proc init(fc: var FrameCounter) =
    fc.frameCounts = @[0]
    fc.frameTimer = 0.0
    fc.elapsed = 0.0

proc tick(fc: var FrameCounter) =
    fc.frameCounts[fc.frameCounts.len() - 1] += 1
    let time = glfw.getTime()
    fc.frameTimer += time - fc.prevTime
    fc.prevTime = time
    if fc.frameTimer >= 1.0:
        fc.frameTimer -= 1.0
        fc.elapsed += 1.0
        fc.frameCounts.add(0)
    if fc.elapsed >= 100.0:
        fc.init()

proc getFps*(fc: var FrameCounter): float =
    let frameSum = fc.frameCounts.foldl(a + b)
    result = frameSum.float / fc.elapsed
    fc.init()
        
proc refreshProjection*(eg: var YpeeEg) =
    let windowSize = eg.window.size()
    let windowRatio = windowSize[1].float / windowSize[0].float
    eg.renderer.setProjMat(ortho[float32](-1.0, 1.0, -windowRatio, windowRatio, -1.0, 1000.0))

proc init*(eg: var YpeeEg) =
    glfw.initialize()

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
        uniforms = @[
            "texSize",
            "viewMat",
            "projMat",
        ]
    eg.renderer.addProgram(prBase.uint, vShaderSrc, fShaderSrc, uniforms)
    eg.renderer.setViewMat(mat4f())
    eg.refreshProjection()
    
    eg.window.registerWindowCallbacks()
    glfw.swapInterval(1)

    eg.frameCounter.init()

proc destroy*(eg: var YpeeEg) =
    eg.window.destroy()
    glfw.terminate()
    
proc nextFrame*(eg: var YpeeEg): bool =
    eg.frameCounter.tick()
    glfw.swapBuffers(eg.window)
    if windowSizeChanged:
        eg.refreshProjection()
        windowSizeChanged = false
    return not eg.window.shouldClose()

proc processEvents*(eg: YpeeEg) =
    glfw.pollEvents()