import termng_types

type
  FileMode* {.pure.} = enum
    Unknown
    Console

when defined(windows):
  import std/winlean

  type
    SHORT = int16
    WORD = uint16
    WCHAR = WinChar
    CHAR = char
    UINT = cint

    COORD* {.bycopy.} = object
      X*: SHORT
      Y*: SHORT

  proc system(cmd: cstring): cint {.importc: "system", header: "<stdlib.h>".}

  proc GetLastError: DWORD
    {.stdcall, dynlib: "kernel32", importc: "GetLastError".}

  proc SetConsoleMode(hConsoleHandle: HANDLE, dwMode: DWORD): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "SetConsoleMode".}

  proc GetStdHandle(nStdHandle: DWORD): HANDLE
    {.stdcall, dynlib: "kernel32", importc: "GetStdHandle".}

  proc SetConsoleCursorPosition(hConsoleOutput: HANDLE, dwCursorPosition: COORD): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "SetConsoleCursorPosition".}

  proc SetConsoleScreenBufferSize(hConsoleOutput: HANDLE, dwSize: COORD): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "SetConsoleScreenBufferSize".}

  proc WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD): DWORD
    {.stdcall, dynlib: "kernel32", importc: "WaitForSingleObject".}

  proc ReadFile(hFile: HANDLE, lpBuffer: pointer, toRead: DWORD, bytesRead: ptr DWORD, lpOverlapped: ptr OVERLAPPED): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "ReadFile".}

  proc GetFileType(hFile: HANDLE): DWORD
    {.stdcall, dynlib: "kernel32", importc: "GetFileType".}

  const
    ENABLE_PROCESSED_INPUT        = 0x0001
    ENABLE_LINE_INPUT             = 0x0002
    ENABLE_ECHO_INPUT             = 0x0004
    ENABLE_WINDOW_INPUT           = 0x0008
    ENABLE_MOUSE_INPUT            = 0x0010
    ENABLE_INSERT_MODE            = 0x0020
    ENABLE_EXTENDED_FLAGS         = 0x0040
    ENABLE_QUICK_EDIT_MODE        = 0x0040
    ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200

    ENABLE_PROCESSED_OUTPUT             = 0x01
    ENABLE_VIRTUAL_TERMINAL_PROCESSING  = 0x04
    DISABLE_NEWLINE_AUTO_RETURN         = 0x08  

  const
    WAIT_TIMEOUT      = 0x00000102.DWORD
    WAIT_OBJECT_0     = 0x00000000.DWORD

  const
    FILE_TYPE_CHAR    = 0x0002
    FILE_TYPE_PIPE    = 0x0003
    FILE_TYPE_UNKNOWN = 0x0000

  proc readInput*(file: File): string =
    const BufferN = 128 # Maximum N of bytes that could be read at once
    case WaitForSingleObject(GetStdHandle(STD_INPUT_HANDLE), 0.DWORD)
    of WAIT_TIMEOUT: discard
    of WAIT_OBJECT_0:
      var event_buffer: array[BufferN, char]
      var n_events_read: DWORD
      let status = ReadFile(GetStdHandle(STD_INPUT_HANDLE), event_buffer[0].unsafeAddr, BufferN.DWORD, n_events_read.unsafeAddr, nil)
      if status == 0.WINBOOL and status != ERROR_IO_PENDING:
        stderr.write GetLastError()
        quit(1)
      result = newString(n_events_read)
      for i in 0..<n_events_read:
        result[i] = event_buffer[i]
    else:
      stderr.write "unexpected signal from WaitForSingleObject\n"
      quit(1) # todo: eh

  proc initInputFile*(file: File): FileMode =
    let os_handle = getOsFileHandle(file)
    case GetFileType(os_handle):
    of FILE_TYPE_CHAR:
      let err = SetConsoleMode(
        os_handle,
        ENABLE_WINDOW_INPUT or
        ENABLE_MOUSE_INPUT or
        ENABLE_VIRTUAL_TERMINAL_INPUT or
        ENABLE_EXTENDED_FLAGS
      )
      FileMode.Console
    else:
      FileMode.Unknown

  proc deinitInputFile(file: File, mode: FileMode) =
    case mode:
    of FileMode.Console:
      let os_handle = getOsFileHandle(file)
      let err = SetConsoleMode(
        os_handle,
        ENABLE_PROCESSED_INPUT or
        ENABLE_ECHO_INPUT or
        ENABLE_MOUSE_INPUT or
        ENABLE_INSERT_MODE or
        ENABLE_LINE_INPUT or
        ENABLE_QUICK_EDIT_MODE or
        ENABLE_EXTENDED_FLAGS)
      if err == 0:
        stderr.write "error restoring windows terminal input mode\n"
    else:
      discard

  proc initOutputFile*(file: File): FileMode =
    let os_handle = getOsFileHandle(file)
    case GetFileType(os_handle):
    of FILE_TYPE_CHAR:
      let err = SetConsoleMode(
        os_handle,
        ENABLE_PROCESSED_OUTPUT or
        ENABLE_VIRTUAL_TERMINAL_PROCESSING or
        DISABLE_NEWLINE_AUTO_RETURN
      )
      FileMode.Console
    else:
      FileMode.Unknown

  proc setFileBufferSize*(file: File, mode: FileMode, size: Vec) =
    case mode:
    of FileMode.Console:
      let os_handle = getOsFileHandle(file)
      # have to do this to prevent crush https://github.com/microsoft/terminal/issues/2366
      discard SetConsoleCursorPosition(os_handle, COORD(X: 0.SHORT, Y: 0.SHORT))
      let err = SetConsoleScreenBufferSize(os_handle, COORD(X: size.x.SHORT, Y: size.y.SHORT))
      if err == 0:
        raise newException(CatchableError, "error while setting terminal buffer size")
    else:
      discard

else:
  {.error: "os not supported".}
