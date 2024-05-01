import std/tables
import std/algorithm

import glm
import glad/gl
from glfw import getProcAddress
import nimBMP

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
    GLRenderer* = object
        programs: Table[uint, GLProgram]
        usedProgram: ptr GLProgram
        toDraw: seq[GLDrawItem]

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

proc instance*(texRect: GLRect; modelMat: Mat4x4f): GLinstance =
    GLInstance(texRect: texRect, modelMat: modelMat)

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

proc init*(image: var GLImage; path: string) =
    let bmp = loadBMP24(path)
    let data = bmp.data.bmpDataFlip(bmp.width)
    assert bmp.width > 0 and bmp.height > 0
    image.size = (bmp.width.GLsizei, bmp.height.GLsizei)
    glGenTextures(1, image.texture.addr)
    glBindTexture(GL_TEXTURE_2D, image.texture)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.GLint, image.size[0], image.size[1], 0, GL_RGB, GL_UNSIGNED_BYTE, data.cstring)

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

proc init*(renderer: var GLRenderer) =
    renderer.usedProgram = nil
    assert gladLoadGL(glfw.getProcAddress)
    glEnable(GL_DEPTH_TEST)

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

proc uniform(renderer: GLRenderer; name: string): (GLint, GLsizei) =
    return renderer.usedProgram[].uniforms[name]

proc use(renderer: var GLRenderer; program: GLProgram) =
    if program.id == renderer.usedProgram[].id: return
    renderer.usedProgram = program.addr
    glUseProgram(program.id)
    
proc use(renderer: GLRenderer; image: GLImage) =
    let imageSize = [image.size[0].GLfloat, image.size[1].GLfloat]
    let (uLoc, _) = renderer.uniform("texSize")
    glUniform2fv(uLoc, 1.GLsizei, cast[ptr GLfloat](imageSize[0].addr))
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, image.texture)

proc use(renderer: var GLRenderer; shape: GLShape) =
    renderer.use(shape.program)
    glBindVertexArray(shape.vao)

proc setViewMat*(renderer: var GLRenderer; mat: Mat4x4f) =
    let mat = cast[Mat4x4[GLfloat]](mat)
    glUniformMatrix4fv(renderer.uniform("viewMat")[0], 1.GLsizei, false, cast[ptr GLfloat](mat.addr))

proc setProjMat*(renderer: var GLRenderer; mat: Mat4x4f) =
    let mat = cast[Mat4x4[GLfloat]](mat)
    glUniformMatrix4fv(renderer.uniform("projMat")[0], 1.GLsizei, false, cast[ptr GLfloat](mat.addr))

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
        let itemPtr = item.addr
        itemPtr[].instances.bufferData()
        glDrawArraysInstanced(GL_TRIANGLES, 0, item.shape[].nVertices, item.instances.len().GLsizei)
        itemPtr[].instances.clear()