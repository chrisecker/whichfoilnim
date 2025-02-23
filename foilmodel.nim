import pixie
import std/strformat
import std/math
import std/strutils
import std/times
import std/hashes
import airfoil
import canvas




type FoilFigure* = ref object of Figure
  pa*, pb*: Vec2
  alpha*: float # angle of tangent
  l*: float # length of tangent line
  foil*: airfoil
  su0*, su1*, su2* : float # upper handles
  sl0*, sl1*, sl2* : float # lower handles

proc newFoilFigure*(f: File): FoilFigure =
  result = new FoilFigure
  result.foil = load_airfoil(f)

proc pt*(figure: FoilFigure): Vec2 = # umbenennen in compute_pt?
  let r = rotate(float32(figure.alpha*PI/180.0))
  let ab = figure.pb-figure.pa
  return r*ab.normalize*figure.l+figure.pa  
  
method get_handles*(figure: FoilFigure): seq[Handle] =
  result = @[]
  result.add(SimpleHandle(position:figure.pa, idx:0))
  result.add(SimpleHandle(position:figure.pb, idx:1))
  result.add(SmallHandle(position:figure.pt, idx:2))

  let v = figure.pa-figure.pb
  let l = v.length
  let d = vec2(-v.y, v.x)*(1.0/l)
  
  var c = figure.pb+v*0.3+d*l*figure.su0
  result.add(Slider(position:c, direction:d, idx:3))

  #c = figure.pb+v*0.5+d*l*figure.su1
  #result.add(Slider(position:c, direction:d, idx:4))

  
method move_handle*(figure: FoilFigure, handleidx: int, pos: Vec2, trafo: Mat3) =
  let p = trafo.inverse*pos
  if handleidx == 0:
    figure.pa = p
  elif handleidx == 1:
    figure.pb = p
  elif handleidx == 2:
    figure.l = length(figure.pa-p)
    let ab = figure.pb-figure.pa
    let at = p-figure.pa
    let a1 = arctan2(ab.y, ab.x)
    let a2 = arctan2(at.y, at.x)
    var alpha = (a1-a2)*180/PI
    if alpha > 180:
      alpha -= 360
    elif alpha < -180:
      alpha += 360
    if alpha<0:
      alpha = 0
    if alpha > 90:
      alpha = 90
    figure.alpha = alpha
  elif handleidx == 3:
    let v = figure.pa-figure.pb
    let l = v.length
    let d = vec2(-v.y, v.x)*(1.0/l)

    var c = figure.pb+v*0.3
    #echo scalarprd(d, p-c)/l
    figure.su0 = max(0, scalarprd(d, p-c)/l)
    
      
proc compute_trafo*(figure: FoilFigure): Mat3 =
  # berechnet airfoil->canvas
  let pa = figure.pa
  let pb = figure.pb
  let pt = figure.pt
  let alpha = arccos(scalarprd((pt-pa).normalize, (pb-pa).normalize))
  let pa0 = find_tangent(figure.foil, alpha)
  #let pa0 = vec2(0, 0)
  #echo "pa0=", pa0, "->", round(arccos(cosalpha)*180/PI, 2), "°"
  let pb0 = figure.foil.points[0] # trailing edge, upper

  # jetzt müssen wir eine Trafo finden mit der pa0 auf pa und pb0 auf
  # pb abgebildet wird.

  let d = pb-pa
  let d0 = pb0-pa0
  
  let f = d.length/d0.length
  let beta = arctan2(d.y, d.x)+arctan2(d0.y, d0.x)

  let b = translate(vec2(float(-pa0.x), float(-pa0.y))) # den Punkt pa0 in den Ursprung schieben
  #echo "b*pa0 sollte 0,0 sein: ", b*pa0 # ok
  let r = rotate(float32(beta))  # Um beta drehen
  #echo "b*pa0 sollte noch immer 0,0 sein: ", b*pa0 # ok
  #echo "pa0-pb0 sollte parallel zu pa-pb sein", (pa0-pb0).normalize, " vs ", (pa-pb).normalize
  let s = scale(vec2(f, float(-f))) # Skalieren
  let t = translate(pa) # pa0 auf pa schieben
  result = t*s*r*b
  #echo result*pa0, "vs. ", pa
  #return t*s*r*b

proc compute_path*(foil: airfoil, trafo: Mat3): Path =
  result = newPath()
  var p = foil.points[0]
  result.moveTo(trafo*vec2(p.x, p.y)) 
  for p in foil.points[1..^1]:
    result.lineTo(trafo*vec2(p.x, p.y)) 
  result.closePath()
  

method draw*(figure: FoilFigure, ctx: Context, trafo: Mat3) =
  ctx.fillStyle = rgba(0, 0, 255, 100)
  #ctx.strokeStyle = rgba(0, 0, 255, 100)
  let m = compute_trafo(figure)
  let path = compute_path(figure.foil, trafo*m)
  ctx.fill(path)
  #ctx.stroke(path)
  
method draw_dragged*(figure: FoilFigure, ctx: Context, trafo: Mat3) =
  figure.draw(ctx, trafo)
  ctx.strokeStyle = rgba(0, 0, 0, 255)
  let pt = trafo*figure.pt
  let pa = trafo*figure.pa
  let d = pt-pa
  ctx.strokeSegment(segment(pa-d*0.3, pt))

  let tmp = d.normalize()*20
  let dup = vec2(-tmp.y, tmp.x)
  ctx.strokeSegment(segment(pa-dup, pa+dup))
  
  let font = readFont("devel/NotoSans-Regular_4.ttf")
  font.size = 20
  font.paint.color = color(0, 0, 0) # warum geht hier nicht rgba?
  let text = figure.alpha.formatFloat(ffDecimal, 1) & "°"
  let t = font.typeset(text)  
  ctx.image.fillText(t, translate(pt))
  # Alternativ: in draw_dragged des Handels!
  

method hit*(figure: FoilFigure, position: Vec2, trafo: Mat3): bool =
  let m = trafo*compute_trafo(figure)
  let p = m.inverse*position
  overlaps(p, Polygon(figure.foil.points))

  
