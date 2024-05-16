func bmpDataFlip*(data: string; width: int): string =
    result = ""
    let width = width * 3
    for i in countdown(data.len() div width, 0):
        result.add(data.substr(i * width, (i + 1) * width - 1))