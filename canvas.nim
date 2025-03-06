import nigui
import pixie
import std/math
import std/hashes
import std/strformat
import std/strutils


  
func toTuple*(p: Vec2): (float, float) = # als Konverter funktioniert das leider nicht!
  return (p.x.float, p.y.float)

  
type Handle* = ref object of RootObj
  idx*: int
  position*: Vec2
  
method draw*(handle: Handle, ctx: Context, trafo: Mat3) {.base.} =
  discard
method draw_dragged*(handle: Handle, ctx: Context, trafo: Mat3) {.base.} =
  discard
  
method hit*(handle: Handle, position: Vec2, trafo: Mat3): bool {.base.} =
  false


  
type SimpleHandle* = ref object of Handle
  
method draw*(handle: SimpleHandle, ctx: Context, trafo: Mat3) =
  ctx.strokeStyle = rgba(0, 0, 0, 255)  
  ctx.strokeCircle(circle(trafo*handle.position, 10.0))

method draw_dragged*(handle: SimpleHandle, ctx: Context, trafo: Mat3) =
  ctx.strokeStyle = rgba(255, 0, 0, 255)  
  ctx.strokeCircle(circle(trafo*handle.position, 12.0))
  let dx = vec2(0, 4)
  let dy = vec2(4, 0)
  let p = trafo*handle.position
  ctx.strokeSegment(segment(p-dx*2, p-dx))
  ctx.strokeSegment(segment(p+dx*2, p+dx))
  ctx.strokeSegment(segment(p-dy*2, p-dy))
  ctx.strokeSegment(segment(p+dy*2, p+dy))
  
method hit*(handle: SimpleHandle, position: Vec2, trafo: Mat3): bool =
  return (trafo*handle.position - position).length < 10

  
type
  SmallHandle* = ref object of SimpleHandle

method draw*(handle: SmallHandle, ctx: Context, trafo: Mat3) =
  let r = 4.0
  let (x, y) = toTuple(trafo*handle.position)
  let box = Rect(x:x-r, y:y-r, w:2*r, h:2*r)
  ctx.fillStyle = rgba(0, 0, 0, 255)
  ctx.fillRect(box)

method draw_dragged*(handle: SmallHandle, ctx: Context, trafo: Mat3) =
  let r = 4.0
  let (x, y) = toTuple(trafo*handle.position)
  let box = Rect(x:x-r, y:y-r, w:2*r, h:2*r)
  ctx.strokeStyle = rgba(255, 0, 0, 255)
  ctx.strokeRect(box)
  
method hit*(handle: SmallHandle, position: Vec2, trafo: Mat3): bool =
  let p1 = trafo*handle.position
  let p2 = position
  const r = 6.0
  return abs(p1.x-p2.x)<r and abs(p1.y-p2.y)<r


  
type
  Slider* = ref object of SimpleHandle
    direction*: Vec2

proc compute_path(slider: Slider, trafo: Mat3): Path =
  let ex = slider.direction.normalize()
  let ey = vec2(-ex.y, ex.x)
  const r = 8.0
  let p0 = trafo*slider.position
  let p1 = p0+(ex+ey)*r
  let p2 = p0+(ex-ey)*r  
  result = newPath()
  result.moveTo(p0)
  result.lineTo(p1)
  result.lineTo(p2)
  result.closePath()

method draw*(slider: Slider, ctx: Context, trafo: Mat3) =  
  ctx.fillStyle = rgba(0, 0, 0, 255)
  ctx.fill(compute_path(slider, trafo))

method draw_dragged*(slider: Slider, ctx: Context, trafo: Mat3) =
  ctx.strokeStyle = rgba(255, 0, 0, 255)
  ctx.stroke(compute_path(slider, trafo))
    
method hit*(slider: Slider, position: Vec2, trafo: Mat3): bool =
  let p1 = trafo*slider.position
  let p2 = position
  const r = 8.0
  return abs(p1.x-p2.x)<r and abs(p1.y-p2.y)<r

  
  
type Figure* = ref object of RootObj

