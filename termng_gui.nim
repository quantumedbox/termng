import termng_terminal, termng_types

# todo: function for resolving unused objects
# todo: objects could be made non ref counted as they're stored exclusively within context

type
  GuiObj* {.inheritable.} = object
    ## Root object of all GUI elements

  GuiContext* = object
    ## Such contexts own all gui objects and manage their hierarchy
    object_pool: seq[Node] # plain array of all nodes in given context
    free_pool: seq[int] # indexes in object_pool that are free to reuse
    focus_hierarchy: seq[int] # sequence of nested nodes

  Node = object
    obj: ref GuiObj
    subs: seq[int]  # which objects are subscribed to this
    bases: seq[int] # where this object is subscribed

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


# todo: self unbinding on destruction of current context?
var current_context: ref GuiContext = nil

func initGuiContext*: ref GuiContext =
  result = new GuiContext
  # result.current_focus = -1

proc makeCurrent*(c: ref GuiContext) =
  current_context = c

proc unbind*(c: ref GuiContext) =
  current_context = nil

func createGuiObjB*(c: ref GuiContext, t: typedesc[GuiObj]): int =
  ## Create globally managed GuiObject
  if c.free_pool.len != 0:
    let idx = c.free_pool.pop()
    c.object_pool[idx] = Node(obj: new(t))
    idx
  else:
    c.object_pool.add Node(obj: new(t))
    c.object_pool.high

proc createGuiObj*(t: typedesc[GuiObj]): int =
  assert current_context != nil
  current_context.createGuiObjB(t)

func deref(c: ref GuiContext, obj: int): ref GuiObj =
  assert obj notin c.free_pool and obj < c.object_pool.len
  ## Retrieve reference to managed gui object
  c.object_pool[obj].obj

func subB*(c: ref GuiContext, base, obj: int) =
  assert obj notin c.free_pool and obj < c.object_pool.len
  assert base notin c.free_pool and base < c.object_pool.len
  assert obj notin c.object_pool[base].subs
  c.object_pool[base].subs.add obj
  c.object_pool[obj].bases.add base

proc sub*(base: int, objs: varargs[int]) =
  assert current_context != nil
  for obj in objs:
    current_context.subB(base, obj)

func unsubB*(c: ref GuiContext, base, obj: int) =
  assert obj notin c.free_pool and obj < c.object_pool.len
  assert base notin c.free_pool and base < c.object_pool.len
  let obj_idx = c.object_pool[base].subs.find(obj)
  if obj_idx == -1:
    raise newException(CatchableError, "obj isn't subscribed")
  let base_idx = c.object_pool[obj].bases.find(base)
  assert base_idx != -1
  c.object_pool[base].subs.del obj_idx
  c.object_pool[obj].bases.del base_idx

proc unsub*(base, obj: int) =
  assert current_context != nil
  current_context.unsubB(base, obj)

func delB*(c: ref GuiContext, obj: int) =
  assert obj notin c.free_pool and obj < c.object_pool.len
  for base in c.object_pool[obj].bases:
    c.unsubB base, obj
  c.object_pool[obj].obj = nil
  c.free_pool.add obj
  # if c.current_focus == obj:
  #   c.current_focus = -1

proc del*(obj: int) =
  assert current_context != nil
  current_context.delB(obj)

# func focusB*(c: ref GuiContext, obj: int) =
#   assert obj notin c.free_pool and obj < c.object_pool.len
#   c.current_focus = obj

# proc focus*(obj: int) =
#   assert current_context != nil
#   current_context.focusB(obj)

method drawTo(a: ref GuiObj, c: ref GuiContext, t: var Terminal, obj: int, start, area: Vec): Vec {.base.} =
  result = Vec.default
  ## Draws itself to terminal buffer
  ## By convention GuiObjects should draw its children here, but it's not necessary
  ## Return value is 'displacement' vector that specifies the margins of rendered object, relative to passed area

func drawToB*(c: ref GuiContext, t: var Terminal, obj: int, start, area: Vec) =
  let style_restore = t.getStyle()
  let cursor_restore = t.getCursor()
  discard c.deref(obj).drawTo(c, t, obj, start, area)
  t.setStyle(style_restore)
  t.setCursor(cursor_restore)

proc drawTo*(t: var Terminal, obj: int, start = Vec.default, area: Vec = t.getSize()) =
  assert current_context != nil
  current_context.drawToB(t, obj, start, area)

method drawTo(a: ref ListContainer, c: ref GuiContext, t: var Terminal, obj: int, start, area: Vec): Vec =
  if area.x == 0 or area.y == 0:
    return
  t.setBackgroundColor(a.bg)
  t.fillRect(' ', a.size)
  let clamped_area = area.clamp a.size
  var displacement: Vec
  for sub in c.object_pool[obj].subs:
    # assert sub != obj
    displacement += (
      0u,
      drawTo(
        c.object_pool[sub].obj,
        c, t, sub,
        start + displacement,
        clamped_area - displacement,
      ).y
    )
  a.size

method drawTo(a: ref Label, c: ref GuiContext, t: var Terminal, obj: int, start, area: Vec): Vec =
  t.setCursor(start)
  t.setForegroundColor(a.fg)
  t.setBackgroundColor(a.bg)
  t.puts(a.text[0..<min(a.text.len.uint, area.x - start.x)])
  (0u, 1u)


template newProperty(name: untyped, value_t: typedesc): untyped =
  method `set name`*(a: ref GuiObj, value: value_t) {.inject, base.} =
    raise newException(CatchableError, "cannot set property for " & $a[])

  func `set name B`*(c: ref GuiContext, obj: int, value: value_t) {.inject.} =
    assert obj notin c.free_pool and obj < c.object_pool.len
    c.object_pool[obj].obj.`set name`(value)

  proc `set name`*(obj: int, value: value_t) {.inject.} =
    assert current_context != nil
    current_context.`set name B`(obj, value)

newProperty(Text, string)
newProperty(Size, Vec)
newProperty(ForegroundColor, ForegroundColor)
newProperty(BackgroundColor, BackgroundColor)

method setText(a: ref Label, value: string) =
  a.text = value

method setForegroundColor(a: ref Label, value: ForegroundColor) =
  a.fg = value

method setBackgroundColor(a: ref Label, value: BackgroundColor) =
  a.bg = value

method setBackgroundColor(a: ref ListContainer, value: BackgroundColor) =
  a.bg = value

method setSize(a: ref ListContainer, value: Vec) =
  a.size = value


# method receiveInput*(a: ref GuiObj, c: ref GuiContext, obj: int, events: set[Keycode]): bool {.base.} =
#   return false
#   ## 'true' return signals that events are 'consumed' and shouldn't be processed anymore 

# func passInputB*(с: ref GuiContext, obj: int, events: set[Keycode]) =
#   ## TODO

# proc passInput*(obj: int, events: set[Keycode]) =
#   assert current_context != nil
#   current_context.passInputB(obj, events)
