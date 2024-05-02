import std/tables
import std/algorithm

import glm
import glad/gl
from glfw import getProcAddress
import nimBMP
import std/streams

import custom_utils
import basic_shapes

export basic_shapes

type
    GLProgram* = object
        id: GLuint
        vertAttributes: seq[(GLuint, GLsizei)]
        instAttributes: seq[(GLuint, GLsizei)]
        uniforms: Table[string, (GLint, GLsizei)]
    GLTexture = GLuint
    GLRect* = object
        x, y, w, h: GLfloat
    GLInstance* = object
        texRect: GLRect
        modelMat: Mat4x4f
    GLInstanceSeq = object
        instances: seq[GLInstance]
        buffer: GLuint
        maxLen: int
    GLImage* = object
        texture: GLTexture
        size: (GLsizei, GLsizei)
    GLShape* = object
        nVertices: GLsizei
        vao: GLuint
        program: GLProgram
    GLDrawItem = object
        shape: ptr GLShape
        image: ptr GLImage
        instances: GLInstanceSeq
    GLFrame = object
        shape: GLShape
        fbo: GLuint
        texture: GLuint
        size: (GLsizei, GLsizei)
    GLRenderer* = object
        programs: Table[uint, GLProgram]
        usedProgram: ptr GLProgram
        toDraw: seq[GLDrawItem]
        uniformVals: Table[string, ptr GLfloat]
        clearColor*: (GLfloat, GLfloat, GLfloat)
        frame*: GLFrame

proc init*(program: var GLProgram; vShaderSrc, fShaderSrc: string) =

    proc errorCheck(shader: GLuint) =
        var
            success: bool
            infoLog = newString(1024)
        glGetShaderiv(shader, GL_COMPILE_STATUS, cast[ptr GLint](success.addr))
        if success: return
        glGetShaderInfoLog(shader, 1024, nil, infoLog.cstring)
        echo infoLog.cstring
        quit()

    var
        vShader = glCreateShader(GL_VERTEX_SHADER)
        vShaderTextArr = [vShaderSrc.cstring]
    glShaderSource(vShader, 1, cast[cstringArray](vShaderTextArr.addr), nil);
    glCompileShader(vShader)
    errorCheck(vShader)

    var
        fShader = glCreateShader(GL_FRAGMENT_SHADER)
        fShaderTextArr = [fShaderSrc.cstring]
    glShaderSource(fShader, 1, cast[cstringArray](fShaderTextArr.addr), nil);
    glCompileShader(fShader)
    errorCheck(fShader)

    var success: bool
    program.id = glCreateProgram()
    glAttachShader(program.id, vShader)
    glAttachShader(program.id, fShader)
    glLinkProgram(program.id)
    glGetProgramiv(program.id, GL_LINK_STATUS, cast[ptr GLint](success.addr))
    assert success

    glDeleteShader(vShader)
    glDeleteShader(fShader)

proc setAttributes*(program: var GLProgram; vertAttribs, instAttribs: seq[(string, int)]) =
    for (aName, aSize) in vertAttribs:
        let 
            aSize = aSize.GLsizei
            aLoc = glGetAttribLocation(program.id, aName.cstring)
        assert aLoc >= 0
        program.vertAttributes.add((aLoc.GLuint, aSize)) 

    for (aName, aSize) in instAttribs:
        let 
            aSize = aSize.GLsizei
            aLoc = glGetAttribLocation(program.id, aName.cstring)
        assert aLoc >= 0
        program.instAttributes.add((aLoc.GLuint, aSize))

proc setUniforms*(program: var GLProgram; uniforms: seq[(string, int)]) =
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
        let aSizeSqrt = sqrt(aSize.float).GLsizei
        let repeat = if aSizeSqrt > 2: aSize div aSizeSqrt else: 0 # works only for even matrices i guess
        let aSize: GLsizei = if repeat > 0: aSizeSqrt else: aSize
        for i in countup(0, repeat):
            let i = i.GLuint
            glEnableVertexAttribArray(aLoc + i)
            glVertexAttribPointer(aLoc + i, aSize, cGL_FLOAT, false, (sizeof(GLFloat) * stride).GLsizei, cast[pointer](sizeof(GLfloat) * totalSize))
            if divisor > 0:
                glVertexAttribDivisor(aLoc + i, divisor)
            totalSize += aSize

proc rect*(x, y, w, h: GLfloat): GLRect =
    GLRect(x: x, y: y, w: w, h: h)

proc instance*(modelMat: Mat4x4f; texRect: GLRect): GLinstance =
    GLInstance(texRect: texRect, modelMat: modelMat)

proc instance*(modelMat: Mat4x4f): GLinstance =
    const noRect = rect(0, 0, 0, 0)
    GLInstance(texRect: noRect, modelMat: modelMat)

proc init(instSeq: var GLInstanceSeq; program: GLProgram; initLen: int) =
    instSeq.maxLen = initLen

    glGenBuffers(1, instSeq.buffer.addr);

    glBindBuffer(GL_ARRAY_BUFFER, instSeq.buffer)
    glBufferData(GL_ARRAY_BUFFER, (instSeq.maxLen * sizeof(GLInstance)).GLsizeiptr, nil, GL_DYNAMIC_DRAW)

    program.enableAttributes(1)