method bbox*(figure: Figure, trafo: Mat3): Rect {.base.} =
  Rect()       
method get_handles*(figure: Figure): seq[Handle] {.base.} =
  @[]
method move_handle*(figure: Figure, handleidx: int, pos: Vec2, trafo: Mat3) {.base.} =
  discard
method draw*(figure: Figure, ctx: Context, trafo: Mat3) {.base.} =
  discard
method draw_dragged*(figure: Figure, ctx: Context, trafo: Mat3) {.base.} = # umbenennen: selected
  figure.draw(ctx, trafo)
  
method hit*(figure: Figure, position: Vec2, trafo: Mat3): bool {.base.} =
  false
  



type CanvasCtrl* = ref object of ControlImpl
  current*: Figure
  figures*: seq[Figure]
  drag_start: Vec2
  drag_handle: Handle
  trafo*: Mat3 # canvas 2 screen
  bgimage*: pixie.Image
  cash_hash : Hash
  cash_image : pixie.Image


proc hash(trafo: Mat3): Hash = 
  var h: Hash = 0
  for i in 0..2:
    for j in 0..2:
      h = h !& hash(trafo[i, j])
  return h

  
proc tonigui(image: pixie.Image): nigui.Image =
  # Helper
  var niGuiImage = nigui.newImage()
  niGuiImage.resize(image.width, image.height)
  var niGuiImageData = niGuiImage.beginPixelDataAccess()    
  let n = image.width*image.height
  copyMem(niGuiImageData[0].addr,
          image.data[0].addr, n * 4)
  var p = cast[cstring](niGuiImageData[0].addr)
  for j in countUp(0, 4*n-4, 4):
    (p[j], p[j+2]) = (p[j+2], p[j])
  niGuiImage.endPixelDataAccess()
  return niGuiImage

  
  
method handleDrawEvent*(ctrl: CanvasCtrl, event: DrawEvent) =
  let canvas = ctrl.canvas
  let w = canvas.width
  let h = canvas.height

  let myhash = hash(ctrl.trafo) !& hash(w) !& hash(h)
  var image: pixie.Image

  if isNil(ctrl.bgimage):
      image = newImage(w, h)
      image.fill(rgba(255, 255, 255, 255))      
  else:
    if ctrl.cash_hash == myhash:
      image = ctrl.cash_image.copy()
    else:
      image = newImage(w, h)
      image.fill(rgba(255, 255, 255, 255))
      image.draw(ctrl.bgimage, ctrl.trafo)
      ctrl.cash_image = image.copy()
      ctrl.cash_hash = myhash
  
  let ctx = newContext(image)
  for figure in ctrl.figures:
    if figure == ctrl.current:
      figure.draw_dragged(ctx, ctrl.trafo)
    else:
      figure.draw(ctx, ctrl.trafo)

  var drag_handle_idx = -1
  if not isNil(ctrl.drag_handle):
    drag_handle_idx = ctrl.drag_handle.idx
    
  if not isNil(ctrl.current):
    for handle in ctrl.current.get_handles:
      if handle.idx != drag_handle_idx:
        handle.draw(ctx, ctrl.trafo)
      else:
        handle.draw_dragged(ctx, ctrl.trafo)

  canvas.drawImage(tonigui(image), 0, 0)



proc handleClick(ctrl: CanvasCtrl, p: Vec2) =
  var found = false
  if not isNil(ctrl.current):
    for i, handle in ctrl.current.get_handles:
      if handle.hit(p, ctrl.trafo) == true:
        ctrl.drag_start = p
        ctrl.drag_handle = handle
        ctrl.forceRedraw
        found = true
  if not found:
    for figure in ctrl.figures:
      if figure.hit(p, ctrl.trafo):
        ctrl.current = figure
        ctrl.forceRedraw()
        found = true
  if not found:
    ctrl.current = nil
    ctrl.forceRedraw()


proc handleZoomIn(ctrl: CanvasCtrl, p: Vec2) =
  let q = ctrl.trafo.inverse()*p
  let s = scale(vec2(1.1, 1.1))
  ctrl.trafo = ctrl.trafo*translate(q)*s*translate(-q)
  ctrl.forceRedraw


