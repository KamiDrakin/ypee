import glm

func contains*[T](rect: Vec4[T]; pt: Vec2[T]): bool =
    pt.x >= rect.x and pt.x <= rect.z and pt.y >= rect.y and pt.y <= rect.w

func bmpDataFlip*(data: string; width: int): string =
    result = ""
    let width = width * 3
    for i in countdown(data.len() div width, 0):
        result.add(data.substr(i * width, (i + 1) * width - 1))