proc len(instSeq: GLInstanceSeq): int =
    instSeq.instances.len()

proc add(instSeq: var GLInstanceSeq; inst: GLInstance) =
    instSeq.instances.add(inst)

proc clear(instSeq: var GLInstanceSeq) =
    instSeq.instances.setLen(0)

proc resize(instSeq: var GLInstanceSeq) =
    instSeq.maxLen *= 2
    glBufferData(GL_ARRAY_BUFFER, (instSeq.maxLen * sizeof(GLInstance)).GLsizeiptr, instSeq.instances[0].addr, GL_DYNAMIC_DRAW)

proc bufferData(instSeq: var GLInstanceSeq) =
    glBindBuffer(GL_ARRAY_BUFFER, instSeq.buffer)
    if instSeq.instances.len() > instSeq.maxLen:
        instSeq.resize()
    else:
        glBufferSubData(GL_ARRAY_BUFFER, 0, (instSeq.len() * sizeof(GLInstance)).GLsizeiptr, instSeq.instances[0].addr)

proc init*(image: var GLImage; bmpStr: string) =
    let rBmp = decodeBMP(newStringStream(bmpStr))
    assert rBmp != nil
    let
        bmp = convert[string](rBmp, 24)
        data = bmp.data.bmpDataFlip(bmp.width)
    assert bmp.width > 0 and bmp.height > 0
    image.size = (bmp.width.GLsizei, bmp.height.GLsizei)
    glGenTextures(1, image.texture.addr)
    glBindTexture(GL_TEXTURE_2D, image.texture)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)
    #glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.GLint, image.size[0], image.size[1], 0, GL_RGB, GL_UNSIGNED_BYTE, data.cstring)
    #glGenerateMipmap(GL_TEXTURE_2D)

proc init*(shape: var GLShape; program: GLProgram; vertices: seq[GLVertex]) =
    shape.nVertices = vertices.len().GLsizei
    shape.program = program
    
    glGenVertexArrays(1, shape.vao.addr)

    var vbo: GLuint
    glGenBuffers(1, vbo.addr)

    glBindVertexArray(shape.vao)

    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    glBufferData(GL_ARRAY_BUFFER, (vertices.len() * sizeof(GLVertex)).GLsizeiptr, vertices[0].addr, GL_STATIC_DRAW)

    program.enableAttributes(0)

func drawItemCmp(x, y: GLDrawItem): int =
    if x.shape < y.shape:
        return -1
    elif x.shape > y.shape:
        return 1
    if x.image < y.image:
        return -1
    elif x.image > y.image:
        return 1
    return 0

proc init*(frame: var GLFrame; size: (GLsizei, GLsizei)) =
    const
        vShaderSrc = staticRead("shaders/frame.vs")
        fShaderSrc = staticRead("shaders/frame.fs")
    var program: GLProgram
    program.init(vShaderSrc, fShaderSrc)
    program.setAttributes(@[("vPos", 3), ("vColor", 3), ("vTexCoords", 2)], @[])
    program.setUniforms(@[("frameScale", 2)])
    frame.shape.init(program, frameVertices)

    frame.size = size

    glGenFramebuffers(1, frame.fbo.addr)
    glBindFramebuffer(GL_FRAMEBUFFER, frame.fbo)

    glGenTextures(1, frame.texture.addr)
    glBindTexture(GL_TEXTURE_2D, frame.texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.GLint, size[0], size[1], 0, GL_RGB, GL_UNSIGNED_BYTE, nil)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
    glBindTexture(GL_TEXTURE_2D, 0)
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, frame.texture, 0)

    var rbo: GLuint
    glGenRenderbuffers(1, rbo.addr);
    glBindRenderbuffer(GL_RENDERBUFFER, rbo); 
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, size[0], size[1])  
    glBindRenderbuffer(GL_RENDERBUFFER, 0)
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo)

    assert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc init*(renderer: var GLRenderer) =
    renderer.usedProgram = nil
    assert gladLoadGL(glfw.getProcAddress)

proc addProgram*(renderer: var GLRenderer; key: uint; vShaderSrc, fShaderSrc: string) =
    var program: GLProgram
    program.init(vShaderSrc, fShaderSrc)
    program.setAttributes(
        @[("vPos", 3), ("vColor", 3), ("vTexCoords", 2)],
        @[("texRect", 4), ("modelMat", 16)]
    ) # move this
    program.setUniforms(@[("texSize", 2), ("viewMat", 16), ("projMat", 16)]) # move this?
    renderer.programs[key] = program
    if renderer.usedProgram == nil:
        renderer.usedProgram = renderer.programs[key].addr
        glUseProgram(program.id)

proc program*(renderer: GLRenderer; key: uint): GLProgram =
    return renderer.programs[key]

