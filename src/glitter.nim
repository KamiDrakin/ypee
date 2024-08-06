import std/sequtils
import std/sugar
import std/with

import opengl

type
  UniformType* = enum
    utVec2i, utVec1i, utVec3i, utVec4i,
    utVec1ui, utVec2ui, utVec3ui, utVec4ui,
    utVec1f, utVec2f, utVec3f, utVec4f,
    utMat2, utMat3, utMat4,
    utMat2x3, utMat3x2, utMat2x4, utMat4x2, utMat3x4, utMat4x3
  BufferTarget* = enum # reorder these once possible
    btArray = GL_ARRAY_BUFFER # 1
    btElementArray = GL_ELEMENT_ARRAY_BUFFER # 7
    btPixelPack = GL_PIXEL_PACK_BUFFER # 8
    btPixelUnpack = GL_PIXEL_UNPACK_BUFFER # 9
    btUniform = GL_UNIFORM_BUFFER # 14
    btTexture = GL_TEXTURE_BUFFER # 12
    btTransform = GL_TRANSFORM_FEEDBACK_BUFFER #13
    btCopyRead = GL_COPY_READ_BUFFER # 3
    btCopyWrite = GL_COPY_WRITE_BUFFER # 4
    btDrawIndirect = GL_DRAW_INDIRECT_BUFFER # 6
    btShaderStorage = GL_SHADER_STORAGE_BUFFER # 11
    btDispatchIndirect = GL_DISPATCH_INDIRECT_BUFFER # 5
    btQuery = GL_QUERY_BUFFER # 10
    btAtomicCounter = GL_ATOMIC_COUNTER_BUFFER # 2
  FramebufferTarget* = enum
    ftRead = GL_READ_FRAMEBUFFER # 2
    ftDraw = GL_DRAW_FRAMEBUFFER # 1
    ftBuffer = GL_FRAMEBUFFER # 3
  TextureTarget* = enum
    tt1D = GL_TEXTURE_1D # 1
    tt2D = GL_TEXTURE_2D # 2
    tt3D = GL_TEXTURE_3D # 3
    ttRectangle = GL_TEXTURE_RECTANGLE # 6
    ttCubeMap = GL_TEXTURE_CUBE_MAP # 7
    tt1DArray = GL_TEXTURE_1D_ARRAY # 4
    tt2DArray = GL_TEXTURE_2D_ARRAY # 5
    ttBuffer = GL_TEXTURE_BUFFER # 9
    ttCubeMapArray = GL_TEXTURE_CUBE_MAP_ARRAY # 8
    tt2DMultisample = GL_TEXTURE_2D_MULTISAMPLE # 10
    tt2DMultisampleArray = GL_TEXTURE_2D_MULTISAMPLE_ARRAY # 11
  Shader* = distinct GLuint
  Program* = distinct GLuint
  AttribLocation* = distinct GLuint
  UniformLocation* = distinct GLuint
  VertexArray* = distinct GLuint
  Buffer* = object
    id*: GLuint
    target: BufferTarget
  Framebuffer* = object
    id*: GLuint
    target: FramebufferTarget
  Renderbuffer* = distinct GLuint
  Texture* = object
    id*: GLuint
    target: TextureTarget

proc shader*(src: openArray[string]; shaderType: GLenum): Shader =
  result = glCreateShader(shaderType).Shader
  let shaderTextArr = src.map((x) => x.cstring)
  glShaderSource(result.GLuint, 1, cast[cstringArray](shaderTextArr[0].addr), nil)
  glCompileShader(result.GLuint)
  var
    success: GLint
    infoLog = newString(1024)
  glGetShaderiv(result.GLuint, GL_COMPILE_STATUS, success.addr)
  if not success.bool:
    glGetShaderInfoLog(result.GLuint, 1024, nil, infoLog.cstring)
    raise newException(Exception, "failed compiling shader " & $result.GLuint & "\n" & infoLog)

