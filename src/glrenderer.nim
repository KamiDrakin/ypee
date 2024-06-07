import std/tables
import std/sets
import std/algorithm
import std/sequtils

import glm
import opengl
import nimBMP
import std/streams

import custom_utils
import basic_shapes

export basic_shapes

type
    GLProgram* = ref object
        id: GLuint
        vertAttributes: seq[(GLuint, GLsizei)]
        instAttributes: seq[(GLuint, GLsizei)]
        instSize: GLsizei
        uniforms: Table[string, (GLint, GLsizei)]
    GLInstances* = ref object
        data: seq[GLfloat]
        offsets: Strider
        instSize: GLsizei
        buffer: GLuint
        maxLen: int
    GLImage* = ref object
        texture: GLuint
        size*: (GLsizei, GLsizei)
    GLShape* = ref object
        nVertices: GLsizei
        vao: GLuint
        vbo: GLuint
        program*: GLProgram
    GLDrawItem = object
        shape: GLShape
        image: GLImage
        instances: GLInstances
    GLFrame = ref object
        shape: GLShape
        fbo: GLuint
        rbo: GLuint
        texture: GLuint
        size: (GLsizei, GLsizei)
    GLRenderer* = ref object
        usedProgram: GLProgram
        toDraw: seq[GLDrawItem]
        uniformVals: Table[string, seq[GLfloat]]
        clearColor*: (GLfloat, GLfloat, GLfloat)
        frame*: GLFrame

proc newProgram*(vShaderSrc, fShaderSrc: string): GLProgram =

    proc errorCheck(shader: GLuint) =
        var
            success: bool
            infoLog = newString(1024)
        glGetShaderiv(shader, GL_COMPILE_STATUS, cast[ptr GLint](success.addr))
        if success: return
        glGetShaderInfoLog(shader, 1024, nil, infoLog.cstring)
        echo infoLog.cstring
        quit()

    result = new GLProgram

    let
        vShader = glCreateShader(GL_VERTEX_SHADER)
        vShaderTextArr = [vShaderSrc.cstring]
    glShaderSource(vShader, 1, cast[cstringArray](vShaderTextArr.addr), nil)
    glCompileShader(vShader)
    errorCheck(vShader)

    let
        fShader = glCreateShader(GL_FRAGMENT_SHADER)
        fShaderTextArr = [fShaderSrc.cstring]
    glShaderSource(fShader, 1, cast[cstringArray](fShaderTextArr.addr), nil)
    glCompileShader(fShader)
    errorCheck(fShader)

    var success: bool
    result.id = glCreateProgram()
    glAttachShader(result.id, vShader)
    glAttachShader(result.id, fShader)
    glLinkProgram(result.id)
    glGetProgramiv(result.id, GL_LINK_STATUS, cast[ptr GLint](success.addr))
    doAssert success

    glDeleteShader(vShader)
    glDeleteShader(fShader)

proc delete*(program: GLProgram) =
    try:
        glDeleteProgram(program.id)
    except:
        echo "Failed to delete program ", program.id

proc setAttributes*(program: GLProgram; vertAttribs, instAttribs: seq[(string, int)]) =
    for (aName, aSize) in vertAttribs:
        let
            aSize = aSize.GLsizei
            aLoc = glGetAttribLocation(program.id, aName.cstring)
        doAssert aLoc >= 0
        program.vertAttributes.add((aLoc.GLuint, aSize)) 

    program.instSize = 0
    for (aName, aSize) in instAttribs:
        let
            aSize = aSize.GLsizei
            aLoc = glGetAttribLocation(program.id, aName.cstring)
        doAssert aLoc >= 0
        program.instAttributes.add((aLoc.GLuint, aSize))
        program.instSize += aSize

proc setUniforms*(program: GLProgram; uniforms: seq[(string, int)]) =
    for (uName, uSize) in uniforms:
        let
            uLoc = glGetUniformLocation(program.id, uName.cstring)
        program.uniforms[uName] = (uLoc, uSize.GLsizei)

