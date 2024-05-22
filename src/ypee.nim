import glm

import ypee_eg

# temporary
import glrenderer
import random

type
    Game = ref object
        eg: YpeeEg
        cam: Camera2D

proc main() =
    randomize()

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
        cursorSheet = newSpriteSheet(vec2i(0, 0), eg.renderer.program(0), cursorBmp)
        cursorSprite = newSprite(cursorSheet, vec2i(-6, 5))

    var fpsText = newMonoText(vec2i(8, 8), eg.renderer.program(0), fontBmp)
    fpsText.setContent("0.0")

    var
        tileSheet = newSpriteSheet(vec2i(0, 0), eg.renderer.program(0), tileBmp)
        tileSprite = newSprite(tileSheet, vec2i(0, 0))

    var tileCountText = newMonoText(vec2i(8, 8), eg.renderer.program(0), fontBmp)

    var cursor = cursorSprite.addInstance()
    cursor.tint = vec4f(0.8, 0.4, 0.2, 1.0)

    var tiles: seq[SpriteInst]
    for y in countup(1, 100):
        for x in countup(1, 100):
            var inst = tileSprite.addInstance()
            inst.tint = vec4f(0.01 * x.float, 0.01 * y.float, 0.33, 1.0)
            inst.pos = vec3f(x.float * 8.0, y.float * 8.0, -(x + y).float)
            tiles.add(inst)

    while eg.nextFrame():
        if eg.frameCounter.elapsed >= 2.0:
            fpsText.setContent($eg.frameCounter.getFps())

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

        if eg.inpHeld(inMouseL):
            for _ in countup(0, 1):
                var inst = tileSprite.addInstance()
                inst.tint = vec4f(sin(eg.time), cos(eg.time), 0.33, 1.0)
                inst.pos = game.cam.relative(vec3f(vec2f(eg.mouse.screenPos), eg.time))
                tiles.add(inst)

        cursor.pos = vec3f(vec2f(eg.mouse.screenPos), 100.0)

        if tiles.len() > 0:
            for _ in countup(0, 16):
                var randomTile = tiles[rand(tiles.len() - 1)]
                randomTile.pos = randomTile.pos + vec3f((-1 + rand(2)).float, (-1 + rand(2)).float, 0.0)
            let randPos = rand(tiles.len() - 1)
            var randomTile = tiles[randPos]
            tiles.delete(randPos)
            randomTile.remove()
        tileCountText.setContent($tiles.len())
            
        eg.beginCamera(game.cam)
        tileSprite.draw(eg)
        eg.layer()
        eg.endCamera()
        cursorSprite.draw(eg)
        fpsText.draw(eg, vec3f(4.0, eg.screenSize[1].float - 4.0, 10.0))
        tileCountText.draw(eg, vec3f(4.0, eg.screenSize[1].float - 14.0, 10.0))
        eg.layer()

    eg.destroy()

when isMainModule:
    main()
