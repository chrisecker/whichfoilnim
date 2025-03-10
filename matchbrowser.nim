import nigui
import listctrl
import airfoil
import std/algorithm
import std/math


type
  MatchListCtrl* = ref object of ListCtrlBase
    items*: seq[(AirFoil, float)]

proc newMatchListCtrl*(): MatchListCtrl =
  result = new MatchListCtrl
  result.init()
  result.items = @[]

method len*(control: MatchListCtrl): int =
  len(control.items)

method handleDrawEvent*(control: MatchListCtrl, event: DrawEvent) =
  let canvas = event.control.canvas
  let dy = canvas.getTextLineHeight()
  control.dy = dy
  let h = dy*len(control)
  if control.scrollableHeight != h:
    control.scrollableHeight= h
  
  canvas.areaColor = rgb(255, 255, 255)  
  canvas.textColor = rgb(255, 255, 255)
  canvas.lineColor = rgb(255, 255, 255)
  canvas.drawRectArea(0, 0, control.width, control.height)
  canvas.areaColor = rgb(0, 0, 255)

  var y = -control.yScrollPos
  for i, (foil, badness) in control.items:    
    if i == control.cursor:
      canvas.textColor = rgb(255, 255, 255)
      canvas.drawRectArea(0, y, control.width, dy)
    else:
      canvas.textColor = rgb(0, 0, 0)
    canvas.drawText($round(badness*100, 3), 0, y)
    canvas.drawText(foil.path, 50.scaleToDpi, y)
    y += dy    
  canvas.drawRectOutline(0, 0, control.width, control.height)


type
  MatchBrowser* = ref object of RootObj
    window*: Window
    textArea*: TextArea
    textBox*: TextBox
    listCtrl*: MatchListCtrl
    
  
proc newMatchBrowser*(items: seq[(AirFoil, float)]): MatchBrowser =
  var window = newWindow(title="Matches")
  var container = newLayoutContainer(Layout_Vertical)
  window.add(container)
  window.width = 200.scaleToDpi

  var listCtrl = newMatchListCtrl()
  listCtrl.widthMode = WidthMode_Expand
  listCtrl.heightMode = HeightMode_Expand
  listCtrl.minHeight = 100.scaleToDpi
  listCtrl.minWidth = 100.scaleToDpi
  listCtrl.items = items
  container.add(listCtrl)

  var textArea = newTextArea()
  textArea.height = 100
  container.add(textArea)
  

  listCtrl.onItemActivate = proc(control: ListCtrlBase, index: int) =
    echo "item selected"
  listCtrl.onCursorMove = proc(control: ListCtrlBase, newIndex, oldIndex: int) =
    textArea.text = listCtrl.items[newIndex][0].doc

  window.alwaysOnTop = true

  var browser = MatchBrowser()
  browser.window = window
  browser.textArea = textArea
  browser.listCtrl = listCtrl
  return browser

    
when isMainModule:
  ## Little demo


  app.init()

  let f1 = load_airfoil("foils/clarky-il.dat")
  let f2 = load_airfoil("foils/ag03-il.dat")
  let f3 = load_airfoil("foils/fx61168-il.dat")
  var matches = @[(f1, 1.0), (f2, 2.0), (f3, 3.0)]
  proc myCmp(x, y: (AirFoil, float)): int =
    cmp(x[1], y[1])      
  matches.sort(myCmp)
  
  var browser = newMatchBrowser(matches)

  browser.window.show()
  app.run()
