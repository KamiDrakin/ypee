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
  Shader* = distinct GLuint
  Program* = distinct GLuint
  AttribLocation* = distinct GLuint
  UniformLocation* = distinct GLuint
  VertexArray* = distinct GLuint
  Buffer* = object
    id*: GLuint
    target: GLenum
  Texture* =  object
    id*: GLuint
    target: GLenum

proc shader*(src: openArray[string]; shaderType: GLenum): Shader =
  result = glCreateShader(shaderType).Shader
  let shaderTextArr = src.map((x) => x.cstring)
  glShaderSource(result.GLuint, 1, cast[cstringArray](shaderTextArr[0].addr), nil)
  glCompileShader(result.GLuint)
  var
    success: bool
    infoLog = newString(1024)
  glGetShaderiv(result.GLuint, GL_COMPILE_STATUS, cast[ptr GLint](success.addr))
  if not success:
    glGetShaderInfoLog(result.GLuint, 1024, nil, infoLog.cstring)
    raise newException(Exception, "failed compiling shader " & $result.GLuint & "\n" & infoLog)

proc program*(shaders: openArray[Shader]): Program =
  result = glCreateProgram().Program
  for shader in shaders:
    glAttachShader(result.GLuint, shader.GLuint)
    glDeleteShader(shader.GLuint)
  glLinkProgram(result.GLuint)
  var
    success: bool
    infoLog = newString(1024)
  glGetProgramiv(result.GLuint, GL_LINK_STATUS, cast[ptr GLint](success.addr))
  if not success:
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

proc vertexArrays*(n: SomeInteger): seq[VertexArray] =
  result.setLen(n)
  glGenVertexArrays(n.GLsizei, cast[ptr GLuint](result[0].addr))

proc delete*(vertexArrays: openArray[VertexArray]) =
  glDeleteVertexArrays(vertexArrays.len.GLsizei, cast[ptr GLuint](vertexArrays[0].addr))

proc assign*[T](
  uniformLoc: UniformLocation;
  uniformType: static(UniformType);
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
  
proc use*(vertexArray: VertexArray) =
  glBindVertexArray(vertexArray.GLuint)

proc unbindVertexArray*() =
  glBindVertexArray(0)

template use*(vertexArray: VertexArray; p: untyped): untyped =
  vertexArray.use()
  p
  unbindVertexArray()

proc buffers*(n: SomeInteger): seq[Buffer] =
  result.setLen(n)
  glGenBuffers(n.GLsizei, cast[ptr GLuint](result[0].addr))

proc delete*(buffers: openArray[Buffer]) =
  glDeleteBuffers(buffers.len.GLsizei, cast[ptr GLuint](buffers[0].addr))

proc use*(buffer: var Buffer; target: GLenum) =
  buffer.target = target
  glBindBuffer(target, buffer.id)

proc unbindBuffer*(target: GLenum) =
  glBindBuffer(target, 0)

template use*(buffer: var Buffer; target: GLenum; p: untyped): untyped =
  buffer.use(target)
  p
  unbindBuffer(target)

template useWith*(buffer: var Buffer; target: GLenum; p: untyped): untyped =
  with buffer:
    use(target)
    p
  unbindBuffer(target)

proc bufferData*[T](target: GLenum; size: SomeInteger; data: openArray[T]; usage: GLenum) =
  glBufferData(target, size.GLsizeiptr, cast[pointer](data[0].addr), usage)

proc bufferData*(target: GLenum; size: SomeInteger; usage: GLenum) =
  glBufferData(target, size.GLsizeiptr, nil, usage)

proc bufferData*[T](buffer: Buffer; size: SomeInteger; data: openArray[T]; usage: GLenum) =
  bufferData(buffer.target, size, data, usage)

proc bufferData*(buffer: Buffer; size: SomeInteger; usage: GLenum) =
  bufferData(buffer.target, size, usage)

proc bufferSubData*[T](target: GLenum; offset, size: SomeInteger; data: openArray[T]) =
  glBufferSubData(target, offset.GLintptr, size.GLsizeiptr, cast[pointer](data[0].addr))

proc bufferSubData*[T](buffer: Buffer; offset, size: SomeInteger; data: openArray[T]) =
  bufferSubData(buffer.target, offset, size, data)

proc textures*(n: SomeInteger): seq[Texture] =
  result.setLen(n)
  glGenTextures(n.GLsizei, cast[ptr GLuint](result[0].addr))

proc delete*(textures: openArray[Texture]) =
  glDeleteTextures(textures.len.GLsizei, cast[ptr GLuint](textures[0].addr))

proc use*(texture: var Texture; target: GLenum) =
  texture.target = target
  glBindTexture(target, texture.id)

proc unbindTexture*(target: GLenum) =
  glBindTexture(target, 0)

template use*(texture: var Texture; target: GLenum; p: untyped): untyped =
  texture.use(target)
  p
  unbindTexture(target)

template useWith*(texture: var Texture; target: GLenum; p: untyped): untyped =
  with texture:
    use(target)
    p
  unbindTexture(target)

proc parameter*(target, pname: GLenum; param: SomeInteger) =
  glTexParameteri(target, pname, param.GLint)

proc parameter*(target, pname: GLenum; param: SomeFloat) =
  glTexParameterf(target, pname, param.GLfloat)

proc parameter*(texture: Texture; pname: GLenum; param: SomeInteger) =
  glTexParameteri(texture.target, pname, param.GLint)

proc parameter*(texture: Texture; pname: GLenum; param: SomeFloat) =
  glTexParameterf(texture.target, pname, param.GLfloat)

proc image2d*[T](
  target, internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  data: openArray[T];
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  glTexImage2D(
    target,
    level.GLint,
    internalFormat.GLint,
    width.GLsizei,
    height.GLsizei,
    0,
    format,
    valueType,
    cast[pointer](data[0].addr)
  )

proc image2d*(
  target, internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  glTexImage2D(
    target,
    level.GLint,
    internalFormat.GLint,
    width.GLsizei,
    height.GLsizei,
    0,
    format,
    valueType,
    nil
  )

proc image2d*[T](
  texture: Texture;
  internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  data: openArray[T];
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  image2d(texture.target, internalFormat, width, height, format, data, level, valueType)

proc image2d*(
  texture: Texture;
  internalFormat: GLenum;
  width, height: SomeInteger;
  format: GLenum;
  level: SomeInteger = 0;
  valueType: GLenum = GL_UNSIGNED_BYTE
) =
  image2d(texture.target, internalFormat, width, height, format, level, valueType)