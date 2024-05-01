import ypee_eg

# temporary
import glm
import glad/gl
import glrenderer
#import random

proc main() =
    var eg: YpeeEg
    eg.init()

    var
        testImage: GLImage
        testShape: GLShape
    testImage.init("./textures/font.bmp")
    testShape.init(eg.renderer.program(0), squareVertices, squareIndices)

    while eg.nextFrame():
        eg.processEvents()

        if eg.frameCounter.elapsed >= 5.0:
            echo eg.frameCounter.getFps()

        glClearColor(0.1, 0.0, 0.1, 1.0)
        glClear((GL_COLOR_BUFFER_BIT.uint + GL_DEPTH_BUFFER_BIT.uint).GLbitfield)
    
        #for i in countup(0, 100):
        #let
        #    r1 = rect(16.0 * float(rand(13)), 16.0 * float(rand(6)), 32.0, 32.0)
        #    r2 = rect(16.0 * float(rand(13)), 16.0 * float(rand(6)), 16.0, 16.0)
        #    m1 = mat4f().translate(-1.0 + rand(2.0), -1.0 + rand(2.0), 0.0)
        #    m2 = mat4f().translate(-1.0 + rand(2.0), -1.0 + rand(2.0), 0.0)
        let
            r1 = rect(32.0, 24.0, 16.0, 16.0)
            r2 = rect(32.0, 32.0, 64.0, 32.0)
            m1 = mat4f().translate(32.0, 32.0, 0.0).scale(64.0, 64.0, 1.0)
            m2 = mat4f().translate(96.0, 96.0, 0.0).scale(64.0, 32.0, 1.0)
        eg.renderer.draw(testShape, testImage, instance(r1, m1))
        eg.renderer.draw(testShape, testImage, instance(r2, m2))
        eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
