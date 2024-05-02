import ypee_eg

# temporary
import glm
import glad/gl
import glrenderer
import random
import glfw

const testFile = staticRead("../textures/ratprism.bmp")

proc randomRange(bot, top: float): float =
    bot + rand(top * 2)

proc main() =
    var eg: YpeeEg
    eg.init()

    var
        testImage: GLImage
        testShape: GLShape
    testImage.init(testFile)
    testShape.init(eg.renderer.program(0), prismVertices)

    randomize()

    var mats: seq[Mat4x4f]

    while eg.nextFrame():
        eg.processEvents()

        if eg.frameCounter.elapsed >= 5.0:
            discard eg.frameCounter.getFps()

        if isKeyDown(eg.window, keySpace):
            mats.add(
                mat4f()
                    .translate(128.0 + randomRange(-64.0, 64.0), 128.0 + randomRange(-64.0, 64.0), 128.0 - randomRange(-32.0, 32.0))
                    .scale(randomRange(2.0, 16.0))
                    .rotateX(rand(2.0) * PI)
                    .rotateY(rand(2.0) * PI)
                    .rotateZ(rand(2.0) * PI)
            )
        if isKeyDown(eg.window, keyEscape) and mats.len() > 0:
            discard mats.pop()

        glClearColor(0.1, 0.05, 0.02, 1.0)
        glClear((GL_COLOR_BUFFER_BIT.uint + GL_DEPTH_BUFFER_BIT.uint).GLbitfield)
    
        #for i in countup(0, 100):
        #let
        #    r1 = rect(16.0 * float(rand(13)), 16.0 * float(rand(6)), 32.0, 32.0)
        #    r2 = rect(16.0 * float(rand(13)), 16.0 * float(rand(6)), 16.0, 16.0)
        #    m1 = mat4f().translate(-1.0 + rand(2.0), -1.0 + rand(2.0), 0.0)
        #    m2 = mat4f().translate(-1.0 + rand(2.0), -1.0 + rand(2.0), 0.0)
        #let
            #r1 = rect(0.0, 0.0, 128.0, 128.0)
            #r2 = rect(32.0, 32.0, 64.0, 32.0)
            #m1 = mat4f().translate(32.0, 32.0, 0.0).scale(64.0, 64.0, 1.0)
            #m2 = mat4f().translate(96.0, 96.0, 0.0).scale(64.0, 32.0, 1.0)
        for mat in mats:
            eg.renderer.draw(testShape, testImage, instance(mat))
        #eg.renderer.draw(testShape, testImage, instance(r2, m2))
        eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
