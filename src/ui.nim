import glm

import graphics

type
  Button* = ref object
    rects: array[2, RectangleInst]
    corners: array[8, Sprite]
    label*: MonoText

proc newButton*(
  rectangle: Rectangle;
  cornersSheet: SpriteSheet;
  pos: Vec3f;
  size: Vec2f;
  fgColor, bgColor: Vec3f;
  text: string = ""
): Button =
  const
    spriteOffsets = [ # cw from bottom left
      [vec2i(2, 3), vec2i(2, 2), vec2i(3, 2), vec2i(3, 3)],
      [vec2i(0, 3), vec2i(0, 2), vec2i(1, 2), vec2i(1, 3)]
    ]
    posOffsets = [vec2f(-1.0, -1.0), vec2f(-1.0, 1.0), vec2f(1.0, 1.0), vec2f(1.0, -1.0)]
    sizeOffsets = [vec2f(0.0, 0.0), vec2f(0.0, 1.0), vec2f(1.0, 1.0), vec2f(1.0, 0.0)]
  result = new Button
  for i in countup(0, 1):
    var rect = rectangle.newInstance()
    rect.area = (vec4f(pos.xy + i.float, size - i.float * 2.0), pos.z + i.float * 0.01)
    rect.color = [fgColor, bgColor][i]
    result.rects[i] = rect
  for i in countup(0, 3):
    for j in countup(0, 1):
      var sprite = newSprite(cornersSheet)
      sprite.offset = spriteOffsets[j][i]
      sprite.pos = pos + vec3f(posOffsets[i] + sizeOffsets[i] * (size - vec2f(cornersSheet.size)), 0.02 + j.float * 0.01)
      sprite.tint = vec4f([bgColor, fgColor][j], 1.0)
      result.corners[j * 4 + i] = sprite