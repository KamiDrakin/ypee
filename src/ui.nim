import glm

import egutils
import ypeeeg
import graphics

type
  Element = ref object of RootObj
    pos, size: Vec2i
    clickBox: Vec4f
    children: seq[Element]
  Button* = ref object of Element
    rects: array[3, RectangleInst]
    center: Vec3f
    fillColor: Vec3f
    borderColor: Vec3f
    label: MonoText
    clickAction: proc()
  Grid* = ref object of Element

method draw(element: Element; posPx, sizePx: Vec2f; depth: float) {.base.} =
  element.clickBox = vec4f(posPx, sizePx)
  let scaledSizePx = sizePx / vec2f(element.size)
  for child in element.children:
    child.draw(posPx + vec2f(child.pos) * scaledSizePx, vec2f(child.size) * scaledSizePx, depth)

method onIdle(element: Element) {.base.} = discard
method onHover(element: Element) {.base.} = discard
method onClick(element: Element) {.base.} = discard
method onHeld(element: Element) {.base.} = discard

proc add*(parent, child: Element) =
  parent.children.add(child)

proc newButton*(
  rectangle: Rectangle;
  fontSheet: SpriteSheet;
  fillColor, borderColor: Vec3f;
  pos, size: Vec2i
): Button =
  result = new Button
  result.fillColor = fillColor
  result.borderColor = borderColor
  for i in countup(0, result.rects.high):
    result.rects[i] = rectangle.newInstance()
  result.label = newMonoText(fontSheet)
  result.pos = pos
  result.size = size

method draw(button: Button; posPx, sizePx: Vec2f; depth: float) =
  procCall button.Element.draw(posPx, sizePx, depth)
  button.center = vec3f(posPx + sizePx / 2.0, depth)
  for i in countup(0, button.rects.high):
    var rect = button.rects[i]
    rect.area = (vec4f(posPx + i.float, sizePx - i.float * 2.0), depth + i.float * 0.1)
    rect.color = [button.fillColor, button.borderColor, button.fillColor][i]
  button.label.pos = button.center + vec3f(-button.label.width / 2.0, 0.0, 0.3)

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
  button.label.pos = button.center + vec3f(-button.label.width / 2.0, 0.0, 0.3)

proc onClick*(button: Button; action: proc()) =
  button.clickAction = action

proc newGrid*(size: Vec2i): Grid =
  result = new Grid
  result.size = size

method draw*(grid: Grid; posPx: Vec2f = vec2f(0.0); sizePx: Vec2f = vec2f(1.0); depth: float = 0.0) =
  procCall grid.Element.draw(posPx, sizePx, depth)

proc update*(grid: Grid; eg: YpeeEg) =
  let
    mouseClick = eg.inpReleased(inMouseL)
    mouseHeld = eg.inpHeld(inMouseL)
  for i, child in grid.children:
    if child.clickBox.contains(vec2f(eg.mouse.screenPos)):
      if mouseClick: child.onClick()
      if mouseHeld: child.onHeld()
      else: child.onHover()
    else: child.onIdle()