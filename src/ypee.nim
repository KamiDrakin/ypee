import std/random

import glm

import ypee_eg

const
    cursorBmp = staticRead("textures/cursor.bmp")
    fontBmp = staticRead("textures/font.bmp")
    tileBmp = staticRead("textures/hexa.bmp")

var
    cursorSheet: SpriteSheet
    fontSheet: SpriteSheet
    tileSheet: SpriteSheet

type
    Tile = ref object
        sprites: array[2, Sprite]
        pos: Vec2f
        adjTiles: seq[Tile]
    Board = ref object
        tiles: seq[Tile]
    Combat = ref object
        board: Board
    Game = ref object
        eg: YpeeEg
        cam: Camera2D
        combat: Combat

proc newTile(pos: Vec2f): Tile =
    result = new Tile

    result.pos = pos
    result.sprites[0] = newSprite(tileSheet)
    result.sprites[0].pos = vec3f(pos * vec2f(30.0, 18.0), 0.0)
    result.sprites[0].tint = vec4f(0.5 + sin(rand(2.0) * PI) / 2.0, 0.5 + sin(rand(2.0) * PI) / 2.0, 0.5 + sin(rand(2.0) * PI) / 2.0, 1.0)
    result.sprites[0].offset = vec2i(1, 0)
    result.sprites[1] = newSprite(tileSheet)
    result.sprites[1].pos = vec3f(pos * vec2f(30.0, 18.0), 1.0)
    result.sprites[1].tint = vec4f(1.0)
    result.sprites[1].offset = vec2i(0, 0)

proc newBoard(): Board =
    const positions = [
        [-1.0,  2.0], [ 0.0,  2.0], [ 1.0,  2.0], [ 2.0,  2.0],
        [-1.5,  1.0], [-0.5,  1.0], [ 0.5,  1.0], [ 1.5,  1.0], [ 2.5,  1.0],
        [-2.0,  0.0], [-1.0,  0.0], [-0.0,  0.0], [ 1.0,  0.0], [ 2.0,  0.0], [ 3.0,  0.0],
        [-1.5, -1.0], [-0.5, -1.0], [ 0.5, -1.0], [ 1.5, -1.0], [ 2.5, -1.0],
        [-1.0, -2.0], [ 0.0, -2.0], [ 1.0, -2.0], [ 2.0, -2.0]
    ]

    result = new Board

    for pos in positions:
        result.tiles.add(newTile(vec2f(pos[0], pos[1])))

proc main() =
    randomize()

    var
        game = new Game
        eg = newYpeeEg(vec2i(320, 200), smFixed, -1)
    game.eg = eg
    game.cam = newCamera2D(mat4f())

    cursorSheet = newSpriteSheet(vec2i(0, 0), eg.defaultProgram, cursorBmp)
    var cursorSprite = newSprite(cursorSheet, vec2i(-6, 5))
    cursorSprite.tint = vec4f(0.8, 0.4, 0.2, 1.0)

    fontSheet = newSpriteSheet(vec2i(8, 8), eg.defaultProgram, fontBmp)
    var fpsText = newMonoText(fontSheet)
    fpsText.content = "0.0"

    tileSheet = newSpriteSheet(vec2i(32, 24), eg.defaultProgram, tileBmp)

    discard newBoard()

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

        cursorSprite.pos = vec3f(vec2f(eg.mouse.screenPos), 100.0)

        fpsText.pos = vec3f(4.0, eg.screenSize[1].float - 4.0, 10.0)
            
        eg.beginCamera(game.cam)
        tileSheet.draw(eg.renderer)
        eg.layer()
        eg.endCamera()
        cursorSheet.draw(eg.renderer)
        fpsText.draw(eg.renderer)
        eg.layer()

    eg.destroy()

when isMainModule:
    main()