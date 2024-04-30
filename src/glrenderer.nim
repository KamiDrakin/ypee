import std/tables
import std/algorithm

import glm
import glad/gl
from glfw import getProcAddress
import nimBMP

import custom_utils

type
    GLVao = GLuint
    GLProgram = object
        id: GLuint
        attributes: Table[string, GLuint]
        uniforms: Table[string, GLint]
    GLTexture = GLuint
    GLVertex* = object
        x, y, z: GLfloat
        r, g, b: GLfloat
        u, v: GLfloat
    GLIndex* = object
        v1, v2, v3: GLuint
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
        nIndices: GLsizei
        vao: GLVao
        program: GLProgram
    GLDrawItem = object
        shape: ptr GLShape
        image: ptr GLImage
        instances: GLInstanceSeq
    GLRenderer* = object
        programs: Table[uint, GLProgram]
        usedProgram: ptr GLProgram
        toDraw: seq[GLDrawItem]

proc init(program: var GLProgram; vShaderSrc, fShaderSrc: string; uniforms: seq[string]) =

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

    const attributes = ["vPos", "vColor", "vTexCoords", "texRect", "modelMat"]
    for attr in attributes:
        let attrPos = glGetAttribLocation(program.id, attr.cstring)
        assert attrPos >= 0
        program.attributes[attr] = attrPos.GLuint

    for uni in uniforms:
        program.uniforms[uni] = glGetUniformLocation(program.id, uni.cstring)

    glDeleteShader(vShader)
    glDeleteShader(fShader)

proc vertex*(x, y, z, r, g, b, u, v: GLFloat): GLVertex =
    GLVertex(x: x, y: y, z: z, r: r, g: g, b: b, u: u, v: v)

proc index*(v1, v2, v3: GLuint): GLIndex =
    GLIndex(v1: v1, v2: v2, v3: v3)

proc rect*(x, y, w, h: GLfloat): GLRect =
    GLRect(x: x, y: y, w: w, h: h)

proc instance*(texRect: GLRect; modelMat: Mat4x4f): GLinstance =
    GLInstance(texRect: texRect, modelMat: modelMat)

proc init(instSeq: var GLInstanceSeq; program: GLProgram; initLen: int) =
    instSeq.maxLen = initLen

    glGenBuffers(1, instSeq.buffer.addr);

    glBindBuffer(GL_ARRAY_BUFFER, instSeq.buffer)
    glBufferData(GL_ARRAY_BUFFER, (instSeq.maxLen * sizeof(GLInstance)).GLsizeiptr, nil, GL_DYNAMIC_DRAW)

    glEnableVertexAttribArray(program.attributes["texRect"])
    glVertexAttribPointer(program.attributes["texRect"], 4, cGL_FLOAT, false, sizeof(GLInstance).GLsizei, cast[pointer](0))

    glEnableVertexAttribArray(program.attributes["modelMat"])
    glVertexAttribPointer(program.attributes["modelMat"], 4, cGL_FLOAT, false, sizeof(GLInstance).GLsizei, cast[pointer](sizeof(Vec4f)))
    glEnableVertexAttribArray(program.attributes["modelMat"] + 1)
    glVertexAttribPointer(program.attributes["modelMat"] + 1, 4, cGL_FLOAT, false, sizeof(GLInstance).GLsizei, cast[pointer](sizeof(Vec4f) * 2))
    glEnableVertexAttribArray(program.attributes["modelMat"] + 2)
    glVertexAttribPointer(program.attributes["modelMat"] + 2, 4, cGL_FLOAT, false, sizeof(GLInstance).GLsizei, cast[pointer](sizeof(Vec4f) * 3))
    glEnableVertexAttribArray(program.attributes["modelMat"] + 3)
    glVertexAttribPointer(program.attributes["modelMat"] + 3, 4, cGL_FLOAT, false, sizeof(GLInstance).GLsizei, cast[pointer](sizeof(Vec4f) * 4))
    
    glVertexAttribDivisor(program.attributes["texRect"], 1)
    glVertexAttribDivisor(program.attributes["modelMat"], 1)
    glVertexAttribDivisor(program.attributes["modelMat"] + 1, 1)
    glVertexAttribDivisor(program.attributes["modelMat"] + 2, 1)
    glVertexAttribDivisor(program.attributes["modelMat"] + 3, 1)

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

