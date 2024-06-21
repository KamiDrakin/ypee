import glm

import graphics
import ypeeeg

type
  Element = ref object of RootObj
  Button* = ref object of Element
    rects: array[3, RectangleInst]
    center: Vec3f
    fillColor: Vec3f
    borderColor: Vec3f
    label: MonoText
    clickAction: proc()
  Grid* = ref object
    eg: YpeeEg
    depth: float
    width: int
    elementPixelSize: Vec2f
    elements: seq[Element]

method onIdle(element: Element) {.base.} = discard
method onHover(element: Element) {.base.} = discard
method onClick(element: Element) {.base.} = discard
method onHeld(element: Element) {.base.} = discard

proc newButton*(
  rectangle: Rectangle;
  fontSheet: SpriteSheet;
  pos: Vec3f;
  size: Vec2f;
  fillColor, borderColor: Vec3f
): Button =
  result = new Button
  result.center = pos + vec3f(size, 0.0) / 2.0
  result.fillColor = fillColor
  result.borderColor = borderColor
  result.label = newMonoText(fontSheet)
  for i in countup(0, result.rects.high):
    var rect = rectangle.newInstance()
    rect.area = (vec4f(pos.xy + i.float, size - i.float * 2.0), pos.z + i.float * 0.01)
    rect.color = [fillColor, borderColor, fillColor][i]
    result.rects[i] = rect

method onIdle(button: Button) =
  button.rects[1].color = button.borderColor
  button.rects[2].color = button.fillColor

method onHover(button: Button) =
  button.rects[1].color = button.borderColor
  button.rects[2].color = button.borderColor

method onClick(button: Button) =
  button.clickAction()

method onHeld(button: Button) =
  button.rects[1].color = button.fillColor
  button.rects[2].color = button.fillColor

proc `label=`*(button: Button; text: string) =
  button.label.content = text
  button.label.pos = button.center + vec3f(-button.label.width / 2.0, 0.0, 0.03)

proc onClick*(button: Button; action: proc()) =
  button.clickAction = action

proc newGrid*(eg: YpeeEg; depth: SomeFloat; size: Vec2i): Grid =
  result = new Grid
  result.eg = eg
  result.depth = depth
  result.width = size.x
  result.elementPixelSize = vec2f(eg.screenSize) / vec2f(size)
  result.elements.setLen(size.x * size.y)

proc addButton*(
  grid: Grid;
  rectangle: Rectangle;
  fontSheet: SpriteSheet;
  pos, size: Vec2i;
  fillColor, borderColor: Vec3f
): Button =
  let
    pixelPos = vec3f(grid.elementPixelSize * vec2f(pos), grid.depth)
    pixelSize = grid.elementPixelSize * vec2f(size)
  result = newButton(rectangle, fontSheet, pixelPos, pixelSize, fillColor, borderColor)
  for y in countup(0, size.y - 1):
    for x in countup(0, size.x - 1):
      grid.elements[(pos.y + y) * grid.width + (pos.x + x)] = result

proc update*(grid: Grid) =
  let
    mousePos = grid.eg.mouse.screenPos div vec2i(grid.elementPixelSize.ceil)
    mouseClick = grid.eg.inpReleased(inMouseL)
    mouseHeld = grid.eg.inpHeld(inMouseL)
    indexAtMouse = mousePos.y * grid.width + mousePos.x
  var processedElements = newSeqOfCap[Element](grid.elements.len)
  for i, element in grid.elements:
    if element == nil: continue
    if element in processedElements: continue
    if i == indexAtMouse:
      if mouseClick: element.onClick()
      if mouseHeld: element.onHeld()
      else: element.onHover()
      processedElements.add(element)
    else: element.onIdle()