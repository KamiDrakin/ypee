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
    Sprite* = object
        image: GLImage
    YpeeEg* = object
        window: glfw.Window
        renderer*: GLRenderer
        
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
            "texRect",
            "viewMat",
            "projMat",
        ]
    eg.renderer.addProgram(prBase.uint, vShaderSrc, fShaderSrc, uniforms)
    eg.renderer.setViewMat(mat4[float32]())
    #eg.renderer.setProjMat(ortho[float32](0.0, screenSize[0].float, 0.0, screenSize[1].float, -1.0, 1000.0))
    eg.refreshProjection()
    #eg.renderer.setViewMat(mat4[float32]());
    
    eg.window.registerWindowCallbacks()
    glfw.swapInterval(1)

proc destroy*(eg: var YpeeEg) =
    eg.window.destroy()
    glfw.terminate()
    
proc nextFrame*(eg: var YpeeEg): bool =
    glfw.swapBuffers(eg.window)
    if windowSizeChanged:
        eg.refreshProjection()
        windowSizeChanged = false
    return not eg.window.shouldClose()

proc processEvents*(eg: YpeeEg) =
    glfw.pollEvents()