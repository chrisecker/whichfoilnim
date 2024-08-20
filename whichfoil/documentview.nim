import nigui
import pixie
import airfoil
import document
import std/strformat
import std/math



let bgimage = readImage("Pirat.png")
let foil = load_airfoil(open("foils/ag03-il.dat"))
var doc = Document()
doc.p1 = point(x:0.0, y:0.0)
doc.p2 = point(x:10.0, y:10.0)


proc tonigui(image: pixie.Image): nigui.Image =
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


func profile2image(p1, p2: point): Mat3 =
  let f = (p2-p1).length()
  let alpha = arctan2((p1.y-p2.y), p2.x-p1.x)
  let r = rotate(float32(alpha))
  let s = scale(vec2(f, float(-f)))
  let t = translate(vec2(p1.x, p1.y))
  return t*r*s 

  
# Definition of a custom widget
type DocView* = ref object of ControlImpl
  current: int
  
method handleDrawEvent(self: DocView, event: DrawEvent) =
  let canvas = self.canvas
  let w = canvas.width
  let h = canvas.height

  let image = newImage(w, h)
  image.fill(rgba(255, 255, 255, 255))
  draw(image, bgimage)
  
  let ctx = newContext(image)

  # handles
  let h1 = doc.p1
  let h2 = doc.p2
  let m = profile2image(h1, h2)

  ctx.strokeStyle = rgba(255, 0, 0, 255)
  ctx.fillStyle = rgba(255, 0, 0, 255)

  echo "current=", self.current, " p1=", doc.p1, " p2=", doc.p2
  if self.current == 1:
    ctx.strokeCircle(circle(h1, 10.0))    
  else:
    ctx.fillCircle(circle(h1, 10.0))    
  if self.current == 2:
    ctx.strokeCircle(circle(h2, 10.0))
  else:
    ctx.fillCircle(circle(h2, 10.0))

  ctx.strokeStyle = rgba(0, 0, 0, 255)  
  var ap = foil.points[0]
  for p in foil.points[1..^1]:
    ctx.strokeSegment(
      segment(m*p, m*ap))
    ap = p
      
  canvas.drawImage(tonigui(image), 0, 0)

proc inHandle(hpos, p: point): bool =
  abs(hpos.x-p.x)<10 and abs(hpos.y-p.y)<10
  
method handleMouseButtonDownEvent(self: DocView, event: MouseEvent) =
  #echo fmt"Mouse down {event.x} {event.y}" #, event.button
  let p = point(x: float(event.x), y: float(event.y))
  if inHandle(doc.p1, p):
    self.current = 1
    echo "in 1"
  elif inHandle(doc.p2, p):
    self.current = 2
    echo "in 2"
  self.forceRedraw

method handleMouseButtonUpEvent(self: DocView, event: MouseEvent) =
  self.current = 0
  self.forceRedraw
  echo fmt"Mouse up {event.x} {event.y}" #, event.button

# klappt nicht
#
#method onMouseMove(control: Canvas, event: MouseEvent) =
#    echo fmt"onMouseMove {event.x}, {event.y}" #, {event.button}"

  

# Constructor (optional)
proc newDocView*(): DocView =
  result = new DocView
  result.init()
  result.width = 500.scaleToDpi
  result.height = 500.scaleToDpi
  result.onClick = proc(event: ClickEvent) =
    echo "myWidget clicked" #, event

  # dafür brauchen wir die letzte Version: nimble install nigui@#e0a29e6

  #result.onMouseMove = proc(event: MouseEvent) =
  #  echo fmt"onMouseMove {event.x}, {event.y}" #, {event.button}"
    #if result.current>0:
    #  doc.p1 = point(x:float(event.x), y:float(event.y))
    #  result.forceRedraw
  




# Main program

app.init()

var window = newWindow()
var c = newDocView()
window.add(c)

# Wir können leider keine Methoden verenden. Das ist in NiGui noch
# nicht implementiert.
c.onMouseMove = proc(event: MouseEvent) =
  #echo fmt"onMouseMove {event.x}, {event.y}" #, {event.button}"
  let p = point(x:float(event.x), y:float(event.y))
  if c.current==1:
    doc.p1 = p
    echo "setting p1"
    c.forceRedraw
  elif c.current==2:
    doc.p2 = p
    echo "setting p2"
    c.forceRedraw


window.show()
app.run()
