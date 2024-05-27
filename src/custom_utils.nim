import std/algorithm

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

func contains*[T](rect: Vec4[T]; pt: Vec2[T]): bool =
    pt.x >= rect.x and pt.x <= rect.x + rect.z and pt.y >= rect.y and pt.y <= rect.y + rect.w

func bmpDataFlip*(data: string; width: int): string =
    result = ""
    let width = width * 3
    for i in countdown(data.len div width, 0):
        result.add(data.substr(i * width, (i + 1) * width - 1))