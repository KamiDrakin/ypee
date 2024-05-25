import glm

import ypee_eg

type
    Game = ref object
        eg: YpeeEg
        cam: Camera2D

proc main() =
    const
        cursorBmp = staticRead("textures/cursor.bmp")
        fontBmp = staticRead("textures/font.bmp")
        tileBmp = staticRead("textures/hexa.bmp")
    var
        game = new Game
        eg = newYpeeEg(vec2i(320, 200), smFixed, -1)
    game.eg = eg
    game.cam = newCamera2D(mat4f())

    var
        cursorSheet = newSpriteSheet(vec2i(0, 0), eg.defaultProgram, cursorBmp)
        cursorSprite = newSprite(cursorSheet, vec2i(-6, 5))

    var fpsText = newMonoText(vec2i(8, 8), eg.defaultProgram, fontBmp)
    fpsText.content = "0.0"

    var
        tileSheet = newSpriteSheet(vec2i(0, 0), eg.defaultProgram, tileBmp)
        tileSprite = newSprite(tileSheet, vec2i(0, 0))

    var cursor = cursorSprite.addInstance()
    cursor.tint = vec4f(0.8, 0.4, 0.2, 1.0)

    var
        testRects = newColoredRectangles(eg.defaultProgram)
        testRect = testRects.addInstance()
    testRect.color = vec3f(0.7, 0.2, 1.0)
    testRect.rect = vec4f(75.0, 75.0, 100.0, 100.0)

    while eg.nextFrame():
        if eg.frameCounter.elapsed >= 2.0:
            fpsText.content = $eg.frameCounter.getFps()

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

        if eg.inpPressed(inKeyEsc):
            eg.running = false

        if eg.inpHeld(inMouseM):
            game.cam.translate(vec3f(vec2f(eg.mouse.screenDelta), 0.0))
        else:
            const speed = 160
            let
                mPos = eg.mouse.screenPos
                move = speed * eg.delta
            if mPos.x == 0:
                game.cam.translate(vec3f(move, 0.0, 0.0))
            elif mPos.x == eg.screenSize.x - 1:
                game.cam.translate(vec3f(-move, 0.0, 0.0))
            if mPos.y == 0:
                game.cam.translate(vec3f(0.0, move, 0.0))
            elif mPos.y == eg.screenSize.y - 1:
                game.cam.translate(vec3f(0.0, -move, 0.0))

        cursor.pos = vec3f(vec2f(eg.mouse.screenPos), 100.0)

        fpsText.pos = vec3f(4.0, eg.screenSize[1].float - 4.0, 10.0)
            
        eg.beginCamera(game.cam)
        tileSprite.draw(eg.renderer)
        testRects.draw(eg.renderer)
        eg.layer()
        eg.endCamera()
        cursorSprite.draw(eg.renderer)
        fpsText.draw(eg.renderer)
        eg.layer()

    eg.destroy()

when isMainModule:
    main()
