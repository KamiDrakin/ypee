import std/sequtils
import std/sugar

import opengl

type
  Shader* = distinct GLuint
  Program* = distinct GLuint
  AttribLocation* = distinct GLuint
  VertexArray* = distinct GLuint
  Buffer* = distinct GLuint

proc shaderFromSrc*(src: openArray[string]; shaderType: GLenum): Shader =
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

proc use*(program: Program) =
  glUseProgram(program.GLuint)

proc getAttribLocation*(program: Program; name: string): AttribLocation =
  let signedResult = glGetAttribLocation(program.GLuint, name.cstring)
  if signedResult < 0:
    raise newException(Exception, "could not find attribute \"" & name & "\"")
  signedResult.AttribLocation

proc enable*(attribLoc: AttribLocation) =
  glEnableVertexAttribArray(attribLoc.GLuint)

## glVertexAttribPointer wrap
## size isn't in bytes you doofus
proc vertexPointer*(
  attribLoc: AttribLocation;
  size: SomeInteger;
  valueType: GLenum;
  stride: SomeInteger;
  offset: SomeInteger
) =
  glVertexAttribPointer(
    attribLoc.GLuint,
    size.GLint,
    valueType,
    false,
    stride.GLsizei,
    cast[pointer](offset)
  )

proc vertexArrays*(n: SomeInteger): seq[VertexArray] =
  result.setLen(n)
  glGenVertexArrays(n.GLsizei, cast[ptr GLuint](result[0].addr))
  
proc use*(vertexArray: VertexArray) =
  glBindVertexArray(vertexArray.GLuint)

proc buffers*(n: SomeInteger): seq[Buffer] =
  result.setLen(n)
  glGenBuffers(n.GLsizei, cast[ptr GLuint](result[0].addr))

proc use*(buffer: Buffer; target: GLenum) =
  glBindBuffer(target, buffer.GLuint)

proc bufferData*[T](target: GLenum; size: SomeInteger; dataPtr: T; usage: GLenum) =
  glBufferData(target, size.GLsizeiptr, cast[pointer](dataPtr), usage)

proc bufferSubData*[T](target: GLenum; offset, size: SomeInteger; dataPtr: T) =
  glBufferSubData(target, offset.GLintptr, size.GLsizeiptr, cast[pointer](dataPtr))