proc handleZoomOut(ctrl: CanvasCtrl, p: Vec2) =
  let q = ctrl.trafo.inverse()*p
  let s = scale(vec2(1/1.1, 1/1.1))
  ctrl.trafo = ctrl.trafo*translate(q)*s*translate(-q)
  ctrl.forceRedraw
  

method handleMouseScrollEvent*(ctrl: CanvasCtrl, event: MouseScrollEvent) =
  let p = vec2(float(event.x), float(event.y))
  echo "Scroll", event.direction
  if event.direction == MouseScroll_Up:
    handleZoomIn(ctrl, p)
  elif event.direction == MouseScroll_Down:
    handleZoomOut(ctrl, p)
  
method handleMouseButtonDownEvent*(ctrl: CanvasCtrl, event: MouseEvent) =
  let p = vec2(float(event.x), float(event.y))
  if event.button == MouseButton_Left:
    handleClick(ctrl, p)
  elif event.button == MouseButton_Middle:
    handleZoomIn(ctrl, p)
  elif event.button == MouseButton_Right:
    handleZoomOut(ctrl, p)
    
    

method handleMouseButtonUpEvent*(ctrl: CanvasCtrl, event: MouseEvent) =
  let handle = ctrl.drag_handle
  if isNil(handle):    
    return
  let p = vec2(float(event.x), float(event.y))
  let figure = ctrl.current
  if isNil(figure):
    return
  figure.move_handle(handle.idx, ctrl.trafo*handle.position-ctrl.drag_start+p, ctrl.trafo)
  ctrl.drag_handle = nil
  ctrl.forceRedraw

method handleMouseMoveEvent*(ctrl: CanvasCtrl, event: MouseEvent) =
  
  # handleMouseMoveEvent fehlt in nigui 2.81!  dafür brauchen wir die letzte
  # Version:
  # - nimble install nigui@#e0a29e6
  # mittlerweile:
  # - nimble install nigui@#f8167a8
  let handle = ctrl.drag_handle
  if isNil(handle):
    return
  let p = vec2(float(event.x), float(event.y))
  let figure = ctrl.current
  if isNil(figure):
    return
  figure.move_handle(handle.idx, ctrl.trafo*handle.position-ctrl.drag_start+p, ctrl.trafo)
  ctrl.forceRedraw



proc newCanvasCtrl*(): CanvasCtrl =
  result = new CanvasCtrl
  result.init()
  result.width = 500.scaleToDpi
  result.height = 500.scaleToDpi



