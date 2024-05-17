import ypee_eg

# temporary
import glm
import glrenderer

proc main() =
    var eg = newYpeeEg(vec2i(320, 200), smFixed, -1)

    var camera = newCamera(mat4f())
    camera.translate(vec3f(vec2f(eg.screenSize) / 2.0, 0.0))

    const testBmp = staticRead("../textures/rat.bmp")
    var
        testSheet = newSpriteSheet(vec2i(0, 0), eg.renderer.program(0), testBmp)
        testSprite = newSprite(testSheet, vec2i(0, 0), vec2i(0, 0))

    const fontBmp = staticRead("../textures/font.bmp")
    var fpsText = newMonoText(vec2i(8, 8), eg.renderer.program(0), fontBmp)
    fpsText.setContent("0.0")

    const cursorBmp = staticRead("../textures/cursor.bmp")
    var
        cursorSheet = newSpriteSheet(vec2i(0, 0), eg.renderer.program(0), cursorBmp)
        cursorSprite = newSprite(cursorSheet, vec2i(0, 0), vec2i(-6, 5))

    while eg.nextFrame():
        if eg.frameCounter.elapsed >= 2.0:
            fpsText.setContent($eg.frameCounter.getFps())

        if eg.inpHeld(inMouseM):
            camera.translate(vec3f(vec2f(eg.mouse.screenDelta), 0.0))
        const speed = 120
        let
            mPos = eg.mouse.screenPos
            move = speed * eg.delta
        if mPos.x == 0:
            camera.translate(vec3f(move, 0.0, 0.0))
        elif mPos.x == eg.screenSize.x - 1:
            camera.translate(vec3f(-move, 0.0, 0.0))
        if mPos.y == 0:
            camera.translate(vec3f(0.0, move, 0.0))
        elif mPos.y == eg.screenSize.y - 1:
            camera.translate(vec3f(0.0, -move, 0.0))

        if eg.inpPressed(inKeyM):
            eg.screenMode = case eg.screenMode
                of smNoFrame: smFixed
                of smFixed: smStretch
                of smStretch: smAdjustWidth
                of smAdjustWidth: smNoFrame
            eg.refreshProjection(eg.winSize)
            echo "Screen mode: ", eg.screenMode

        if eg.inpPressed(inKeyF11):
            eg.toggleFullscreen()
            
        fpsText.setPos(vec3f(4.0, eg.screenSize[1].float - 4.0, 10.0))
            
        eg.beginCamera(camera)
        for i in countup(1, 100):
            let i = i.float / 100.0
            testSprite.draw(
                eg,
                pos = vec3f(0.0, 0.0, i),
                tint = vec4f(0.5 + sin(eg.time * i) / 2.0, 0.0, 0.5 + cos(eg.time * i) / 2.0, 1.0),
                scale = vec2f(abs(tan(eg.time * i)), abs(1.0 / tan(eg.time * i)))
            )
        eg.layer()
        eg.endCamera()
        cursorSprite.draw(
            eg,
            pos = vec3f(vec2f(eg.mouse.screenPos), 100.0),
            tint = vec4f(0.8, 0.4, 0.2, 1.0)
        )
        fpsText.draw(eg)
        eg.layer()
    
    eg.destroy()

when isMainModule:
    main()