proc program*(shaders: openArray[Shader]): Program =
  result = glCreateProgram().Program
  for shader in shaders:
    glAttachShader(result.GLuint, shader.GLuint)
    glDeleteShader(shader.GLuint)
  glLinkProgram(result.GLuint)
  var
    success: GLint
    infoLog = newString(1024)
  glGetProgramiv(result.GLuint, GL_LINK_STATUS, success.addr)
  if not success.bool:
    glGetProgramInfoLog(result.GLuint, 1024, nil, infoLog.cstring)
    raise newException(Exception, "failed linking program " & $result.GLuint & "\n" & infoLog)

proc delete*(program: Program) =
  glDeleteProgram(program.GLuint)

proc use*(program: Program) =
  glUseProgram(program.GLuint)

proc unbindProgram*() =
  glUseProgram(0)

template use*(program: Program; p: untyped): untyped =
  program.use()
  p
  unbindProgram()

proc getAttribLocation*(program: Program; name: string): AttribLocation =
  let signedResult = glGetAttribLocation(program.GLuint, name.cstring)
  if signedResult < 0:
    raise newException(Exception, "could not find attribute \"" & name & "\"")
  signedResult.AttribLocation

proc getUniformLocation*(program: Program; name: string): UniformLocation =
  let signedResult = glGetUniformLocation(program.GLuint, name.cstring)
  if signedResult < 0:
    raise newException(Exception, "could not find uniform \"" & name & "\"")
  return signedResult.UniformLocation

proc `[]`*(attribLoc: AttribLocation; i: SomeInteger): AttribLocation =
  (attribLoc.GLuint + i.GLuint).AttribLocation

proc enable*(attribLoc: AttribLocation) =
  glEnableVertexAttribArray(attribLoc.GLuint)

proc vertexPointer*(
  attribLoc: AttribLocation;
  size: 1..4;
  valueType: GLenum;
  stride, offset: SomeInteger;
  transpose: bool = false
) =
  glVertexAttribPointer(
    attribLoc.GLuint,
    size.GLint,
    valueType,
    transpose,
    stride.GLsizei,
    cast[pointer](offset)
  )

proc vertexDivisor*(attribLoc: AttribLocation; divisor: SomeInteger) =
  glVertexAttribDivisor(attribLoc.GLuint, divisor.GLuint)

proc assign*[T](
  uniformLoc: UniformLocation;
  uniformType: static UniformType;
  v: openArray[T];
  count: SomeInteger = 1;
  transpose: bool = false
) =

  template uni(p, c: untyped): untyped {.used.} =
    p(uniformLoc.GLint, count.GLsizei, cast[ptr c](v[0].addr))
  
  template uniMat(p, c: untyped): untyped {.used.} =
    p(uniformLoc.GLint, count.GLsizei, transpose, cast[ptr c](v[0].addr))

  # pain
  when uniformType == utVec1f: uni(glUniform1fv, GLfloat)
  elif uniformType == utVec2f: uni(glUniform2fv, GLfloat)
  elif uniformType == utVec3f: uni(glUniform3fv, GLfloat)
  elif uniformType == utVec4f: uni(glUniform4fv, GLfloat)
  elif uniformType == utVec1i: uni(glUniform1iv, GLint)
  elif uniformType == utVec2i: uni(glUniform2iv, GLint)
  elif uniformType == utVec3i: uni(glUniform3iv, GLint)
  elif uniformType == utVec4i: uni(glUniform4iv, GLint)
  elif uniformType == utVec1ui: uni(glUniform1uiv, GLuint)
  elif uniformType == utVec2ui: uni(glUniform2uiv, GLuint)
  elif uniformType == utVec3ui: uni(glUniform3uiv, GLuint)
  elif uniformType == utVec4ui: uni(glUniform4uiv, GLuint)
  elif uniformType == utMat2: uniMat(glUniformMatrix2fv, GLfloat)
  elif uniformType == utMat3: uniMat(glUniformMatrix3fv, GLfloat)
  elif uniformType == utMat4: uniMat(glUniformMatrix4fv, GLfloat)
  elif uniformType == utMat2x3: uniMat(glUniformMatrix2x3fv, GLfloat)
  elif uniformType == utMat3x2: uniMat(glUniformMatrix3x2fv, GLfloat)
  elif uniformType == utMat2x4: uniMat(glUniformMatrix2x4fv, GLfloat)
  elif uniformType == utMat4x2: uniMat(glUniformMatrix4x3fv, GLfloat)
  elif uniformType == utMat3x4: uniMat(glUniformMatrix3x4fv, GLfloat)
  elif uniformType == utMat4x3: uniMat(glUniformMatrix4x3fv, GLfloat)

