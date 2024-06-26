import std/tables
import std/sets
import std/algorithm
import std/sequtils
import std/streams

import glm
import opengl
import nimBMP

import egutils
import basicshapes
import glitter

export basicshapes

type
  GLProgram* = ref object
    id: Program
    vertAttributes: seq[(AttribLocation, GLsizei)]
    instAttributes: seq[(AttribLocation, GLsizei)]
    instSize: GLsizei
    uniforms: Table[string, (UniformLocation, GLsizei)]
  GLInstances* = ref object
    data: seq[GLfloat]
    offsets: Strider
    instSize: GLsizei
    buffer: Buffer
    maxLen: int
  GLImage* = ref object
    texture: Texture
    size*: Vec2i
  GLShape* = ref object
    nVertices: GLsizei
    vao: VertexArray
    vbo: Buffer
    program*: GLProgram
  GLDrawItem = object
    shape: GLShape
    image: GLImage
    instances: GLInstances
  GLFrame = ref object
    shape: GLShape
    fbo: Framebuffer
    rbo: Renderbuffer
    texture: Texture
    size: Vec2i
  GLRenderer* = ref object
    usedProgram: GLProgram
    toDraw: seq[GLDrawItem]
    uniformVals: Table[string, seq[GLfloat]]
    clearColor*: (GLfloat, GLfloat, GLfloat)
    frame*: GLFrame

proc newProgram*(vShaderSrc, fShaderSrc: string): GLProgram =
  result = new GLProgram
  result.id = program([
    shader([vShaderSrc], GL_VERTEX_SHADER),
    shader([fShaderSrc], GL_FRAGMENT_SHADER)
  ])

proc delete*(program: GLProgram) =
  try:
    program.id.delete()
  except:
    echo "Failed to delete program ", program.id.GLuint

proc setAttributes*(program: GLProgram; vertAttribs, instAttribs: seq[(string, int)]) =
  for (aName, aSize) in vertAttribs:
    let
      aSize = aSize.GLsizei
      aLoc = program.id.getAttribLocation(aName)
    program.vertAttributes.add((aLoc, aSize)) 

  program.instSize = 0
  for (aName, aSize) in instAttribs:
    let
      aSize = aSize.GLsizei
      aLoc = program.id.getAttribLocation(aName)
    program.instAttributes.add((aLoc, aSize))
    program.instSize += aSize

proc setUniforms*(program: GLProgram; uniforms: seq[(string, int)]) =
  for (uName, uSize) in uniforms:
    let
      uLoc = program.id.getUniformLocation(uName)
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
      aSizeSqrt = sqrt(aSize.float).int
      repeat = if aSizeSqrt > 2: (aSize div aSizeSqrt) - 1 else: 0 # works only for even matrices i guess
      aSize = if repeat > 0: aSizeSqrt else: aSize
    for i in countup(0, repeat):
      aLoc[i].enable()
      aLoc[i].vertexPointer(aSize, cGL_FLOAT, sizeof(GLFloat) * stride, sizeof(GLfloat) * totalSize)
      if divisor > 0:
        aLoc[i].vertexDivisor(divisor)
      totalSize += aSize

proc newInstances*(shape: GLShape; initLen: int = 1): GLInstances =
  result = new GLInstances
  result.data = newSeqOfCap[GLfloat](initLen)
  result.instSize = shape.program.instSize
  result.maxLen = initLen

  result.buffer = buffers(1)[0]
  
  shape.vao.use():
    result.buffer.use(btArray):
      result.buffer.bufferData(result.maxLen * sizeof(GLfloat), GL_DYNAMIC_DRAW)
      shape.program.enableAttributes(1)

proc delete*(insts: GLinstances) =
  try:
    [insts.buffer].delete()
  except:
    echo "Failed to delete instance buffer ", insts.buffer.id

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
  bufferData(btArray, insts.maxLen * sizeof(GLfloat), GL_DYNAMIC_DRAW)

