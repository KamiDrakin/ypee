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

    var cursor = newInstance(cursorSprite)
    cursor.tint = vec4f(0.8, 0.4, 0.2, 1.0)

    var
        testRect = newRectangle(eg.defaultProgram)
        testRectInsts: seq[RectangleInst]
    for i in countup(0, 99):
        var inst = newInstance(testRect)
        inst.area = vec4f((i mod 10).float * 15.0, (i div 10).float * 10.0, 15.0, 10.0)
        inst.color = vec3f(0.5 + sin((i mod 10).float) / 2.0, 0.5 + sin((i div 10).float) / 2.0, 0.5)
        testRectInsts.add(inst)

    while eg.nextFrame():
        if eg.frameCounter.elapsed >= 2.0:
            fpsText.content = $eg.frameCounter.fps

        if eg.inpPressed(inKeyM):
            eg.screenMode =
                case eg.screenMode
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
        testRect.draw(eg.renderer)
        eg.layer()
        eg.endCamera()
        cursorSprite.draw(eg.renderer)
        fpsText.draw(eg.renderer)
        eg.layer()

    eg.destroy()

when isMainModule:
    main()