import glm

import graphics

type
  Button* = ref object
    rects: array[3, RectangleInst]
    center: Vec3f
    label*: MonoText

proc newButton*(
  rectangle: Rectangle;
  pos: Vec3f;
  size: Vec2f;
  fillColor, borderColor: Vec3f
): Button =
  result = new Button
  for i in countup(0, result.rects.high):
    var rect = rectangle.newInstance()
    rect.area = (vec4f(pos.xy + i.float, size - i.float * 2.0), pos.z + i.float * 0.01)
    rect.color = [fillColor, borderColor, fillColor][i]
    result.rects[i] = rect
  result.center = pos + vec3f(size, 0.0) / 2.0

proc setLabel*(button: Button; sheet: SpriteSheet; text: string) =
  button.label = newMonoText(sheet)
  button.label.content = text
  button.label.pos = button.center + vec3f(-button.label.width / 2.0, 0.0, 0.03)