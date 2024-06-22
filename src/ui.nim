import glm

import egutils
import ypeeeg
import graphics

type
  Element = ref object of RootObj
    pos, size, span: Vec2i
    children: seq[Element]
  Button* = ref object of Element
    rects: array[3, RectangleInst]
    center: Vec3f
    fillColor: Vec3f
    borderColor: Vec3f
    label: MonoText
    clickBox: Vec4f
    onClick: proc()
  Grid* = ref object of Element

method update*(element: Element; eg: YpeeEg) {.base.} =
  for child in element.children:
    child.update(eg)

method draw*(element: Element; posPx: Vec2f = vec2f(0.0); sizePx: Vec2f = vec2f(1.0); depth: float = 0.0) {.base.} =
  let scaledSizePx = sizePx / vec2f(element.size)
  for child in element.children:
    child.draw(posPx + vec2f(child.pos) * scaledSizePx, vec2f(child.span) * scaledSizePx, depth + 1.0)

proc add*(parent, child: Element) =
  parent.children.add(child)

proc newButton*(
  rectangle: Rectangle;
  fontSheet: SpriteSheet;
  fillColor, borderColor: Vec3f;
  pos, size, span: Vec2i
): Button =
  result = new Button
  result.fillColor = fillColor
  result.borderColor = borderColor
  for i in countup(0, result.rects.high):
    result.rects[i] = rectangle.newInstance()
  result.label = newMonoText(fontSheet)
  result.onClick = proc() = discard
  result.pos = pos
  result.size = size
  result.span = span

proc onIdle(button: Button) =
  button.rects[1].color = button.borderColor
  button.rects[2].color = button.fillColor

proc onHover(button: Button) =
  button.rects[1].color = button.borderColor
  button.rects[2].color = button.borderColor

proc onHeld(button: Button) =
  button.rects[1].color = button.fillColor
  button.rects[2].color = button.fillColor

method update*(button: Button; eg: YpeeEg) =
  procCall button.Element.update(eg)
  let
    mouseClick = eg.inpReleased(inMouseL)
    mouseHeld = eg.inpHeld(inMouseL)
  if button.clickBox.contains(vec2f(eg.mouse.screenPos)):
    if mouseClick: button.onClick()
    if mouseHeld: button.onHeld()
    else: button.onHover()
  else: button.onIdle()

method draw*(button: Button; posPx, sizePx: Vec2f; depth: float) =
  procCall button.Element.draw(posPx, sizePx, depth)
  button.center = vec3f(posPx + sizePx / 2.0, depth)
  for i in countup(0, button.rects.high):
    var rect = button.rects[i]
    rect.area = (vec4f(posPx + i.float, sizePx - i.float * 2.0), depth + i.float * 0.1)
    rect.color = [button.fillColor, button.borderColor, button.fillColor][i]
  button.label.pos = button.center + vec3f(-button.label.width / 2.0, 0.0, 0.3)
  button.clickBox = vec4f(posPx, sizePx)

proc `label=`*(button: Button; text: string) =
  button.label.content = text
  button.label.pos = button.center + vec3f(-button.label.width / 2.0, 0.0, 0.3)

proc onClick*(button: Button; action: proc()) =
  button.onClick = action

proc newGrid*(pos, size, span: Vec2i): Grid =
  result = new Grid
  result.pos = pos
  result.size = size
  result.span = span