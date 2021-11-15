# todo: fill remaining
# todo: keycode to string repr

type
  Keycode* = uint16

const
  KeyNone* = 0.Keycode

  KeyBackspace* = 8.Keycode
  KeyTab* = 9.Keycode

  KeyClear* = 12.Keycode
  KeyEnter* = 13.Keycode

  KeyShift* = 16.Keycode
  KeyCtrl* = 17.Keycode
  KeyAlt* = 18.Keycode
  KeyPause* = 19.Keycode
  KeyCapsLock* = 20.Keycode

  KeyEscape* = 27.Keycode

  KeySpace* = 32.Keycode

  KeyPlus* = 43.Keycode

  KeyMinus* = 45.Keycode

  Key1* = 48.Keycode
  Key2* = 49.Keycode
  Key3* = 50.Keycode
  Key4* = 51.Keycode
  Key5* = 52.Keycode
  Key6* = 53.Keycode
  Key7* = 54.Keycode
  Key8* = 55.Keycode
  Key9* = 56.Keycode

  KeyEqual* = 61.Keycode

  KeyShiftA* = 65.Keycode
  KeyShiftB* = 66.Keycode
  KeyShiftC* = 67.Keycode
  KeyShiftD* = 68.Keycode
  KeyShiftE* = 69.Keycode
  KeyShiftF* = 70.Keycode
  KeyShiftG* = 71.Keycode
  KeyShiftH* = 72.Keycode
  KeyShiftI* = 73.Keycode
  KeyShiftJ* = 74.Keycode
  KeyShiftK* = 75.Keycode
  KeyShiftL* = 76.Keycode
  KeyShiftM* = 77.Keycode
  KeyShiftN* = 78.Keycode
  KeyShiftO* = 79.Keycode
  KeyShiftP* = 80.Keycode
  KeyShiftQ* = 81.Keycode
  KeyShiftR* = 82.Keycode
  KeyShiftS* = 83.Keycode
  KeyShiftT* = 84.Keycode
  KeyShiftU* = 85.Keycode
  KeyShiftV* = 86.Keycode
  KeyShiftW* = 87.Keycode
  KeyShiftX* = 88.Keycode
  KeyShiftY* = 89.Keycode
  KeyShiftZ* = 90.Keycode

  KeyUnderscore* = 95.Keycode

  KeyA* = 97.Keycode
  KeyB* = 98.Keycode
  KeyC* = 99.Keycode
  KeyD* = 100.Keycode
  KeyE* = 101.Keycode
  KeyF* = 102.Keycode
  KeyG* = 103.Keycode
  KeyH* = 104.Keycode
  KeyI* = 105.Keycode
  KeyJ* = 106.Keycode
  KeyK* = 107.Keycode
  KeyL* = 108.Keycode
  KeyM* = 109.Keycode
  KeyN* = 110.Keycode
  KeyO* = 111.Keycode
  KeyP* = 112.Keycode
  KeyQ* = 113.Keycode
  KeyR* = 114.Keycode
  KeyS* = 115.Keycode
  KeyT* = 116.Keycode
  KeyU* = 117.Keycode
  KeyV* = 118.Keycode
  KeyW* = 119.Keycode
  KeyX* = 120.Keycode
  KeyY* = 121.Keycode
  KeyZ* = 122.Keycode

  # Virtual keycodes
  KeyUp*       = 1001.Keycode
  KeyDown*     = 1002.Keycode
  KeyRight*    = 1003.Keycode
  KeyLeft*     = 1004.Keycode
  KeyHome*     = 1005.Keycode
  KeyInsert*   = 1006.Keycode
  KeyDelete*   = 1007.Keycode
  KeyEnd*      = 1008.Keycode
  KeyPageUp*   = 1009.Keycode
  KeyPageDown* = 1010.Keycode

  KeyF1*  = 1011.Keycode
  KeyF2*  = 1012.Keycode
  KeyF3*  = 1013.Keycode
  KeyF4*  = 1014.Keycode
  KeyF5*  = 1015.Keycode
  KeyF6*  = 1016.Keycode
  KeyF7*  = 1017.Keycode
  KeyF8*  = 1018.Keycode
  KeyF9*  = 1019.Keycode
  KeyF10* = 1020.Keycode
  KeyF11* = 1021.Keycode
  KeyF12* = 1022.Keycode

const
  escapeSequences* = {
    KeyUp:        @["OA", "[A"],
    KeyDown:      @["OB", "[B"],
    KeyRight:     @["OC", "[C"],
    KeyLeft:      @["OD", "[D"],
    KeyHome:      @["[1~", "[7~", "OH", "[H"],
    KeyInsert:    @["[2~"],
    KeyDelete:    @["[3~"],
    KeyEnd:       @["[4~", "[8~", "OF", "[F"],
    KeyPageUp:    @["[5~"],
    KeyPageDown:  @["[6~"],
    KeyF1:        @["[11~", "OP"],
    KeyF2:        @["[12~", "OQ"],
    KeyF3:        @["[13~", "OR"],
    KeyF4:        @["[14~", "OS"],
    KeyF5:        @["[15~"],
    KeyF6:        @["[17~"],
    KeyF7:        @["[18~"],
    KeyF8:        @["[19~"],
    KeyF9:        @["[20~"],
    KeyF10:       @["[21~"],
    KeyF11:       @["[23~"],
    KeyF12:       @["[24~"],
  }
