import std/algorithm

import glm

type
    AdditiveIntsItem = object
        val: ref int
        valid: bool
        offset: int
    AdditiveInts* = object
        data: seq[AdditiveIntsItem]

# recursion bad

#proc validate(ints: var AdditiveInts; i: int): ptr AdditiveIntsItem =
#    let item = ints.data[i].addr
#    if not item[].valid:
#        item[].val[] =
#            if i > 0:
#                let prevItem = ints.validate(i - 1)
#                prevItem[].val[] + prevItem[].offset
#            else:
#                0
#        item[].valid = true
#    item

# also i think this is slow in most use cases but i spent too long on it so i'm keeping it here

#[
proc validate(ints: var AdditiveInts; i: int): ptr AdditiveIntsItem =
    if not ints.data[i].valid:
        var firstInvalid = 0
        for j in countdown(i - 1, 0):
            if ints.data[j].valid:
                firstInvalid = j + 1
        for j in countup(firstInvalid, i):
            let item = ints.data[j].addr
            item[].val[] =
                if j > 0:
                    let prevItem = ints.data[j - 1].addr
                    prevItem[].val[] + prevItem[].offset
                else:
                    0
    ints.data[i].addr

proc `[]`*(ints: var AdditiveInts; i: int): ref int =
    ints.validate(i).val

proc len*(ints: AdditiveInts): int =
    ints.data.len()

proc add*(ints: var AdditiveInts; v: int): ref int =
    var item: AdditiveIntsItem
    item.val = new int
    item.valid = false
    item.offset = v
    ints.data.add(item)
    ints[ints.len() - 1]

proc delete*(ints: var AdditiveInts; i: int) =
    discard ints.validate(i)
    ints.data.delete(i)
    for i in countup(i, ints.len() - 1):
        if not ints.data[i].valid: break
        ints.data[i].valid = false

proc find*(ints: var AdditiveInts; v: ref int): int =

    func valCmp(x: AdditiveIntsItem; y: ref int): int =
        cmp(x.val[], y[])

    ints.data.binarySearch(v, valCmp)
]#

proc `[]`*(ints: var AdditiveInts; i: int): ref int =
    ints.data[i].val

proc len*(ints: AdditiveInts): int =
    ints.data.len()

proc add*(ints: var AdditiveInts; v: int): ref int =
    var item: AdditiveIntsItem
    item.val = new int
    item.val[] =
        if ints.len() > 0:
            ints.data[ints.len() - 1].val[] + ints.data[ints.len() - 1].offset
        else:
            0
    item.offset = v
    ints.data.add(item)
    ints[ints.len() - 1]

proc delete*(ints: var AdditiveInts; i: int) =
    for j in countup(i + 1, ints.data.len() - 1):
        ints.data[j].val[] -= ints.data[i].offset
    ints.data.delete(i)

proc find*(ints: var AdditiveInts; v: ref int): int =

    func valCmp(x: AdditiveIntsItem; y: ref int): int =
        cmp(x.val[], y[])

    ints.data.binarySearch(v, valCmp)

func contains*[T](rect: Vec4[T]; pt: Vec2[T]): bool =
    pt.x >= rect.x and pt.x <= rect.z and pt.y >= rect.y and pt.y <= rect.w

func bmpDataFlip*(data: string; width: int): string =
    result = ""
    let width = width * 3
    for i in countdown(data.len() div width, 0):
        result.add(data.substr(i * width, (i + 1) * width - 1))