proc setUniform*(renderer: var GLRenderer; name: string; valPtr: ptr GLfloat) =
    if not renderer.uniformVals.hasKey(name):
        renderer.uniformVals[name] = valPtr
        return
    let oldPtr = renderer.uniformVals[name]
    if oldPtr != nil:
        dealloc(oldPtr)
    renderer.uniformVals[name] = valPtr

proc use(renderer: var GLRenderer; program: GLProgram) =
    if renderer.usedProgram != nil and program.id == renderer.usedProgram[].id: return
    renderer.usedProgram = program.addr
    glUseProgram(program.id)
    
proc use(renderer: var GLRenderer; image: GLImage) =
    let imageSize = cast[ptr Vec2f](alloc(sizeof(Vec2f)))
    imageSize[] = vec2f(image.size[0].GLfloat, image.size[1].GLfloat)
    renderer.setUniform("texSize", cast[ptr GLfloat](imageSize))
    #glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, image.texture)

proc use(renderer: var GLRenderer; shape: GLShape) =
    renderer.use(shape.program)
    glBindVertexArray(shape.vao)

proc applyUniforms(renderer: var GLRenderer) =
    let uniforms = renderer.usedProgram[].uniforms
    for k, (uLoc, uSize) in uniforms:
        let val = renderer.uniformVals[k]
        case uSize
            of 1: glUniform1fv(uLoc, 1.GLsizei, val)
            of 2: glUniform2fv(uLoc, 1.GLsizei, val)
            of 3: glUniform3fv(uLoc, 1.GLsizei, val)
            of 4: glUniform4fv(uLoc, 1.GLsizei, val)
            of 16: glUniformMatrix4fv(uLoc, 1.GLsizei, false, val)
            else: discard

    #let viewMat = cast[Mat4x4[GLfloat]](renderer.viewMat)
    #glUniformMatrix4fv(renderer.uniform("viewMat")[0], 1.GLsizei, false, cast[ptr GLfloat](viewMat.addr))
    #let projMat = cast[Mat4x4[GLfloat]](renderer.projMat)
    #glUniformMatrix4fv(renderer.uniform("projMat")[0], 1.GLsizei, false, cast[ptr GLfloat](projMat.addr))

proc draw*(renderer: var GLRenderer; shape: GLShape; image: GLImage; instance: GLInstance) =
    var item: GLDrawItem
    item.shape = shape.addr
    item.image = image.addr
    let searchPos = renderer.toDraw.binarySearch(item, drawItemCmp)
    if searchPos == -1:
        renderer.use(shape)
        item.instances.init(renderer.usedProgram[], 4)
        item.instances.add(instance)
        renderer.toDraw.add(item)
    else:
        renderer.toDraw[searchPos].instances.add(instance)

proc render*(renderer: var GLRenderer) =
    glClearColor(renderer.clearColor[0], renderer.clearColor[1], renderer.clearColor[2], 1.0)
    glClear((GL_COLOR_BUFFER_BIT.uint + GL_DEPTH_BUFFER_BIT.uint).GLbitfield)
    glEnable(GL_DEPTH_TEST)
    renderer.toDraw.sort(drawItemCmp)
    var
        lastShape: ptr GLShape = nil
        lastImage: ptr GLImage = nil
    for item in renderer.toDraw:
        if item.instances.len() == 0: continue
        if item.shape != lastShape:
            renderer.use(item.shape[])
            lastShape = item.shape
        if item.image != lastImage:
            renderer.use(item.image[])
            lastImage = item.image
        renderer.applyUniforms()
        let itemPtr = item.addr
        itemPtr[].instances.bufferData()
        glDrawArraysInstanced(GL_TRIANGLES, 0, item.shape[].nVertices, item.instances.len().GLsizei)
        itemPtr[].instances.clear()

proc renderFramed*(renderer: var GLRenderer; windowSize: (GLsizei, GLsizei)) =
    glBindFramebuffer(GL_FRAMEBUFFER, renderer.frame.fbo)
    glViewport(0, 0, renderer.frame.size[0], renderer.frame.size[1])
    renderer.render()
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glViewport(0, 0, windowSize[0], windowSize[1])
    glClearColor(0.0, 0.0, 0.0, 1.0)
    glClear(GL_COLOR_BUFFER_BIT)
    glDisable(GL_DEPTH_TEST)
    renderer.use(renderer.frame.shape)
    #glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, renderer.frame.texture)
    let
        scalePtr = cast[ptr Vec2f](alloc(sizeof(Vec2f)))
        xRatio = renderer.frame.size[0].GLfloat / windowSize[0].GLfloat
        yRatio = renderer.frame.size[1].GLfloat / windowSize[1].GLfloat
        higherRatio = max(xRatio, yRatio)
    scalePtr[] = vec2f(xRatio, yRatio) / higherRatio
    renderer.setUniform("frameScale", cast[ptr GLfloat](scalePtr))
    renderer.applyUniforms()
    glDrawArrays(GL_TRIANGLES, 0, renderer.frame.shape.nVertices)
    renderer.usedProgram = nil