when isMainModule:
  ## Little drawing demo
  
  type RectFigure = ref object of Figure
    p1, p2: Vec2
    r: float

  func mk_rect(p1, p2: Vec2): Rect =
    let (x1, y1) = p1.toTuple
    let (x2, y2) = p2.toTuple
    let xmin = min(x1, x2)
    let ymin = min(y1, y2)
    Rect(x:xmin, y:ymin, w:max(x1, x2)-xmin, h:max(y1, y2)-ymin)

  method bbox(figure: RectFigure, trafo: Mat3): Rect =
    mk_rect(trafo*figure.p1, trafo*figure.p2)

  method get_handles(figure: RectFigure): seq[Handle] =
    result = @[]
    result.add(SimpleHandle(position:figure.p1, idx:0))
    result.add(SimpleHandle(position:figure.p2, idx:1))
    let (x1, y1) = figure.p1.toTuple
    let (x2, y2) = figure.p2.toTuple
    let r = figure.r
    var dx = 1.0
    var dy = 1.0
    if x2<x1:
      dx = -1.0
    if y2<y1:
      dy = -1.0
    result.add(SmallHandle(position:vec2(x1+dx*r, y1), idx:2))
    #result.add(SmallHandle(position:vec2(x1, y1+dy*r), idx:3))
    result.add(Slider(position:vec2(x1, y1+dy*r), direction:figure.p2-figure.p1, idx:3)) # XXX

  method move_handle(figure: RectFigure, handleidx: int, pos: Vec2, trafo: Mat3) =
    let p = trafo.inverse*pos
    if handleidx == 0:
      figure.p1 = p
    elif handleidx == 1:
      figure.p2 = p
    else:
      let (x1, y1) = figure.p1.toTuple
      let (x2, y2) = figure.p2.toTuple
      var dx = 1.0
      var dy = 1.0
      if x2<x1:
        dx = -1.0
      if y2<y1:
        dy = -1.0

      if handleidx == 2:
        figure.r = dx*(p.x-x1)
      elif handleidx == 3:
        figure.r = dy*(p.y-y1)
      if figure.r<0.0:
        figure.r = 0.0

  method draw(figure: RectFigure, ctx: Context, trafo: Mat3) =
    ctx.fillStyle = rgba(0, 255, 0, 100)
    let box = mk_rect(trafo*figure.p1, trafo*figure.p2)
    ctx.fillRoundedRect(box, figure.r) # XXX r ist falsch

  method hit(figure: RectFigure, position: Vec2, trafo: Mat3): bool =
    overlaps(position, figure.bbox(trafo))



  type CircleFigure = ref object of Figure
    pc: Vec2
    pr: Vec2

  method bbox(figure: CircleFigure, trafo: Mat3): Rect =
    let (x, y) = toTuple(trafo*figure.pc)
    let r = length(trafo*figure.pr)
    let d = 2*r
    Rect(x:x-r, y:y-r, w:d, h:d)

  method get_handles(figure: CircleFigure): seq[Handle] =
    result = @[]
    result.add(SimpleHandle(position:figure.pc, idx:0))
    result.add(SmallHandle(position:figure.pc+figure.pr, idx:1))

  method move_handle(figure: CircleFigure, handleidx: int, pos: Vec2, trafo: Mat3) =
    let p = trafo.inverse*pos
    if handleidx == 0:
      figure.pc = p
    elif handleidx == 1:
      figure.pr = p-figure.pc

  method draw(figure: CircleFigure, ctx: Context, trafo: Mat3) =
    ctx.fillStyle = rgba(255, 255, 0, 100)
    let pc = trafo*figure.pc
    let pr = trafo*(figure.pr+figure.pc)-pc
    ctx.fillCircle(circle(pc, pr.length))

  method hit(figure: CircleFigure, position: Vec2, trafo: Mat3): bool =
    (trafo*figure.pc-position).length <= (trafo*figure.pr).length



  ## Main
  app.init()

  var window = newWindow()
  var c = newCanvasCtrl()
  c.trafo = mat3(
      0.5, 0.0, 0.0,
      0.0, 0.5, 0.0,
      0.0, 0.0, 1.0
    )


  var square = RectFigure(p1:vec2(10, 10), p2:vec2(200, 200), r:20)
  c.figures.add(square)
  var circle = CircleFigure(pc:vec2(200, 200), pr:vec2(0, 100))
  c.figures.add(circle)

  c.widthMode = WidthMode_Fill
  c.heightMode = HeightMode_Expand
  window.add(c)


  window.onKeyDown = proc(event: KeyboardEvent) =
    if event.key == Key_Plus:
      c.trafo = c.trafo*scale(vec2(1.1, 1.1))
      c.forceRedraw
    elif event.key == Key_Minus:
      const f = 1/1.1
      c.trafo = c.trafo*scale(vec2(f, f))
    elif event.key == Key_Left:
      c.trafo = c.trafo*translate(vec2(5, 0))
    elif event.key == Key_Right:
      c.trafo = c.trafo*translate(vec2(-5, 0))
    elif event.key == Key_Up:
      c.trafo = c.trafo*translate(vec2(0, 5))
    elif event.key == Key_Down:
      c.trafo = c.trafo*translate(vec2(0, -5))
    elif Key_Q.isDown() and Key_ControlL.isDown():
      app.quit()    
    c.forceRedraw


  echo "Benutze +, -, left, right, up, down"

  window.show()
  app.run()
