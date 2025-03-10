# A simple platform independent list control

import nigui
import std/times
import std/strutils



type
  ListCtrlBase* = ref object of ControlImpl
    fCursor: int
    onItemActivate*: ActivateProc
    onCursorMove*: CursorProc
    dy*: int # height per item
    lastRelease: float # time of last mouse button release
    buttonDown: bool # is left mouse button down or not?

  ActivateProc* = proc(control: ListCtrlBase, index: int)
  CursorProc* = proc(control: ListCtrlBase, newindex, oldindex: int)


method len(control: ListCtrlBase): int {.base.} = # needs to be overridden
  0

method adjustViewport(control: ListCtrlBase) =
  let y1 = control.yScrollPos
  let y2 = control.height+y1-control.dy
  let y = control.fCursor*control.dy
  if y < y1:
    control.yScrollPos = y
    control.forceRedraw
  elif y > y2:
    control.yScrollPos = y1+y-y2
    control.forceRedraw
    
method cursor*(control: ListCtrlBase): int =
  control.fCursor
  
method `cursor=`*(control: ListCtrlBase, cursor: int) =
    let old = control.fCursor
    control.fCursor = cursor
    let callback = control.onCursorMove
    if callback != nil:
      callback(control, control.cursor, old)
    
    control.adjustViewport # in redraw??
    control.forceRedraw
       

method handleMouseMoveEvent(control: ListCtrlBase, event: MouseEvent) =
  if not control.buttonDown:
    return
  let dy = control.dy
  var y = event.y+control.yScrollPos
  for i in 1..control.len:    
    y -= dy
    if y <= 0:
      control.cursor = i-1
      break
    
method handleMouseButtonDownEvent(control: ListCtrlBase, event: MouseEvent) =
  control.buttonDown = true # XXX check: is it left?
  let dy = control.dy
  var y = event.y+control.yScrollPos
  for i in 1..control.len:    
    y -= dy
    if y <= 0:
      control.cursor = i-1
      break

method handleMouseButtonUpEvent(control: ListCtrlBase, event: MouseEvent) =
  control.buttonDown = false
  let time = epochTime()  
  if time-control.lastRelease<0.4:
    # double click
    let callback = control.onItemActivate
    if callback != nil:
      callback(control, control.cursor)
  control.lastRelease = time
      
method handleKeyDownEvent(control: ListCtrlBase, event: KeyboardEvent) =
  let ctrl_down = isDown(Key_ControlL) or isDown(Key_ControlR)
  let cursor = control.cursor
  if event.key == Key_Up and ctrl_down:
    control.cursor = 0
  elif event.key == Key_Up and cursor > 0:
    control.cursor = cursor-1
  elif event.key == Key_Down and ctrl_down:
    control.cursor = len(control)-1
  elif event.key == Key_Down and cursor < len(control)-1:
    control.cursor = cursor+1
  elif event.key == Key_return:
    let callback = control.onItemActivate
    if callback != nil:
      callback(control, control.cursor)

method itemsInserted*(control: ListCtrlBase, i, n: int) =
  if control.len == n:
    control.cursor = 0
  elif i<=control.cursor:
    control.cursor = control.cursor+n
  
method itemsRemoved*(control: ListCtrlBase, i, n: int) =
  if i+n<control.cursor:
    control.cursor = control.cursor-n
  elif i<control.cursor:
    control.cursor = i

      
      
type
  StringListCtrl* = ref object of ListCtrlBase
    items*: seq[string]

proc newStringListCtrl*(): StringListCtrl =
  result = new StringListCtrl
  result.init()
  result.items = @[]

method len*(control: StringListCtrl): int =
  len(control.items)

method handleDrawEvent*(control: StringListCtrl, event: DrawEvent) =
  let canvas = event.control.canvas
  let dy = canvas.getTextLineHeight()
  control.dy = dy
  let h = dy*len(control)
  if control.scrollableHeight != h:
    control.scrollableHeight= h
  # musste '*' in platformimpl einfügen!??
  #procCall control.Control.`scrollableWidth=`(h)

  
  canvas.areaColor = rgb(255, 255, 255)  
  canvas.textColor = rgb(255, 255, 255)
  canvas.lineColor = rgb(255, 255, 255)
  canvas.drawRectArea(0, 0, control.width, control.height)
  canvas.areaColor = rgb(0, 0, 255)

  var y = -control.yScrollPos
  for i, text in control.items:    
    if i == control.cursor:
      canvas.textColor = rgb(255, 255, 255)
      canvas.drawRectArea(0, y, control.width, dy)
    else:
      canvas.textColor = rgb(0, 0, 0)
    canvas.drawText(text, 0, y)
    y += dy
    
  canvas.drawRectOutline(0, 0, control.width, control.height)
  

type
  String2ListCtrl* = ref object of ListCtrlBase
    items*: seq[(string, string)]

proc newString2ListCtrl*(): String2ListCtrl =
  result = new String2ListCtrl
  result.init()
  result.items = @[]

method len*(control: String2ListCtrl): int =
  len(control.items)

method handleDrawEvent*(control: String2ListCtrl, event: DrawEvent) =
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
  for i, (text1, text2) in control.items:    
    if i == control.cursor:
      canvas.textColor = rgb(255, 255, 255)
      canvas.drawRectArea(0, y, control.width, dy)
    else:
      canvas.textColor = rgb(0, 0, 0)
    canvas.drawText(text1, 0, y)
    canvas.drawText(text2, 100, y)     
    y += dy    
  canvas.drawRectOutline(0, 0, control.width, control.height)



when isMainModule:
  ## Little demo

  app.init()

  var window = newWindow()
  
  var container = newLayoutContainer(Layout_Vertical)
  window.add(container)

  var textBox = newTextBox("")
  container.add(textBox)

  var myWidget = newString2ListCtrl()

  var items: seq[(string, string)] = @[]
  for i in 1..30:
    items.add(($i, $char(i+ord('a'))))
    
  myWidget.items = items
  myWidget.widthMode = WidthMode_Expand
  myWidget.heightMode = HeightMode_Expand
  myWidget.minHeight = 100
  myWidget.minWidth = 100
  myWidget.onItemActivate = proc(control: ListCtrlBase, index: int) =
    echo "item selected"
  #myWidget.onCursorMove = proc(control: ListCtrlBase, newIndex, oldIndex: int) =
  #  echo "cursor moved from ", oldIndex, " to ", newIndex

  container.add(myWidget)

  # configure searchbox
  textBox.onTextChange = proc(event: TextChangeEvent) =
    var newItems: seq[(string, string)]
    let text = textBox.text
    for item in items:
      if text in item[0]:
        newItems.add(item)
    myWidget.itemsRemoved(0, myWidget.len)
    myWidget.items = newItems
    myWidget.itemsInserted(0, newItems.len)  

  window.show()
  app.run()
