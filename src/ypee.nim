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

        #var testInstances: seq[float32]
        #testInstances.add(cast[array[3, float32]](vec3f(1.0, 0.2, 0.6)))
        #testInstances.add(cast[array[4, float32]](testSheet.at(1, 0)))
        #testInstances.add(cast[array[16, float32]](mat.translate(pPos).scale(16.0, 16.0, 1.0)))
        #echo testInstances
        var instance = instance(vec3f(1.0, 0.4, 0.7)) +
            testSheet.at(1, 0) +
            mat.translate(pPos).scale(16.0, 16.0, 1.0)
        eg.renderer.draw(testSheet.shape, testSheet.image, instance)
        instance =
            instance(vec3f(0.0, 0.6, 0.3)) +
            instance(testSheet.at(1, 0)) +
            instance(mat.translate(pPos).scale(32.0, 32.0, 1.0))
        eg.renderer.draw(testSheet.shape, testSheet.image, instance)
        eg.renderer.renderFramed(eg.window.size())
        #eg.renderer.render()
    
    eg.destroy()

when isMainModule:
    main()