proc vertexArrays*(n: SomeInteger): seq[VertexArray] =
  result.setLen(n)
  glGenVertexArrays(n.GLsizei, cast[ptr GLuint](result[0].addr))

proc delete*(vertexArrays: openArray[VertexArray]) =
  glDeleteVertexArrays(vertexArrays.len.GLsizei, cast[ptr GLuint](vertexArrays[0].addr))
  
proc use*(vertexArray: VertexArray) =
  glBindVertexArray(vertexArray.GLuint)

proc unbindVertexArray*() =
  glBindVertexArray(0)

template use*(vertexArray: VertexArray; p: untyped): untyped =
  vertexArray.use()
  p
  unbindVertexArray()

proc buffers*(n: SomeInteger): seq[Buffer] =
  let ids = newSeq[GLuint](n)
  glGenBuffers(n.GLsizei, ids[0].addr)
  return ids.map((x) => Buffer(id: x))

proc delete*(buffers: openArray[Buffer]) =
  let ids = buffers.map((x) => x.id)
  glDeleteBuffers(buffers.len.GLsizei, ids[0].addr)

proc use*(buffer: var Buffer; target: BufferTarget) =
  buffer.target = target
  glBindBuffer(target.GLenum, buffer.id)

proc unbindBuffer*(target: BufferTarget) =
  glBindBuffer(target.GLenum, 0)

template use*(buffer: var Buffer; target: BufferTarget; p: untyped): untyped =
  buffer.use(target)
  p
  unbindBuffer(target)

template useWith*(buffer: var Buffer; target: BufferTarget; p: untyped): untyped =
  buffer.use(target, with(buffer, p))

proc bufferData*[T](target: BufferTarget; size: SomeInteger; data: openArray[T]; usage: GLenum) =
  glBufferData(target.GLenum, size.GLsizeiptr, cast[pointer](data[0].addr), usage)

proc bufferData*(target: BufferTarget; size: SomeInteger; usage: GLenum) =
  glBufferData(target.GLenum, size.GLsizeiptr, nil, usage)

proc bufferData*[T](buffer: Buffer; size: SomeInteger; data: openArray[T]; usage: GLenum) =
  bufferData(buffer.target, size, data, usage)

proc bufferData*(buffer: Buffer; size: SomeInteger; usage: GLenum) =
  bufferData(buffer.target, size, usage)

proc bufferSubData*[T](target: BufferTarget; offset, size: SomeInteger; data: openArray[T]) =
  glBufferSubData(target.GLenum, offset.GLintptr, size.GLsizeiptr, cast[pointer](data[0].addr))

proc bufferSubData*[T](buffer: Buffer; offset, size: SomeInteger; data: openArray[T]) =
  bufferSubData(buffer.target, offset, size, data)

proc framebuffers*(n: SomeInteger): seq[Framebuffer] =
  let ids = newSeq[GLuint](n)
  glGenFramebuffers(n.GLsizei, ids[0].addr)
  return ids.map((x) => Framebuffer(id: x))

proc delete*(fbuffers: openArray[Framebuffer]) =
  let ids = fbuffers.map((x) => x.id)
  glDeleteFramebuffers(fbuffers.len.GLsizei, ids[0].addr)

proc use*(fbuffer: var Framebuffer; target: FramebufferTarget) =
  fbuffer.target = target
  glBindFramebuffer(target.GLenum, fbuffer.id)

proc unbindFramebuffer*(target: FramebufferTarget) =
  glBindFramebuffer(target.GLenum, 0)

template use*(fbuffer: var Framebuffer; target: FramebufferTarget; p: untyped): untyped =
  fbuffer.use(target)
  p
  unbindFramebuffer(target)

template useWith*(fbuffer: var Framebuffer; target: FramebufferTarget; p: untyped): untyped =
  fbuffer.use(target, with(buffer, p))

proc texture2D*(
  target: FramebufferTarget;
  attachment: GLenum;
  texTarget: TextureTarget;
  texture: Texture;
  level: SomeInteger = 0
) =
  glFramebufferTexture2D(target.GLenum, attachment, texTarget.GLenum, texture.id, level.GLint)

