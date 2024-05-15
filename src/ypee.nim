import ypee_eg

# temporary
import glm
import glrenderer

proc main() =
    var eg = newYpeeEg((320, 200), smFixed)

    const testBmp = staticRead("../textures/rat.bmp")
    var
        #testSheet = newSpriteSheet((16u, 16u), eg.renderer.program(0), testBmp)
        testSheet = newSpriteSheet((0u, 0u), eg.renderer.program(0), testBmp)
        testSprite = newSprite(testSheet, (0u, 0u))

    const fontBmp = staticRead("../textures/font.bmp")
    var fpsText = newMonoText((8u, 8u), eg.renderer.program(0), fontBmp)
    fpsText.setContent("0.0")
    fpsText.setPos(vec3f(4.0, eg.screenSize[1].float - 4.0, 10.0))

    var pPos = vec3f(eg.screenSize[0].float / 2.0, eg.screenSize[1].float / 2.0, 0.0)

    while eg.nextFrame():
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
        testSprite.draw(
            eg,
            pos = pPos,
            tint = vec4f(0.5 + sin(eg.time) / 2.0, 0.0, 0.5 + cos(eg.time) / 2.0, 1.0),
            scale = vec2f(abs(tan(eg.time)), abs(1.0 / tan(eg.time)))
        )
        fpsText.draw(eg)
        eg.present()
    
    eg.destroy()

when isMainModule:
    main()
