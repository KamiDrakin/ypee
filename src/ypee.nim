import ypee_eg

# temporary
import glm
import glrenderer

proc main() =
    var eg = newYpeeEg((320, 200), smStretch)

    const testBmp = staticRead("../textures/rat.bmp")
    var
        #testSheet = newSpriteSheet((16u, 16u), eg.renderer.program(0), testBmp)
        testSheet = newSpriteSheet((0u, 0u), eg.renderer.program(0), testBmp)
        testSprite = newSprite(testSheet, (0u, 0u))

    const fontBmp = staticRead("../textures/font.bmp")
    var fpsText = newMonoText((8u, 8u), eg.renderer.program(0), fontBmp)
    fpsText.setContent("0.0")

    var pPos = vec3f(eg.screenSize[0].float / 2.0, eg.screenSize[1].float / 2.0, 0.0)

    while eg.nextFrame():
        if eg.frameCounter.elapsed >= 2.0:
            fpsText.setContent($eg.frameCounter.getFps())

        const moveSpeed = 64.0
        var moveVec = vec3f(0.0)
        if eg.inpHeld(inKeyDown):
            moveVec.y -= 1.0
        if eg.inpHeld(inKeyUp):
            moveVec.y += 1.0
        if eg.inpHeld(inKeyLeft):
            moveVec.x -= 1.0
        if eg.inpHeld(inKeyRight):
            moveVec.x += 1.0
        if moveVec.length2() > 0.0:
            pPos += moveVec.normalize() * moveSpeed * eg.delta

        if eg.inpPressed(inKeyM):
            eg.screenMode = case eg.screenMode
                of smNoFrame:
                    smFixed
                of smFixed:
                    smStretch
                of smStretch:
                    smAdjustWidth
                of smAdjustWidth:
                    smNoFrame
            eg.refreshProjection(eg.winSize)
            echo "Screen mode: ", eg.screenMode
            
        fpsText.setPos(vec3f(4.0, eg.screenSize[1].float - 4.0, 10.0))
            
        #eg.renderer.setUniform("viewMat", mat4f().translate(-pPos + vec3f(128.0, 112.0, 0.0)))
        for i in countup(1, 100):
            let i = i.float / 100.0
            testSprite.draw(
                eg,
                pos = pPos + vec3f(0.0, 0.0, i),
                tint = vec4f(0.5 + sin(eg.time * i) / 2.0, 0.0, 0.5 + cos(eg.time * i) / 2.0, 1.0),
                scale = vec2f(abs(tan(eg.time * i)), abs(1.0 / tan(eg.time * i)))
            )
        fpsText.draw(eg)
        eg.present()
    
    eg.destroy()

when isMainModule:
    main()