proc enableAttributes(program: GLProgram; divisor: GLuint) =
    let attributes = if divisor == 0: program.vertAttributes else: program.instAttributes
    var
        stride = 0
        totalSize = 0
    for (_, aSize) in attributes:
        stride += aSize
    for (aLoc, aSize) in attributes:
        let
            aSizeSqrt = sqrt(aSize.float).GLsizei
            repeat = if aSizeSqrt > 2: aSize div aSizeSqrt else: 0 # works only for even matrices i guess
            aSize: GLsizei = if repeat > 0: aSizeSqrt else: aSize
        for i in countup(0, repeat):
            let i = i.GLuint
            glEnableVertexAttribArray(aLoc + i)
            glVertexAttribPointer(aLoc + i, aSize, cGL_FLOAT, false, (sizeof(GLFloat) * stride).GLsizei, cast[pointer](sizeof(GLfloat) * totalSize))
            if divisor > 0:
                glVertexAttribDivisor(aLoc + i, divisor)
            totalSize += aSize

proc newInstances*(shape: GLShape; initLen: int): GLInstances =
    result = new GLInstances

    result.data = newSeqOfCap[GLfloat](initLen)
    result.instSize = shape.program.instSize
    result.maxLen = initLen

    glGenBuffers(1, result.buffer.addr)
    
    glBindVertexArray(shape.vao)
    glBindBuffer(GL_ARRAY_BUFFER, result.buffer)
    
    glBufferData(GL_ARRAY_BUFFER, (result.maxLen * sizeof(GLfloat)).GLsizeiptr, nil, GL_DYNAMIC_DRAW)
    shape.program.enableAttributes(1)

    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindVertexArray(0)

proc delete*(insts: GLinstances) =
    try:
        glDeleteBuffers(1, insts.buffer.addr)
    except:
        echo "Failed to delete instance buffer ", insts.buffer

proc len(insts: GLInstances): int =
    insts.data.len div insts.instSize

proc add*[T](insts: GLInstances; data: T): ref int =
    const size = sizeof(T) div sizeof(GLfloat)
    let data = cast[array[size, GLfloat]](data)
    result = insts.offsets.add(size)
    insts.data.add(data)

proc del*(insts: GLInstances; offset: ref int) =  
    let
        i = insts.offsets.find(offset)
        last =
            if i == insts.offsets.high:
                insts.data.high
            else:
                insts.offsets[i + 1][] - 1
    for i in countdown(last, offset[]):
        insts.data.del(i)
    insts.offsets.del(i)

proc `[]=`*[T](insts: GLInstances; i: int; v: T) =
    cast[ptr T](insts.data[i].addr)[] = v

proc add(insts1: GLInstances; insts2: GLInstances) =
    insts1.data.add(insts2.data)

proc clear*(insts: GLInstances) =
    insts.data.setLen(0)
    insts.offsets.clear()

proc resize(insts: GLInstances) =
    while insts.data.len > insts.maxLen:
        insts.maxLen *= 2
    glBufferData(GL_ARRAY_BUFFER, (insts.maxLen * sizeof(GLfloat)).GLsizeiptr, nil, GL_DYNAMIC_DRAW)

proc bufferData(insts: GLInstances) =
    glBindBuffer(GL_ARRAY_BUFFER, insts.buffer)
    if insts.data.len > insts.maxLen:
        insts.resize()
    glBufferSubData(GL_ARRAY_BUFFER, 0, (insts.data.len * sizeof(GLfloat)).GLsizeiptr, insts.data[0].addr)
    glBindBuffer(GL_ARRAY_BUFFER, 0)

proc newImage*(bmpStr: string): GLImage =
    result = new GLImage

    let
        sStream = newStringStream(bmpStr)
        rBmp = decodeBMP(sStream)
    sStream.close()
    doAssert rBmp != nil
    let
        bmp = convert[string](rBmp, 24)
        data = bmp.data.bmpDataFlip(bmp.width)
    doAssert bmp.width > 0 and bmp.height > 0
    result.size = (bmp.width.GLsizei, bmp.height.GLsizei)
    glGenTextures(1, result.texture.addr)
    glBindTexture(GL_TEXTURE_2D, result.texture)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.GLint, result.size[0], result.size[1], 0, GL_RGB, GL_UNSIGNED_BYTE, data.cstring)
    glBindTexture(GL_TEXTURE_2D, 0)

