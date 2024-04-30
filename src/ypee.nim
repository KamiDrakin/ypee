import ypee_eg

# temporary
import glm
import glad/gl
import glrenderer
import random

proc main() =
    var eg: YpeeEg
    eg.init()

    const
        testVertices: seq[GLVertex] = @[
            vertex( 0.5,  0.5, 0.0,   0.6, 0.0, 0.8,   1.0, 1.0),
            vertex( 0.5, -0.5, 0.0,   0.0, 0.8, 0.6,   1.0, 0.0),
            vertex(-0.5, -0.5, 0.0,   0.8, 0.6, 0.0,   0.0, 0.0),
            vertex(-0.5,  0.5, 0.0,   0.8, 0.0, 0.6,   0.0, 1.0),
        ]
        #testVertices: seq[GLVertex] = @[
        #    vertex( 0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 1.0),
        #    vertex( 0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 0.0),
        #    vertex(-0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 0.0),
        #    vertex(-0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 1.0),
        #]
        testIndices: seq[GLIndex] = @[
            index(0, 1, 3),
            index(1, 2, 3),
        ]
    var
        testImage: GLImage
        testShape: GLShape
    #testSprite.init("./textures/checker.bmp")
    testImage.init("./textures/temp.bmp")
    testShape.init(eg.renderer.program(0), testVertices, testIndices)

    glViewport(0, 0, 256 * 3, 240 * 3)

    while eg.nextFrame():
        eg.processEvents()

        glClearColor(0.1, 0.0, 0.1, 1.0)
        glClear((GL_COLOR_BUFFER_BIT.uint + GL_DEPTH_BUFFER_BIT.uint).GLbitfield)
    
        #for i in countup(0, 100):
        let
            r1 = rect(16.0 * float(rand(13)), 16.0 * float(rand(6)), 32.0, 32.0)
            r2 = rect(16.0 * float(rand(13)), 16.0 * float(rand(6)), 16.0, 16.0)
            m1 = mat4f().translate(-1.0 + rand(2.0), -1.0 + rand(2.0), 0.0)
            m2 = mat4f().translate(-1.0 + rand(2.0), -1.0 + rand(2.0), 0.0)
        #let r = rect(0.0, 0.0, 16.0, 16.0)
        #let r = rect(0.0, 0.0, 240.0, 128.0)
        eg.renderer.draw(testShape, testImage, instance(r1, m1))
        eg.renderer.draw(testShape, testImage, instance(r2, m2))
        #eg.renderer.draw(testShape, testImage)
        eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
