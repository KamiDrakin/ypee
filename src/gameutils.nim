import std/sequtils
import std/sugar

import glm

type
    Timer = ref object
        tick*: bool
        tickCount*: int
        time: float
        timeToTick: float
    
proc newTimer*(timeToTick: float): Timer =
    result = new Timer
    result.timeToTick = timeToTick

proc update*(timer: Timer; time: float) =
    timer.time += time
    timer.tick = false
    if timer.time >= timer.timeToTick:
        timer.time -= timer.timeToTick
        timer.tick = true
        timer.tickCount += 1

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