proc delete*(image: GLImage) =
    try:
        glDeleteTextures(1, image.texture.addr)
    except:
        echo "Failed to delete texture ", image.texture

proc `<`*(image1, image2: GLImage): bool =
    image1.texture < image2.texture

proc newShape*(program: GLProgram; vertices: seq[GLVertex]): GLShape =
    result = new GLShape

    result.nVertices = vertices.len.GLsizei
    result.program = program
    
    glGenVertexArrays(1, result.vao.addr)

    glGenBuffers(1, result.vbo.addr)

    glBindVertexArray(result.vao)
    glBindBuffer(GL_ARRAY_BUFFER, result.vbo)
    
    glBufferData(GL_ARRAY_BUFFER, (vertices.len * sizeof(GLVertex)).GLsizeiptr, vertices[0].addr, GL_STATIC_DRAW)

    program.enableAttributes(0)

    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindVertexArray(0)

proc delete*(shape: GLShape) =
    try:
        glDeleteBuffers(1, shape.vbo.addr)
    except:
        echo "Failed to delete VBO ", shape.vbo
    try:
        glDeleteVertexArrays(1, shape.vao.addr)
    except:
        echo "Failed to delete VAO ", shape.vao

func drawItemCmp(x, y: GLDrawItem): int =
    let shapeCmp = cmp(x.shape, y.shape)
    if shapeCmp != 0:
        shapeCmp
    else:
        cmp(x.image, y.image)

proc resize*(frame: GLFrame; size: Vec2i) =
    if frame.fbo == 0: return
    let size = (size.x.GLsizei, size.y.GLsizei)
    frame.size = size

    glBindFramebuffer(GL_FRAMEBUFFER, frame.fbo)

    glBindTexture(GL_TEXTURE_2D, frame.texture)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.GLint, size[0], size[1], 0, GL_RGB, GL_UNSIGNED_BYTE, nil)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint) # temporary "fix"
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint)
    glBindTexture(GL_TEXTURE_2D, 0)
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, frame.texture, 0)

    glBindRenderbuffer(GL_RENDERBUFFER, frame.rbo)
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, size[0], size[1])  
    glBindRenderbuffer(GL_RENDERBUFFER, 0)
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, frame.rbo)

    doAssert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc newFrame*(size: Vec2i): GLFrame =
    result = new GLFrame

    const
        vShaderSrc = staticRead("shaders/ypee/frame.vs")
        fShaderSrc = staticRead("shaders/ypee/frame.fs")
    var program: GLProgram
    program = newProgram(vShaderSrc, fShaderSrc)
    program.setAttributes(@[("vPos", 3), ("vColor", 3), ("vTexCoords", 2)], @[])
    program.setUniforms(@[("frameScale", 2)])
    result.shape = newShape(program, frameVertices)

    glGenFramebuffers(1, result.fbo.addr)
    glGenTextures(1, result.texture.addr)
    glGenRenderbuffers(1, result.rbo.addr)

    result.resize(size)

proc delete*(frame: GLFrame) =
    try:
        glDeleteTextures(1, frame.texture.addr)
    except:
        echo "Failed to delete framebuffer texture"
    try:
        glDeleteFramebuffers(1, frame.fbo.addr)
    except:
        echo "Failed to delete framebuffer"
    frame.shape.delete()
    frame.shape.program.delete()

proc newRenderer*(): GLRenderer =
    result = new GLRenderer
    loadExtensions()
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glEnable(GL_CULL_FACE)
    glFrontFace(GL_CW)

proc delete*(renderer: GLRenderer) =
    renderer.frame.delete()

proc setUniform*[T](renderer: GLRenderer; name: string; val: T) =
    const size = sizeof(T) div sizeof(GLfloat)
    let
        valFloats = cast[array[size, GLfloat]](val)
        valSeq = valFLoats.toSeq
    renderer.uniformVals[name] = valSeq

proc use(renderer: GLRenderer; program: GLProgram) =
    if renderer.usedProgram != nil and program == renderer.usedProgram: return
    renderer.usedProgram = program
    glUseProgram(program.id)
    
