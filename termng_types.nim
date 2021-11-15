type
  Vec* = tuple[x, y: uint]
    ## Terminal vector type, coords are always unsigned

func area*(a: Vec): uint =
  a.x * a.y

func `+`*(a: Vec, b: Vec): Vec =
  (a.x + b.x, a.y + b.y)

func `-`*(a: Vec, b: Vec): Vec =
  ## Saturated subtraction, values can't get less than 0
  let
    x = if a.x < b.x: 0u else: a.x - b.x
    y = if a.y < b.y: 0u else: a.y - b.y
  (x, y)

func `+=`*(a: var Vec, v: Natural) =
  a.x += v.uint
  a.y += v.uint

func `+=`*(a: var Vec, b: Vec) =
  a.x += b.x
  a.y += b.y

func clamp*(a: Vec, b: Vec): Vec =
  result.x = min(a.x, b.x)
  result.y = min(a.y, b.y)
