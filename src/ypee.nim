import ypee_eg

# temporary
import glm
import glrenderer

proc main() =
    var eg: YpeeEg
    eg.init((256, 224), smAdjustWidth)

    const testBmp = staticRead("../textures/champions.bmp")
    var testSheet: SpriteSheet
    testSheet.init((16u, 16u), eg.renderer.program(0), testBmp)

    const fontBmp = staticRead("../textures/font.bmp")
    var fpsText: MonoText
    fpsText.init((8u, 8u), eg.renderer.program(0), fontBmp)
    fpsText.setContent("0.0")
    fpsText.setPos(vec3f(6.0, eg.screenSize[1].float - 10.0, 10.0))

    const mat = mat4f()

    var pPos = vec3f(128.0, 112.0, 0.0)

    while eg.nextFrame():
        eg.processEvents()

        if eg.frameCounter.elapsed >= 2.0:
            fpsText.setContent($eg.frameCounter.getFps())

        const moveSpeed = 64.0
        var moveVec = vec3f(0.0)
        if eg.inputs[inKeyDown]:
            moveVec.y -= 1.0
        if eg.inputs[inKeyUp]:
            moveVec.y += 1.0
        if eg.inputs[inKeyLeft]:
            moveVec.x -= 1.0
        if eg.inputs[inKeyRight]:
            moveVec.x += 1.0
        if moveVec.length2() > 0.0:
           pPos += moveVec.normalize() * moveSpeed * eg.delta
            
        #eg.renderer.setUniform("viewMat", mat4f().translate(-pPos + vec3f(128.0, 112.0, 0.0)))
        let instance = instance(vec4f(1.0, 1.0, 1.0, 1.0)) +
            testSheet.at(1, 0) +
            mat.translate(pPos).scale(16.0, 16.0, 1.0)
        eg.renderer.draw(testSheet.shape, testSheet.image, instance)
        eg.draw(fpsText.drawData())
        eg.renderer.renderFramed(eg.winSize)
        #eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
