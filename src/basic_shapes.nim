import glad/gl

type
    GLVertex* = object
        x, y, z: GLfloat
        r, g, b: GLfloat
        u, v: GLfloat

proc vertex*(x, y, z, r, g, b, u, v: GLFloat): GLVertex =
    GLVertex(x: x, y: y, z: z, r: r, g: g, b: b, u: u, v: v)

const
    squareVertices* = @[
        vertex( 0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 1.0), #0
        vertex( 0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 0.0), #1
        vertex(-0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 1.0), #3
        
        vertex( 0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   1.0, 0.0), #1
        vertex(-0.5, -0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 0.0), #2
        vertex(-0.5,  0.5, 0.0,   1.0, 1.0, 1.0,   0.0, 1.0), #3
    ]

    prismVertices* = @[
        vertex(-0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   1/3, 1/3), #1
        vertex( 0.0,  0.5,  0.0,   1.0, 1.0, 1.0,   1/2, 0.0), #0  back
        vertex( 0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   2/3, 1/3), #2
        
        vertex( 0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   2/3, 1/3), #2
        vertex( 0.0,  0.5,  0.0,   1.0, 1.0, 1.0,   1.0, 1/2), #0  right
        vertex( 0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   2/3, 2/3), #3
        
        vertex( 0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   2/3, 2/3), #3
        vertex( 0.0,  0.5,  0.0,   1.0, 1.0, 1.0,   1/2, 1.0), #0  front
        vertex(-0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   1/3, 2/3), #4
        
        vertex(-0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   1/3, 2/3), #4
        vertex( 0.0,  0.5,  0.0,   1.0, 1.0, 1.0,   0.0, 1/2), #0  left
        vertex(-0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   1/3, 1/3), #1

        vertex(-0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   1/3, 2/3), #4
        vertex( 0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   2/3, 1/3), #2  bottom 1
        vertex( 0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   2/3, 2/3), #3
        
        vertex(-0.5, -0.5,  0.5,   1.0, 1.0, 1.0,   1/3, 2/3), #4
        vertex(-0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   1/3, 1/3), #1  bottom 2
        vertex( 0.5, -0.5, -0.5,   1.0, 1.0, 1.0,   2/3, 1/3), #2
    ]