proc texture2D*(
  fbuffer: Framebuffer;
  attachment: GLenum;
  texTarget: TextureTarget;
  texture: Texture;
  level: SomeInteger = 0
) =
  glFramebufferTexture2D(fbuffer.target.GLenum, attachment, texTarget.GLenum, texture.id, level.GLint)

proc renderbuffer*(target: FrameBufferTarget; attachment: GLenum; rbuffer: RenderBuffer) =
  glFramebufferRenderbuffer(target.GLenum, attachment, GL_RENDERBUFFER, rbuffer.GLuint)

proc renderbuffer*(fbuffer: FrameBuffer; attachment: GLenum; rbuffer: RenderBuffer) =
  renderbuffer(fbuffer.target, attachment, rbuffer)

proc renderbuffers*(n: SomeInteger): seq[Renderbuffer] =
  result.setLen(n)
  glGenRenderbuffers(n.GLsizei, cast[ptr GLuint](result[0].addr))

proc delete*(rbuffers: openArray[Renderbuffer]) =
  glDeleteRenderbuffers(rbuffers.len.GLsizei, cast[ptr GLuint](rbuffers[0].addr))
  
proc use*(rbuffer: Renderbuffer) =
  glBindRenderbuffer(GL_RENDERBUFFER, rbuffer.GLuint)

proc unbindRenderbuffer*() =
  glBindRenderbuffer(GL_RENDERBUFFER, 0)

template use*(rbuffer: Renderbuffer; p: untyped): untyped =
  rbuffer.use()
  p
  unbindRenderbuffer()

proc renderbufferStorage*(internalFormat: GLenum; width, height: SomeInteger) =
  glRenderbufferStorage(GL_RENDERBUFFER, internalFormat, width.GLsizei, height.GLsizei)

proc textures*(n: SomeInteger): seq[Texture] =
  let ids = newSeq[GLuint](n)
  glGenTextures(n.GLsizei, ids[0].addr)
  return ids.map((x) => Texture(id: x))

proc delete*(textures: openArray[Texture]) =
  let ids = textures.map((x) => x.id)
  glDeleteTextures(textures.len.GLsizei, ids[0].addr)

proc use*(texture: var Texture; target: TextureTarget) =
  texture.target = target
  glBindTexture(target.GLenum, texture.id)

proc unbindTexture*(target: TextureTarget) =
  glBindTexture(target.GLenum, 0)

template use*(texture: var Texture; target: TextureTarget; p: untyped): untyped =
  texture.use(target)
  p
  unbindTexture(target)

template useWith*(texture: var Texture; target: TextureTarget; p: untyped): untyped =
  texture.use(target, with(texture, p))

proc parameter*(target: TextureTarget; pname: GLenum; param: SomeInteger) =
  glTexParameteri(target.GLenum, pname, param.GLint)

proc parameter*(target: TextureTarget; pname: GLenum; param: SomeFloat) =
  glTexParameterf(target.GLenum, pname, param.GLfloat)

proc parameter*(texture: Texture; pname: GLenum; param: SomeInteger) =
  parameter(texture.target, pname, param)

proc parameter*(texture: Texture; pname: GLenum; param: SomeFloat) =
  parameter(texture.target, pname, param)

proc image2D*[T](
  target: TextureTarget;
  internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  data: openArray[T];
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  glTexImage2D(
    target.GLenum,
    level.GLint,
    internalFormat.GLint,
    width.GLsizei,
    height.GLsizei,
    0,
    format,
    valueType,
    cast[pointer](data[0].addr)
  )

proc image2D*(
  target: TextureTarget;
  internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  glTexImage2D(
    target.GLenum,
    level.GLint,
    internalFormat.GLint,
    width.GLsizei,
    height.GLsizei,
    0,
    format,
    valueType,
    nil
  )

proc image2D*[T](
  texture: Texture;
  internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  data: openArray[T];
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  image2D(texture.target, internalFormat, width, height, format, data, level, valueType)

proc image2D*(
  texture: Texture;
  internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  image2D(texture.target, internalFormat, width, height, format, level, valueType)