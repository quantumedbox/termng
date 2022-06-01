# Some parts are based on illwill: https://github.com/johnnovak/illwill

# limitations:
#   - broken utf-8
#   - automatic resizing only supported on conhost based terminals, it should not be the case
#   - currently it fucks up original terminal buffer

# todo: macro for setting style from set-like argument interface
# todo: xterm support: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Extended-coordinates
# todo: redirect stderr

import std/[times, sequtils, terminal, atomics]
export terminal.BackgroundColor
export terminal.ForegroundColor

import termng_os, termng_keycodes, termng_types
export termng_keycodes

type
  TermCode* {.pure.} = enum
    clear
    reset
    # echoOn
    echoOff
    boldOn
    boldOff
    wrapOn
    wrapOff
    underlineOn
    underlineOff
    negativeOn
    negativeOff
    cursorShow
    cursorHide
    repeatOn
    repeatOff
    interlaceOn
    interlaceOff

const TermCodes = [
    TermCode.clear: "\e[2J",
    TermCode.reset: "\e[0m",
    # TermCode.echoOn: ...
    TermCode.echoOff: "\e[12h",
    TermCode.boldOn: "\e[1m",
    TermCode.boldOff: "\e[22m",
    TermCode.wrapOn: "\e[7h",
    TermCode.wrapOff: "\e[7l",
    TermCode.underlineOn: "\e[4m",
    TermCode.underlineOff: "\e[24m",
    TermCode.negativeOn: "\e[7m",
    TermCode.negativeOff: "\e[27m",
    TermCode.cursorShow: "\e[?25h",
    TermCode.cursorHide: "\e[?25l",
    TermCode.repeatOn: "\e[[?8h",
    TermCode.repeatOff: "\e[[?8l",
    TermCode.interlaceOn: "\e[[?9h",
    TermCode.interlaceOff: "\e[[?9l",
]

func `$`*(a: TermCode): lent string = TermCodes[a]

type
  Terminal* = object
    instream: File            # input handle from which commands are read
    instreamMode: termng_os.FileMode
    outstream: File           # output handle to which terminal sequences are flushed
    outstreamMode: termng_os.FileMode
    readerChannel: ptr Channel[set[Keycode]]
    readerShouldClose: ptr Atomic[bool]
    readerThread: Thread[ReaderPackage]

    size: Vec                 # current size of terminal 
    queue: seq[string]        # global terminal sequence commands
    board: seq[Cell]          # matrix of characters and their styles, cleared every flush
    keyEvents: set[Keycode]   # set of platform-independent keycode events, filled on pollEvents call

    isCursorVisible: bool
    isWrapping: bool

    # writer states
    cursor: Vec               # current state of writer, will be used in draw functions, zeroed each flush
    style: Style              # current style of writer, will be used in draw function, defaulted each flush

    debugLines: seq[string]   # todo: make it debug build only?

  Style* = object
    bold, underline, negative: bool
    foreground: ForegroundColor
    background: BackgroundColor

  Cell* = tuple[ch: char, style: Style]

  ReaderPackage = tuple[
    channel: ptr Channel[set[Keycode]],
    shouldClose: ptr Atomic[bool],
    file: File
  ]

const
  defaultTerminalSize: Vec = (x: 80u, y: 24u)
  defaultStyle =
    Style(
      bold: false,
      underline: false,
      negative: false,
      foreground: fgDefault,
      background: bgDefault
    )

func `=copy`*(a: var Terminal, b: Terminal) {.error.} = discard

func initStyle*(foreground: ForegroundColor = fgDefault,
                background: BackgroundColor = bgDefault,
                bold, underline, negative: bool = false): Style =
  Style(
    foreground: foreground,
    background: background,
    bold: bold,
    underline: underline,
    negative: negative
  )

func parseSequence(s: string): set[Keycode] =
  # todo: wtf
  func parseEscape(s: string, current: var int): Keycode =
    for variants in escapeSequences:
      for variant in variants[1]:
        if (current + variant.len < s.len) and
            (variant == s[(current + 1)..(current + variant.len)]):
          current += variant.len
          return variants[0]

  var current = 0
  while current != s.len:
    let key = case s[current]:
      of '\9':   KeyTab
      of '\10':  KeyEnter
      of '\32':  KeySpace
      of '\127': KeyBackspace
      of '\27':  # possible escape sequence
        if current == s.high: KeyEscape
        else:
          if s[current + 1].Keycode == KeyEscape:
            KeyEscape
          else:
            parseEscape(s, current)
      else:
        s[current].Keycode
    if key != KeyNone:
      result.incl key
    current.inc