proc bufferData(insts: GLInstances) =
  insts.buffer.use(btArray):
    if insts.data.len > insts.maxLen:
      insts.resize()
    insts.buffer.bufferSubData(0, insts.data.len * sizeof(GLfloat), insts.data)

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
  result.size = vec2i(bmp.width.int32, bmp.height.int32)
  result.texture = textures(1)[0]
  result.texture.useWith(tt2D):
    image2D(GL_RGB, result.size[0], result.size[1], GL_RGB, data)
    parameter(GL_TEXTURE_WRAP_S, GL_REPEAT)
    parameter(GL_TEXTURE_WRAP_T, GL_REPEAT)
    parameter(GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    parameter(GL_TEXTURE_MAG_FILTER, GL_NEAREST)

proc delete*(image: GLImage) =
  try:
    [image.texture].delete()
  except:
    echo "Failed to delete texture ", image.texture.id

proc newShape*(program: GLProgram; vertices: seq[GLVertex]): GLShape =
  result = new GLShape
  result.nVertices = vertices.len.GLsizei
  result.program = program
  
  result.vao = vertexArrays(1)[0]
  result.vbo = buffers(1)[0]
  result.vao.use():
    result.vbo.use(btArray):
      result.vbo.bufferData(vertices.len * sizeof(GLVertex), vertices, GL_STATIC_DRAW)
      program.enableAttributes(0)

proc delete*(shape: GLShape) =
  try:
    [shape.vbo].delete()
  except:
    echo "Failed to delete VBO ", shape.vbo.id
  try:
    [shape.vao].delete()
  except:
    echo "Failed to delete VAO ", shape.vao.GLuint

func drawItemCmp(x, y: GLDrawItem): int =
  let shapeCmp = cmp(x.shape, y.shape)
  if shapeCmp != 0:
    shapeCmp
  else:
    cmp(x.image, y.image)

proc resize*(frame: GLFrame; size: Vec2i) =
  if frame.fbo.id == 0: return
  frame.size = size

  frame.texture.useWith(tt2D):
    image2D(GL_RGB, size[0], size[1], GL_RGB)
    parameter(GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    parameter(GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    parameter(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE) # temporary "fix"
    parameter(GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

  frame.fbo.use(ftBuffer):
    frame.fbo.texture2D(GL_COLOR_ATTACHMENT0, tt2D, frame.texture)
    frame.rbo.use():
      renderbufferStorage(GL_DEPTH24_STENCIL8, size[0], size[1])
    frame.fbo.renderbuffer(GL_DEPTH_STENCIL_ATTACHMENT, frame.rbo)
    doAssert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE

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

  result.fbo = framebuffers(1)[0]
  result.texture = textures(1)[0]
  result.rbo = renderbuffers(1)[0]

  result.resize(size)

proc delete*(frame: GLFrame) =
  try:
    [frame.texture].delete()
  except:
    echo "Failed to delete framebuffer texture"
  try:
    [frame.fbo].delete()
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
  program.id.use()
    
proc use(renderer: GLRenderer; image: GLImage) =
  var texSize: Vec2f
  if image != nil:
    image.texture.use(tt2D)
    texSize = vec2f(image.size[0].GLfloat, image.size[1].GLfloat)
  else:
    texSize = vec2f(0.0)
  renderer.setUniform("texSize", texSize)

proc use(renderer: GLRenderer; shape: GLShape) =
  renderer.use(shape.program)
  shape.vao.use()

proc applyUniforms(renderer: GLRenderer) =
  let uniforms = renderer.usedProgram[].uniforms
  for k, (uLoc, uSize) in uniforms:
    let val = renderer.uniformVals[k]
    case uSize
      of 1: uLoc.assign(utVec1f, val)
      of 2: uLoc.assign(utVec2f, val)
      of 3: uLoc.assign(utVec3f, val)
      of 4: uLoc.assign(utVec4f, val)
      of 16: uLoc.assign(utMat4, val)
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
  renderer.frame.fbo.use(ftBuffer):
    renderer.layer(renderer.frame.size)

proc clear*(renderer: GLRenderer) =
  glClearColor(renderer.clearColor[0], renderer.clearColor[1], renderer.clearColor[2], 1.0)
  glClear(GL_COLOR_BUFFER_BIT)

proc clearFrame*(renderer: GLRenderer) =
  renderer.frame.fbo.use(ftBuffer):
    renderer.clear()

proc renderFrame*(renderer: GLRenderer; windowSize: Vec2i; letterbox: bool) =
  glViewport(0, 0, windowSize.x, windowSize.y)
  glClearColor(0.0, 0.0, 0.0, 1.0)
  glClear(GL_COLOR_BUFFER_BIT)
  glDisable(GL_DEPTH_TEST)
  renderer.use(renderer.frame.shape)
  renderer.frame.texture.use(tt2D):
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