proc use(renderer: GLRenderer; image: GLImage) =
    var texSize: Vec2f
    if image != nil:
        glBindTexture(GL_TEXTURE_2D, image.texture)
        texSize = vec2f(image.size[0].GLfloat, image.size[1].GLfloat)
    else:
        texSize = vec2f(0.0)
    renderer.setUniform("texSize", cast[ptr GLfloat](texSize))

proc use(renderer: GLRenderer; shape: GLShape) =
    renderer.use(shape.program)
    glBindVertexArray(shape.vao)

proc applyUniforms(renderer: GLRenderer) =
    let uniforms = renderer.usedProgram[].uniforms
    for k, (uLoc, uSize) in uniforms:
        let valPtr = renderer.uniformVals[k][0].addr
        case uSize
            of 1: glUniform1fv(uLoc, 1.GLsizei, valPtr)
            of 2: glUniform2fv(uLoc, 1.GLsizei, valPtr)
            of 3: glUniform3fv(uLoc, 1.GLsizei, valPtr)
            of 4: glUniform4fv(uLoc, 1.GLsizei, valPtr)
            of 16: glUniformMatrix4fv(uLoc, 1.GLsizei, false, valPtr)
            else: discard

proc draw*(renderer: GLRenderer; shape: GLShape; image: GLImage; insts: GLInstances) =
    var item: GLDrawItem
    item.shape = shape
    item.image = image
    let searchPos = renderer.toDraw.binarySearch(item, drawItemCmp)
    if searchPos == -1:
        renderer.use(shape)
        item.instances = new GLInstances
        item.instances[] = insts[]
        renderer.toDraw.add(item)
    else:
        renderer.toDraw[searchPos].instances.add(insts) # someday someone will optimise this

proc layer(renderer: GLRenderer; bufferSize: (GLsizei, GLsizei)) =
    glViewport(0, 0, bufferSize[0], bufferSize[1])
    glClear(GL_DEPTH_BUFFER_BIT)
    glEnable(GL_DEPTH_TEST)
    renderer.toDraw.sort(drawItemCmp)
    var
        lastShape: GLShape
        lastImage: GLImage
    for item in renderer.toDraw.mitems:
        if item.instances.len == 0: continue
        if item.shape != lastShape:
            renderer.use(item.shape)
            lastShape = item.shape
        if item.image == nil or item.image != lastImage:
            renderer.use(item.image)
            lastImage = item.image
        renderer.applyUniforms()
        item.instances.bufferData()
        glDrawArraysInstanced(GL_TRIANGLES, 0, item.shape.nVertices, item.instances.len.GLsizei)
        item.instances.clear()

proc layer*(renderer: GLRenderer; bufferSize: Vec2i) =
    renderer.layer((bufferSize.x.GLsizei, bufferSize.y.GLsizei))

proc layerFramed*(renderer: GLRenderer) =
    glBindFramebuffer(GL_FRAMEBUFFER, renderer.frame.fbo)
    renderer.layer(renderer.frame.size)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc clear*(renderer: GLRenderer) =
    glClearColor(renderer.clearColor[0], renderer.clearColor[1], renderer.clearColor[2], 1.0)
    glClear(GL_COLOR_BUFFER_BIT)

proc clearFrame*(renderer: GLRenderer) =
    glBindFramebuffer(GL_FRAMEBUFFER, renderer.frame.fbo)
    renderer.clear()
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc renderFrame*(renderer: GLRenderer; windowSize: Vec2i; letterbox: bool) =
    glViewport(0, 0, windowSize.x, windowSize.y)
    glClearColor(0.0, 0.0, 0.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT)
    glDisable(GL_DEPTH_TEST)
    renderer.use(renderer.frame.shape)
    glBindTexture(GL_TEXTURE_2D, renderer.frame.texture)
    if letterbox:
        let
            xRatio = renderer.frame.size[0].GLfloat / windowSize[0].GLfloat
            yRatio = renderer.frame.size[1].GLfloat / windowSize[1].GLfloat
            higherRatio = max(xRatio, yRatio)
            scale = vec2f(xRatio, yRatio) / higherRatio
        renderer.setUniform("frameScale", scale)
    else:
        renderer.setUniform("frameScale", vec2f(1.0))
    renderer.applyUniforms()
    glDrawArrays(GL_TRIANGLES, 0, renderer.frame.shape.nVertices)
    renderer.usedProgram = nil