import termng

var term = initTerminal()
var guic = initGuiContext()
term.setTitle "thing without meaning"
var panel = guic.createGuiObj(ListContainer)
guic.deref(panel).set "size", (10u, term.size.y)
guic.deref(panel).set "bg", bgBlue
var txt = guic.createGuiObj(Label)
guic.deref(txt).set "text", "what the fuck"
var txtAnother = guic.createGuiObj(Label)
guic.deref(txtAnother).set "text", "dynamism my ass"
guic.sub panel, txt
guic.sub panel, txtAnother

while true:
  term.updateEvents()
  if term.testKeyEvent KeyEscape:
    break
  guic.drawHierarchy panel, term, (0u, 0u), term.size
  term.flush()
term.close()