proc inputThread(arg: ReaderPackage) {.thread.} =
  while not arg.shouldClose[].load:
    let bytes = arg.file.readInput()
    let sequence = parseSequence(bytes)
    if sequence.card != 0:
      arg.channel[].send(sequence)

proc initInput(t: var Terminal) =
  t.readerChannel = createShared(Channel[set[Keycode]])
  t.readerShouldClose = createShared(Atomic[bool])
  t.readerChannel[].open(maxItems = 1)
  t.readerThread.createThread(inputThread, (t.readerChannel, t.readerShouldClose, stdin))

func showCursor*(t: var Terminal) =
  t.queue.add $TermCode.cursorShow
  t.isCursorVisible = true

func hideCursor*(t: var Terminal) =
  t.queue.add $TermCode.cursorHide
  t.isCursorVisible = false

func wrapTurnOn*(t: var Terminal) =
  t.queue.add $TermCode.wrapOn
  t.isWrapping = true

func wrapTurnOff*(t: var Terminal) =
  t.queue.add $TermCode.wrapOff
  t.isWrapping = false

func repeatTurnOn*(t: var Terminal) =
  t.queue.add $TermCode.repeatOn

func repeatTurnOff*(t: var Terminal) =
  t.queue.add $TermCode.repeatOff

# func echoTurnOn*(t: var Terminal) =
#   t.queue.add $TermCode.repeatOn

func echoTurnOff*(t: var Terminal) =
  t.queue.add $TermCode.echoOff

func interlaceTurnOn*(t: var Terminal) =
  t.queue.add $TermCode.interlaceOn

func interlaceTurnOff*(t: var Terminal) =
  t.queue.add $TermCode.interlaceOff

func setStyle*(t: var Terminal, style: Style) =
  t.style = style

func getStyle*(t: var Terminal): Style = t.style

func setForegroundColor*(t: var Terminal, c: ForegroundColor) =
  if c.int != 0: # convention: 0 value means "inherit"
    var style = t.getStyle
    style.foreground = c
    t.setStyle style

func setBackgroundColor*(t: var Terminal, c: BackgroundColor) =
  if c.int != 0: # convention: 0 value means "inherit"
    var style = t.getStyle
    style.background = c
    t.setStyle style

func setCursor*(t: var Terminal, pos: Vec) =
  # t.frame.add "\e[" & $(pos.y + 1) & ';' & $(pos.x + 1) & 'H'
  t.cursor = pos

func getCursor*(t: var Terminal): Vec = t.cursor

func getSize*(t: Terminal): Vec = t.size

template withStyle*(t: var Terminal, style: Style, body: untyped) = 
  let to_restore = t.getStyle()
  t.setStyle style
  body
  t.setStyle to_restore

func puts*(t: var Terminal, txt: string) =
  # todo: make it variadic with automatic conversion to string?
  if t.cursor.x < t.size.x and t.cursor.y < t.size.y:
    let lin_pos = t.cursor.x + t.cursor.y * t.size.x
    for i in 0u..<min(txt.len.uint, t.size.x - t.cursor.x):
      t.board[lin_pos + i] = (ch: txt[i], style: t.style)

# todo: use t.cursor as start?
func fillRect*(t: var Terminal, ch: char, size: Vec) =
  if t.cursor.x < size.x and t.cursor.y < size.y:
    for y in t.cursor.y..<min(t.cursor.y + size.y, t.size.y):
      for x in t.cursor.x..<min(t.cursor.x + size.x, t.size.x):
        t.board[x + y * t.size.x] = (ch: ch, style: t.style)

func fillWith*(t: var Terminal, ch: char) =
  fillRect(t, ch, t.size)

func clear*(t: var Terminal) =
  t.withStyle defaultStyle:
    t.setCursor (0u, 0u)
    t.fillWith '\32' # fill with whitespace

func setTitle*(t: var Terminal, title: string) =
  if title.len >= 255:
    raise newException(CatchableError, "title is too long to fit in ANSI escape sequence")
  t.queue.add "\e]0;" & title & '\7'

proc setBufferSize*(t: var Terminal, size: Vec) =
  # setFileBufferSize(t.outstream, t.outstreamMode, size)
  t.board = repeat(Cell.default, size.area)

