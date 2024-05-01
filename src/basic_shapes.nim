import glad/gl

type
    GLVertex* = object
        x, y, z: GLfloat
        r, g, b: GLfloat
        u, v: GLfloat
    GLIndex* = object
        v1, v2, v3: GLuint

proc vertex*(x, y, z, r, g, b, u, v: GLFloat): GLVertex =
    GLVertex(x: x, y: y, z: z, r: r, g: g, b: b, u: u, v: v)

proc index*(v1, v2, v3: GLuint): GLIndex =
    GLIndex(v1: v1, v2: v2, v3: v3)

const
    squareVertices*: seq[GLVertex] = @[
        vertex( 0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 1.0),
        vertex( 0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 0.0),
        vertex(-0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 0.0),
        vertex(-0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 1.0),
    ]
    squareIndices*: seq[GLIndex] = @[
        index(0, 1, 3),
        index(1, 2, 3),
    ]