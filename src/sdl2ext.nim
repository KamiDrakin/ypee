import sdl2

{.push warning[user]: off}

when defined(SDL_Static):
  discard
else:
  when defined(windows):
    const LibName* = "SDL2.dll"
  elif defined(macosx):
    const LibName* = "libSDL2.dylib"
  elif defined(openbsd):
    const LibName* = "libSDL2.so.0.6"
  elif defined(haiku):
    const LibName* = "libSDL2-2.0.so.0"
  else:
    const LibName* = "libSDL2(|-2.0).so(|.0)"

{.pop.}

when not defined(SDL_Static):
  {.push callConv: cdecl, dynlib: LibName.}

proc setMinimumSize*(window: WindowPtr; minW, minH: cint) {.importc: "SDL_SetWindowMinimumSize".}

when not defined(SDL_Static):
  {.pop.}