func boardToSequence*(t: Terminal): string =
  # todo: can append to already existing string
  # todo: could preallocate string storage
  # todo: could use wrapping behavior to simplify this, but we should ensure this behaviour between terminals
  var current_style = defaultStyle
  for y in 0u..<t.size.y:
    result.add "\e[" & $(y + 1u) & ';' & $1u & 'H' # todo: use /n instead?
    for x in 0u..<t.size.x:
      let cell = t.board[x + y * t.size.x]
      if cell.style != current_style:
        if cell.style.bold != current_style.bold:
          result.add if cell.style.bold: $TermCode.boldOn else: $TermCode.boldOff
        if cell.style.underline != current_style.underline:
          result.add if cell.style.underline: $TermCode.underlineOn else: $TermCode.underlineOff
        if cell.style.negative != current_style.negative:
          result.add if cell.style.negative: $TermCode.negativeOn else: $TermCode.negativeOff
        if cell.style.foreground != current_style.foreground:
          result.add "\e[" & $cell.style.foreground.uint & 'm'
        if cell.style.background != current_style.background:
          result.add "\e[" & $cell.style.background.uint & 'm'
        current_style = cell.style
      result.add cell.ch

func pushDebugLine*(t: var Terminal, line: sink string) =
  t.debugLines.add line

proc flushDebugLines(t: var Terminal) = 
  ## Print terminal-related debugging info
  let
    cursor_restore = t.getCursor()
    style_restore = t.getStyle()
  t.setStyle initStyle(background=bgWhite, foreground=fgBlack)
  t.setCursor (0u, 0u)
  for line in t.debugLines:
    t.puts line
    t.setCursor t.getCursor() + (0u, 1u)
  t.setCursor cursor_restore
  t.setStyle style_restore
  t.debugLines.reset

proc flush*(t: var Terminal) =
  t.flushDebugLines()
  var sequence: string
  for com in t.queue: # todo: queue could be replaced for string
    sequence.add com
  sequence.add t.boardToSequence
  t.cursor = (0u, 0u)
  sequence.add "\e[" & $1u & ';' & $1u & 'H' # move to (0, 0)
  t.outstream.write sequence
  t.setStyle defaultStyle
  t.outstream.flushFile()
  t.clear() # todo: probably users should initiate it by themselves

proc initTerminal*(instream = stdin, outstream: File = stdout): Terminal =
  result.instreamMode = initInputFile(instream)
  result.instream = instream
  result.outstreamMode = initOutputFile(outstream)
  result.outstream = outstream

  result.initInput()

  result.size = defaultTerminalSize

  result.hideCursor()
  result.repeatTurnOff()
  result.wrapTurnOff()
  result.interlaceTurnOn()
  result.echoTurnOff()
  result.setBufferSize(result.size)
  result.outstream = outstream

proc close*(t: var Terminal) =
  # todo: use =destoy?
  # todo: should be called on abnormal program exiting too
  t.readerShouldClose[].store true
  t.readerThread.joinThread()
  t.readerChannel.deallocShared()
  t.readerShouldClose.deallocShared()

  if t.outstream == stdout:
    stdout.write $TermCode.boldOff & $TermCode.underlineOff & $TermCode.negativeOff
    stdout.write "\e[" & $fgDefault.byte & 'm' & "\e[" & $bgDefault.byte & 'm'
    stdout.write $TermCode.clear & $TermCode.reset & $TermCode.cursorShow
    stdout.flushFile()

proc updateEvents*(t: var Terminal): bool {.discardable.} =
  ## Try to update event set
  ## Returns true if event update occurred, otherwise false
  let events = t.readerChannel[].tryRecv()
  if events.dataAvailable:
    t.keyEvents = events.msg
  else:
    t.keyEvents.reset
  return events.dataAvailable

func testKeyEvent*(t: Terminal, s: set[Keycode]): bool =
  s == t.keyEvents

func testKeyEvent*(t: Terminal, s: Keycode): bool =
  s in t.keyEvents

func hasEvents*(t: Terminal): bool =
  t.keyEvents.len != 0

func getEvents*(t: Terminal): set[Keycode] =
  t.keyEvents

proc putDebugState*(t: var Terminal) = 
  ## Print terminal-related debugging info
  t.pushDebugLine "board size: " & $t.size
  # t.pushDebugLine "- mode: " & $t.outputMode
  t.pushDebugLine "- keyEvents: " & $t.keyEvents

template timedBody*(once_in: float, body: untyped) =
  var tillUpdate {.global.} = once_in
  var lastClock {.global.} = cpuTime()
  let time = cpuTime()
  tillUpdate -= time - lastClock
  lastClock = time
  if tillUpdate <= 0.0:
    tillUpdate = once_in
    body