proc init*(shape: var GLShape; program: GLProgram; vertices: seq[GLVertex]; indices: seq[GLIndex]) =
    shape.nIndices = indices.len().GLsizei
    shape.program = program
    
    glGenVertexArrays(1, shape.vao.addr)

    var vbo, ebo: GLuint
    glGenBuffers(1, vbo.addr)
    glGenBuffers(1, ebo.addr)

    glBindVertexArray(shape.vao)

    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    glBufferData(GL_ARRAY_BUFFER, (vertices.len() * sizeof(GLVertex)).GLsizeiptr, vertices[0].addr, GL_STATIC_DRAW)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, (vertices.len() * sizeof(GLIndex)).GLsizeiptr, indices[0].addr, GL_STATIC_DRAW)
    glEnableVertexAttribArray(program.attributes["vPos"])
    glVertexAttribPointer(program.attributes["vPos"], 3, cGL_FLOAT, false, sizeof(GLVertex).GLsizei, nil)
    glEnableVertexAttribArray(program.attributes["vColor"])
    glVertexAttribPointer(program.attributes["vColor"], 3, cGL_FLOAT, false, sizeof(GLVertex).GLsizei, cast[pointer](sizeof(GLfloat) * 3))
    glEnableVertexAttribArray(program.attributes["vTexCoords"])
    glVertexAttribPointer(program.attributes["vTexCoords"], 2, cGL_FLOAT, false, sizeof(GLVertex).GLsizei, cast[pointer](sizeof(GLfloat) * 6))

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

proc addProgram*(renderer: var GLRenderer; key: uint; vShaderSrc, fShaderSrc: string; uniforms: seq[string]) =
    var program: GLProgram
    program.init(vShaderSrc, fShaderSrc, uniforms)
    renderer.programs[key] = program
    if renderer.usedProgram == nil:
        renderer.usedProgram = renderer.programs[key].addr
        glUseProgram(program.id)

proc program*(renderer: GLRenderer; key: uint): GLProgram =
    return renderer.programs[key]

proc uniform(renderer: GLRenderer; name: string): GLint =
    return renderer.usedProgram[].uniforms[name]

proc use(renderer: var GLRenderer; program: GLProgram) =
    if program.id == renderer.usedProgram[].id: return
    renderer.usedProgram = program.addr
    glUseProgram(program.id)
    
proc use(renderer: GLRenderer; image: GLImage) =
    let imageSize = [image.size[0].GLfloat, image.size[1].GLfloat]
    glUniform2fv(renderer.uniform("texSize"), 1.GLsizei, cast[ptr GLfloat](imageSize[0].addr))
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, image.texture)

proc use(renderer: var GLRenderer; shape: GLShape) =
    renderer.use(shape.program)
    glBindVertexArray(shape.vao)

#proc useProgram(renderer: var GLRenderer; key: uint) =
#    renderer.useProgram(renderer.programs[key])

proc setViewMat*(renderer: var GLRenderer; mat: Mat4x4f) =
    let mat = cast[Mat4x4[GLfloat]](mat)
    glUniformMatrix4fv(renderer.uniform("viewMat"), 1.GLsizei, false, cast[ptr GLfloat](mat.addr))

proc setProjMat*(renderer: var GLRenderer; mat: Mat4x4f) =
    let mat = cast[Mat4x4[GLfloat]](mat)
    glUniformMatrix4fv(renderer.uniform("projMat"), 1.GLsizei, false, cast[ptr GLfloat](mat.addr))

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

# memories how they fade so fast
#proc draw*(renderer: var GLRenderer; shape: GLShape; image: GLImage) =
#    let fullRect = rect(0.0, 0.0, image.size[0].GLfloat, image.size[1].GLfloat)
#    const idMat = mat4f()
#    renderer.draw(shape, image, instance(fullRect, idMat))

proc render*(renderer: var GLRenderer) =
    renderer.toDraw.sort(drawItemCmp)
    var
        lastShape: ptr GLShape = nil
        lastImage: ptr GLImage = nil
    for item in renderer.toDraw:
        if item.shape != lastShape:
            renderer.use(item.shape[])
            lastShape = item.shape
        if item.image != lastImage:
            renderer.use(item.image[])
            lastImage = item.image
        let itemPtr = item.addr
        itemPtr[].instances.bufferData()
        glDrawElementsInstanced(GL_TRIANGLES, item.shape[].nIndices * 3, GL_UNSIGNED_INT, nil, item.instances.len().GLsizei)
        itemPtr[].instances.clear()