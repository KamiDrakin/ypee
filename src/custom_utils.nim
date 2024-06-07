import std/algorithm
import std/sequtils
import std/sugar

import glm

type
    StriderItem = object
        val: ref int
        offset: int
    Strider* = object
        data: seq[StriderItem]

proc `[]`*(strd: Strider; i: int): ref int =
    strd.data[i].val

proc len*(strd: Strider): int =
    strd.data.len

proc high*(strd: Strider): int =
    strd.data.high

proc add*(strd: var Strider; v: int): ref int =
    var item: StriderItem
    item.val = new int
    item.val[] =
        if strd.len > 0:
            strd.data[strd.high].val[] + strd.data[strd.high].offset
        else:
            0
    item.offset = v
    strd.data.add(item)
    strd[strd.high]

proc del*(strd: var Strider; i: int) =
    strd.data.del(i)
    if i == strd.data.len: return
    strd.data[i].val[] =
        if i > 0:
            strd.data[i - 1].val[] + strd.data[i - 1].offset
        else:
            0

proc clear*(strd: var Strider) =
    strd.data.setLen(0)

proc find*(strd: Strider; v: ref int): int =

    func valCmp(x: StriderItem; y: ref int): int =
        cmp(x.val[], y[])

    strd.data.binarySearch(v, valCmp)

func bmpDataFlip*(data: string; width: int): string =
    result = ""
    let width = width * 3
    for i in countdown(data.len div width, 0):
        result.add(data.substr(i * width, (i + 1) * width - 1))

func contains*[T](rect: Vec4[T]; pt: Vec2[T]): bool =
    pt.x >= rect.x and pt.x <= rect.x + rect.z and pt.y >= rect.y and pt.y <= rect.y + rect.w

func polygonContains*(polyPts: seq[Vec2f]; pt: Vec2f): bool =
    result = false
    var first = polyPts[polyPts.high]
    for i in countup(0, polyPts.high):
        let
            second = polyPts[i]
            intersect = ((second.y > pt.y) != (first.y > pt.y)) and
                (pt.x < (first.x - second.x) * (pt.y - second.y) / (first.y - second.y) + second.x)
        if intersect: result = not result
        first = second

# useless, perchance
func hexagonPoints*(pos: Vec2f = vec2f(0.0); scale: Vec2f = vec2f(1.0)): seq[Vec2f] =
    const
        angle = radians(60.0)
        rotMat = mat2f(vec2f(cos(angle), -sin(angle)), vec2f(sin(angle), cos(angle)))
    var norm = vec2f(0.0, -0.5)
    while result.len < 6:
        result.add((norm + vec2f(0.5)) * scale + pos)
        norm = rotMat * norm

func squareHexagonPoints*(pos: Vec2f = vec2f(0.0); scale: Vec2f = vec2f(1.0)): seq[Vec2f] =
    const hexa = @[
        vec2f( 0.0, -0.50),
        vec2f( 0.5, -0.25), vec2f( 0.5,  0.25),
        vec2f( 0.0,  0.50),
        vec2f(-0.5,  0.25), vec2f(-0.5, -0.25)
    ]
    hexa.map((x) => (x + 0.5) * scale + pos)