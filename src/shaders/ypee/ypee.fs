#version 330 core

in vec4 color;
in vec2 texCoords;
in vec4 fBlendColor;

out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 texSize;

void main() {
    if (texSize.x > 0.0) {
        fragColor = texture(tex, texCoords);
        if (fragColor.xyz == vec3(1.0, 0.0, 1.0)) discard;
        fragColor = fragColor * color;
    }
    else {
        fragColor = color;
    }
    fragColor = vec4(fragColor.rgb * (1.0 - fBlendColor.a) + fBlendColor.rgb * fBlendColor.a, fragColor.a);
} 