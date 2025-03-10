import nigui
import std/strutils
import listctrl
import airfoil



type
  FoilListCtrl* = ref object of ListCtrlBase
    items*: seq[AirFoil]

proc newFoilListCtrl*(): FoilListCtrl =
  result = new FoilListCtrl
  result.init()
  result.items = @[]

method len*(control: FoilListCtrl): int =
  len(control.items)

method handleDrawEvent*(control: FoilListCtrl, event: DrawEvent) =
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
  for i, foil in control.items:    
    if i == control.cursor:
      canvas.textColor = rgb(255, 255, 255)
      canvas.drawRectArea(0, y, control.width, dy)
    else:
      canvas.textColor = rgb(0, 0, 0)
    canvas.drawText(foil.path, 0, y)
    y += dy    
  canvas.drawRectOutline(0, 0, control.width, control.height)


type
  FoilBrowser* = ref object of RootObj
    window*: Window
    textArea*: TextArea
    textBox*: TextBox
    listCtrl*: FoilListCtrl
    
  
proc newFoilBrowser*(path: string): FoilBrowser =
  var window = newWindow(title="Available Airfoils")
  var container = newLayoutContainer(Layout_Vertical)
  window.add(container)
  window.width = 200.scaleToDpi

  var textBox = newTextBox("")
  container.add(textBox)
  textBox.placeholder = "Enter search"

  var foilListCtrl = newFoilListCtrl()
  var items = loadAirfoils(path)
  foilListCtrl.items = items
  foilListCtrl.widthMode = WidthMode_Expand
  foilListCtrl.heightMode = HeightMode_Expand
  foilListCtrl.minHeight = 100.scaleToDpi
  foilListCtrl.minWidth = 100.scaleToDpi
  container.add(foilListCtrl)

  var textArea = newTextArea()
  textArea.height = 100
  container.add(textArea)
  
  # configure searchbox
  textBox.onTextChange = proc(event: TextChangeEvent) =
    var newItems: seq[AirFoil]
    let text = textBox.text
    for item in items:
      if text in item.path:
        newItems.add(item)
    foilListCtrl.itemsRemoved(0, foilListCtrl.len)
    foilListCtrl.items = newItems
    foilListCtrl.itemsInserted(0, newItems.len)

  foilListCtrl.onItemActivate = proc(control: ListCtrlBase, index: int) =
    echo "item selected"
  foilListCtrl.onCursorMove = proc(control: ListCtrlBase, newIndex, oldIndex: int) =
    textArea.text = foilListCtrl.items[newIndex].doc

  window.alwaysOnTop = true

  var browser = FoilBrowser()
  browser.window = window
  browser.textArea = textArea
  browser.listCtrl = foilListCtrl
  browser.textBox = textBox
  return browser

    
when isMainModule:
  ## Little demo


  app.init()

  var browser = newFoilBrowser("foils/")
  browser.window.show()
  app.run()
