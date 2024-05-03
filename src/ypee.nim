import ypee_eg

# temporary
import glm
import glrenderer
import random
import glfw

proc main() =
    var eg: YpeeEg
    eg.init((256, 224), smAdjustWidth)

    var
        testImage: GLImage
        testShape: GLShape
    testImage.init(staticRead("../textures/ratprism.bmp").static)
    testShape.init(eg.renderer.program(0), prismVertices)

    randomize()
    var mat = mat4f()
        .translate(128.0, 112.0, 0.0)
        .scale(96.0, 96.0, 1.0)
        #.rotateX(rand(2.0) * PI)
        #.rotateY(rand(2.0) * PI)
        #.rotateZ(rand(2.0) * PI)

    while eg.nextFrame():
        eg.processEvents()

        if eg.frameCounter.elapsed >= 5.0:
            echo eg.frameCounter.getFps()

        if isKeyDown(eg.window, keyW):
            mat.rotateInplX(-eg.delta * PI / 5)
        if isKeyDown(eg.window, keyS):
            mat.rotateInplX(eg.delta * PI / 5)
        if isKeyDown(eg.window, keyA):
            mat.rotateInplY(-eg.delta * PI / 5)
        if isKeyDown(eg.window, keyD):
            mat.rotateInplY(eg.delta * PI / 5)
        if isKeyDown(eg.window, keySpace):
            mat.translateInpl(0.0, 0.0, eg.delta)
        if isKeyDown(eg.window, keyLeftShift):
            mat.translateInpl(0.0, 0.0, -eg.delta)
    
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
        eg.renderer.draw(testShape, testImage, instance(mat))
        #eg.renderer.draw(testShape, testImage, instance(r2, m2))
        eg.renderer.renderFramed(eg.window.size())
        #eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
