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
  airfoil*: Airfoil
  positions*: seq[float]
  upper_values*: seq[float]
  lower_values*: seq[float]

proc newFoilFigure*(path: string): FoilFigure =
  result = new FoilFigure
  result.airfoil = load_airfoil(path)
  result.positions = @[0.3, 0.5, 0.7]
  result.upper_values = @[0.01, 0.01, 0.01]
  result.lower_values = @[0.01, 0.01, 0.01]


proc pt*(figure: FoilFigure): Vec2 = # umbenennen in compute_pt?
  let r = rotate(float32(figure.alpha*PI/180.0))
  let ab = figure.pb-figure.pa
  return r*ab.normalize*figure.l+figure.pa

proc compute_trafo*(figure: FoilFigure, airfoil: Airfoil): Mat3 =
  # berechnet airfoil->canvas
  let pa = figure.pa
  let pb = figure.pb
  let pt = figure.pt
  let sp = scalarprd((pt-pa).normalize, (pb-pa).normalize)
  var alpha: float
  if sp>=1:
    alpha = 0.0
  elif sp<= -1:
    alpha = PI
  else:
    alpha = arccos(sp)
  let pa0 = find_tangent(figure.airfoil, alpha)
  #let pa0 = vec2(0, 0)
  #echo "pa0=", pa0, "->", round(arccos(cosalpha)*180/PI, 2), "°"
  let pb0 = figure.airfoil.points[0] # trailing edge, upper

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
  
  
method get_handles*(figure: FoilFigure): seq[Handle] =
  result = @[]
  result.add(SimpleHandle(position:figure.pa, idx:0))
  result.add(SimpleHandle(position:figure.pb, idx:1))
  result.add(SmallHandle(position:figure.pt, idx:2))

  let v = figure.pa-figure.pb
  let l = v.length
  let up = vec2(-v.y, v.x)*(1.0/l)
  let down = up*(-1)

  let foil2canvas = compute_trafo(figure, figure.airfoil)
  let canvas2foil = foil2canvas.inverse()

  let qa = canvas2foil*figure.pa # in foil-Koordinaten
  let qb = canvas2foil*figure.pb # ~

  var idx = 3
  # upper sliders
  for i, pos in figure.positions:
    let x = qa.x+(qb.x-qa.x)*pos
    let y = figure.upper_values[i]
    let c = foil2canvas*vec2(x, y)
    result.add(Slider(position:c, direction:up, idx:idx))
    idx += 1

  # lower sliders
  for i, pos in figure.positions:
    let x = qa.x+(qb.x-qa.x)*pos
    let y = figure.lower_values[i]
    let c = foil2canvas*vec2(x, y)    
    result.add(Slider(position:c, direction:down, idx:idx))
    idx += 1
    

  
method move_handle*(figure: FoilFigure, idx: int, pos: Vec2, trafo: Mat3) =
  let p = trafo.inverse*pos # pos in canvas-coordinates
  if idx == 0:
    figure.pa = p
  elif idx == 1:
    figure.pb = p
  elif idx == 2:
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
    alpha= max(0, alpha)
    alpha = min(90, alpha)
    figure.alpha = alpha
  else:
    let foil2canvas = compute_trafo(figure, figure.airfoil)
    let canvas2foil = foil2canvas.inverse()
    let q = canvas2foil*p # point in foil-coordinates
    
    if idx <= 5:
      # upper sliders
      let i = idx-3    
      figure.upper_values[i] = q.y
    else:
      # lower sliders
      let i = idx-6
      figure.lower_values[i] = q.y
      
      
    
      

proc compute_path*(foil: Airfoil, trafo: Mat3): Path =
  result = newPath()
  var p = foil.points[0]
  result.moveTo(trafo*vec2(p.x, p.y)) 
  for p in foil.points[1..^1]:
    result.lineTo(trafo*vec2(p.x, p.y)) 
  result.closePath()
  

method draw*(figure: FoilFigure, ctx: Context, trafo: Mat3) =
  ctx.fillStyle = rgba(0, 0, 255, 100)
  #ctx.strokeStyle = rgba(0, 0, 255, 100)
  let m = compute_trafo(figure, figure.airfoil)
  let path = compute_path(figure.airfoil, trafo*m)
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
  let m = trafo*compute_trafo(figure, figure.airfoil)
  let p = m.inverse*position
  overlaps(p, Polygon(figure.airfoil.points))


method match_sliders*(figure: FoilFigure, airfoil: Airfoil): (seq[float], seq[float]) =
  # Sucht die Werte (upper, lower), die airfoil bei gegebenem t am besten beschreiben
  let pt = find_tangent(airfoil, figure.alpha)
  let pb = figure.airfoil.points[0] # trailing edge, upper
  var upper_values = @[0.01, 0.015, 0.01] # XXX
  var lower_values = @[0.01, 0.012, 0.01]
  for i, pos in figure.positions:
    let x = (pt+(pb-pt)*pos).x
    let (lower, upper) = interpolate_airfoil(x, airfoil)
    lower_values[i] = lower
    upper_values[i] = upper    
  return (upper_values, lower_values)

  
method badness*(figure: FoilFigure, airfoil: Airfoil): float =
  let (upper_values, lower_values) = match_sliders(figure, airfoil)
  var dist = 0.0
  for i, upper in upper_values:
    let lower = lower_values[i]
    let c1 = 0.5*(upper+lower)
    let c2 = 0.5*(figure.upper_values[i]+figure.lower_values[i])    
    let h1 = upper-lower
    let h2 = figure.upper_values[i]-figure.lower_values[i]
    dist += (h1-h2)^2+(c1-c2)^2
  return dist


when isMainModule:
  import unittest
  import std/os
  
  suite "testing foilmodel.nim":
    var foil = newFoilFigure("devel/fx61168-il.dat")
    foil.pa = vec2(100, 400)
    foil.pb = vec2(500, 400)
    foil.alpha = 90

    # Exakte gematchte Werte
    foil.upper_values = @[0.1121102049946785, 0.10481564700603485, 0.06984496116638184]
    foil.lower_values = @[-0.05335169658064842, -0.04783700406551361, -0.01655637100338936]

    # Manuelle Werte
    #foil.upper_values = @[0.1139031946659088, 0.1058920323848724, 0.06800532341003418]      
    #foil.lower_values = @[-0.05836701393127441, -0.05029535293579102, -0.01220706105232239]
    
    test "match_sliders":
      let fx61168 = load_airfoil("devel/fx61168-il.dat")
      discard foil.match_sliders(fx61168)
      discard foil.badness(fx61168)

    test "ag24":
      let f = load_airfoil("foils/ag24-il.dat")
    test "s2060":
      let f = load_airfoil("foils/s2060-il.dat")
    test "oaf095":
      let f = load_airfoil("foils/oaf095-il.dat")
    test "allfoils":      
      var testfoil: Airfoil

      var i = -1
      for d in walkDir("foils", relative=false):
        i += 1
        if d.kind == pcFile:
          try:
            testfoil = load_airfoil($d.path)
          except:
            echo "Kann nicht geladen werden", i, " ", d.path
            if d.path != "foils/oaf095-il.dat":
               continue
            raise
          let b = foil.badness(testfoil)
          echo b, ": ",  $d.path 
