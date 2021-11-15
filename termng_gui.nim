import termng_terminal, termng_types

# todo: function for resolving of unused objects
# todo: recursive GUI elements might be possible if we assure that area will become smaller each call and when no area left - drawing is finished

type
  GuiObj* {.inheritable.} = object
    ## Root object of all GUI elements

  Behaviour* = enum
    None
    Stretch

  ListContainer* = object of GuiObj
    size*: Vec
    bg*: BackgroundColor
    widthBehaviour*: Behaviour
    heightBehaviour*: Behaviour

  Label* = object of GuiObj
    text*: string
    fg*: ForegroundColor
    bg*: BackgroundColor

type
  GuiContext* = object
    ## Such contexts own all gui objects and manage their hierarchy
    object_pool: seq[Node] # plain array of all nodes in given context
    free_pool: seq[int] # indexes in object_pool that are free to reuse
    focus_sub: int # object that is subscribed for getting sole input

  Node = object
    obj: ref GuiObj
    subs: seq[int]  # which objects are subscribed to this
    bases: seq[int] # where this object is subscribed

func initGuiContext*: GuiContext =
  GuiContext()

func createGuiObj*(c: var GuiContext, t: typedesc[GuiObj]): int =
  ## Create globally managed GuiObject
  if c.free_pool.len != 0:
    let idx = c.free_pool.pop()
    c.object_pool[idx] = Node(obj: new(t))
    idx
  else:
    c.object_pool.add Node(obj: new(t))
    c.object_pool.high

func deref*(c: GuiContext, obj: int): ref GuiObj =
  assert obj notin c.free_pool
  ## Retrieve reference to managed gui object
  c.object_pool[obj].obj

func sub*(c: var GuiContext, base, obj: int) =
  assert obj notin c.free_pool
  c.object_pool[base].subs.add obj
  c.object_pool[obj].bases.add base

func unsub*(c: var GuiContext, base, obj: int) =
  assert obj notin c.free_pool
  let obj_idx = c.object_pool[base].subs.find(obj)
  if obj_idx == -1:
    raise newException(CatchableError, "obj isn't subscribed")
  c.object_pool[base].subs.del(obj_idx)

func del*(c: var GuiContext, obj: int) =
  assert obj notin c.free_pool
  for base in c.object_pool[obj].bases:
    c.unsub base, obj
  c.object_pool[obj].obj = nil
  c.free_pool.add obj

method drawTo(a: ref GuiObj, c: GuiContext, obj: int, t: var Terminal, start, area: Vec): Vec {.base.} =
  result = Vec.default
  ## Draws itself to terminal buffer
  ## By convention GuiObjects should draw its children here, but it's not necessary
  ## Return value is 'displacement' vector that specifies the margins of rendered object, relative to passed area

func drawHierarchy*(c: GuiContext, obj: int, t: var Terminal, start, area: Vec) =
  discard c.deref(obj).drawTo(c, obj, t, start, area)

method drawTo(a: ref ListContainer, c: GuiContext, obj: int, t: var Terminal, start, area: Vec): Vec =
  let style_restore = t.getStyle()
  t.setBackgroundColor(a.bg)
  t.fillRect(' ', a.size)
  let clamped_area = area.clamp a.size
  var displacement: Vec
  for sub in c.object_pool[obj].subs:
    displacement += (
      0u,
      drawTo(
        c.object_pool[sub].obj,
        c, sub, t,
        start + displacement,
        clamped_area - displacement,
      ).y
    )
  t.setStyle(style_restore)
  a.size

method drawTo(a: ref Label, c: GuiContext, obj: int, t: var Terminal, start, area: Vec): Vec =
  let style_restore = t.getStyle()
  let cursor_restore = t.getCursor()
  t.setCursor(start)
  t.setForegroundColor(a.fg)
  t.setBackgroundColor(a.bg)
  t.puts(a.text[0..<(min(a.text.len.uint, area.x - start.x))])
  t.setStyle(style_restore)
  t.setCursor(cursor_restore)
  (0u, 1u)

# todo: make those set methods automatically?

method set*(a: ref GuiObj, property: string, string_value: string) {.base.} =
  raise newException(CatchableError, "cannot set string properties in " & $a[])

method set*(a: ref Label, property: string, string_value: string) =
  case property:
  of "text":
    a.text = string_value
  else:
    raise newException(CatchableError, "no string property " & property & " in " & $a[])

method set*(a: ref GuiObj, property: string, vec_value: Vec) {.base.} =
  raise newException(CatchableError, "cannot set vector properties in " & $a[])

method set*(a: ref ListContainer, property: string, vec_value: Vec) =
  case property:
  of "size":
    a.size = vec_value
  else:
    raise newException(CatchableError, "no vector property " & property & " in " & $a[])

method set*(a: ref GuiObj, property: string, foreground_value: ForegroundColor) {.base.} =
  raise newException(CatchableError, "cannot set foreground color properties in " & $a[])

method set*(a: ref GuiObj, property: string, background_value: BackgroundColor) {.base.} =
  raise newException(CatchableError, "cannot set background color properties in " & $a[])

method set*(a: ref ListContainer, property: string, background_value: BackgroundColor) =
  case property:
  of "bg":
    a.bg = background_value
  else:
    raise newException(CatchableError, "no background color property " & property & " in " & $a[])
