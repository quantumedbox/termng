import termng

var term = initTerminal()
term.setTitle "thing without meaning"

var guic = initGuiContext()
guic.makeCurrent()

let panel = createGuiObj ListContainer
panel.setSize (10u, term.getSize().y)
panel.setBackgroundColor bgBlue
let text = createGuiObj Label
text.setText "what the fuck"
let another_txt = createGuiObj Label
another_txt.setText "uh"
panel.sub text, another_txt

# panel.focus()

while true:
  term.updateEvents()
  if term.testKeyEvent KeyEscape:
    break
  drawTo term, panel, (0u, 0u), term.getSize()
  # passInput term.getEvents()
  term.flush()
term.close()
