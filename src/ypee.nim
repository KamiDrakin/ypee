import ypee_eg

# temporary
import glm
import glrenderer
import glfw

proc main() =
    var eg: YpeeEg
    eg.init((256, 224), smAdjustWidth)

    const testBmp = staticRead("../textures/temp.bmp")
    var testSheet: SpriteSheet
    testSheet.init((16u, 16u), eg.renderer.program(0), testBmp)

    const mat = mat4f()

    var pPos = vec3f(128.0, 112.0, -100.0)

    while eg.nextFrame():
        eg.processEvents()

        if eg.frameCounter.elapsed >= 5.0:
            echo eg.frameCounter.getFps()

        const moveSpeed = 64.0
        var moveVec = vec3f(0.0)
        if isKeyDown(eg.window, keyDown):
            moveVec.y -= 1.0
        if isKeyDown(eg.window, keyUp):
            moveVec.y += 1.0
        if isKeyDown(eg.window, keyLeft):
            moveVec.x -= 1.0
        if isKeyDown(eg.window, keyRight):
            moveVec.x += 1.0
        if moveVec.length2() > 0.0:
            pPos += moveVec.normalize() * moveSpeed * eg.delta

        eg.renderer.draw(testSheet.shape, testSheet.image, instance(mat.translate(pPos).scale(16.0, 16.0, 1.0), testSheet.at(1, 0)))
        eg.renderer.renderFramed(eg.window.size())
        #eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
