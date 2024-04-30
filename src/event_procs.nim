#import std/strutils

import glad/gl
import glfw

var
    windowSizeChanged*: bool = false

{.push warning[HoleEnumConv]:off.}

proc keyCb(w: Window; key: Key; scanCode: int32; action: KeyAction; mods: set[ModifierKey]) =
    discard #echo "Key: $1 (scan code: $2): $3 - $4" % [$key, $scanCode, $action, $mods]

{.pop.}

proc frameBufferSizeCb(window: glfw.Window; size: tuple[w, h: int32]) =
    glViewport(0, 0, size[0], size[1])
    windowSizeChanged = true

proc registerWindowCallbacks*(window: var Window) =
    window.keyCb = keyCb
    window.framebufferSizeCb = frameBufferSizeCb