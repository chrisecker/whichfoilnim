import pixie
import std/strformat
import std/math
import std/strutils
import std/times
import std/hashes
import airfoil
import canvas
import foilmodel



  
type FoilModel1* = ref object of FoilModel
  pa*, pb*: Vec2
  alpha*: float # angle of tangent
  l*: float # length of tangent line
  positions*: seq[float]
  upper_values*: seq[float]
  lower_values*: seq[float]

proc newFoilModel1*(path: string): FoilModel1 =
  result = new FoilModel1
  result.airfoil = load_airfoil(path)
  result.positions = @[0.1, 0.3, 0.5, 0.7]
  result.upper_values = @[0.01, 0.01, 0.01, 0.01]
  result.lower_values = @[-0.01, -0.01, -0.01, -0.01]


proc pt*(figure: FoilModel1): Vec2 =
  var alpha = float32(figure.alpha*PI/180.0)
  if figure.mirror:
    alpha = -alpha
  var r = rotate(alpha)
  let ab = figure.pb-figure.pa
  return r*ab.normalize*figure.l+figure.pa

proc compute_f2c*(figure: FoilModel1, airfoil: Airfoil): Mat3 =
  # berechnet foil->canvas
  let pa = figure.pa
  let pb = figure.pb
  let pt = figure.pt

  let alpha = figure.alpha*PI/180.0
  let pa0 = find_tangent(figure.airfoil, alpha)
  let pb0 = figure.airfoil.points[0] # trailing edge, upper

  # jetzt müssen wir eine Trafo finden mit der pa0 auf pa und pb0 auf
  # pb abgebildet wird.

  let d = pb-pa
  let d0 = pb0-pa0
  var f = 1.0
  if figure.mirror:
    f = -1.0
  
  let fx = d.length/d0.length
  let fy = -fx*f
  var beta = arctan2(d.y, d.x)*f+arctan2(d0.y, d0.x)

  let b = translate(vec2(float(-pa0.x), float(-pa0.y))) # den Punkt pa0 in den Ursprung schieben

  let r = rotate(float32(beta))  # Um beta drehen    
  let s = scale(vec2(fx, fy)) # Skalieren
  let t = translate(pa) # pa0 auf pa schieben
  result = t*s*r*b
  

proc compute_m2c*(figure: FoilModel1): Mat3 =
  # berechnet model->canvas
  #
  # Im Modellsystem ist A auf (0, 0) und B auf (1, 0). Das gilt auch,
  # wenn eine Tangentenwinkel alpha>0 eingestellt ist und ensprechend
  # A nicht in der Leading Edge liegt.
  let pa = figure.pa
  let pb = figure.pb

  let ab = (pb-pa)
  let l = (pa-pb).length
  var f = 1.0
  if figure.mirror:
    f = -1.0
  let beta = arctan2(ab.y, ab.x)
  let r = rotate(float32(f*beta))  # Um beta drehen
  let s = scale(vec2(l, -f*l)) # Skalieren
  let t = translate(pa) # (0, 0) auf pa schieben  
  result = t*s*r

proc draw_modelcs*(figure: FoilModel1, ctx: Context, trafo: Mat3) =
  # for debugging

  let m = trafo*figure.compute_m2c()
  const d = 0.01
  
  ctx.strokeStyle = rgba(255, 0, 0, 100)
  ctx.lineWidth = 2
  
  ctx.strokeSegment(segment(m*vec2(0.0, 0.0), m*vec2(1.0, 0.0)))
  ctx.strokeSegment(segment(m*vec2(1, 0), m*vec2(1-d, d)))
  ctx.strokeSegment(segment(m*vec2(1, 0), m*vec2(1-d, -d)))

  
  ctx.strokeSegment(segment(m*vec2(0, -0.1), m*vec2(0, 0.1)))
  ctx.strokeSegment(segment(m*vec2(0, 0.1), m*vec2(-d, 0.1-d)))
  ctx.strokeSegment(segment(m*vec2(0, 0.1), m*vec2(d, 0.1-d)))

  if false:
    ctx.fontSize = 20
    ctx.fillStyle = rgba(0, 0, 0, 255)  
    ctx.fillText("A", m*vec2(0, 0))    
    ctx.fillText("B", m*vec2(1, 0))

  
  
method get_handles*(figure: FoilModel1): seq[Handle] =
  result = @[]
  result.add(SimpleHandle(position:figure.pa, idx:0))
  result.add(SimpleHandle(position:figure.pb, idx:1))
  let label = figure.alpha.formatFloat(ffDecimal, 1) & "°"
  result.add(SmallHandle(position:figure.pt, idx:2, label:label))

  let v = figure.pa-figure.pb
  let l = v.length
  var up = vec2(-v.y, v.x)*(1.0/l)
  var down = up*(-1)
  if figure.mirror:
    up = -up
    down = -down

  #let foil2canvas = compute_f2c(figure, figure.airfoil)
  #let canvas2foil = foil2canvas.inverse()

  let m2c = compute_m2c(figure)
  
  var idx = 3
  # upper sliders
  for i, pos in figure.positions:
    let x = pos
    let y = figure.upper_values[i]
    let c = m2c*vec2(x, y)
    let label = (y*100).formatFloat(ffDecimal, 1) 
    result.add(Slider(position:c, direction:up, idx:idx, label:label))
    idx += 1

  # lower sliders
  for i, pos in figure.positions:
    let x = pos
    let y = figure.lower_values[i]
    let c = m2c*vec2(x, y)    
    let label = (y*100).formatFloat(ffDecimal, 1) 
    result.add(Slider(position:c, direction:down, idx:idx, label:label))
    idx += 1
    

  
method move_handle*(figure: FoilModel1, idx: int, pos: Vec2, trafo: Mat3) =
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
    if figure.mirror:
      alpha = -alpha
    if alpha > 180:
      alpha -= 360
    elif alpha < -180:
      alpha += 360
    alpha= max(0, alpha)
    alpha = min(90, alpha)
    figure.alpha = alpha
  else:
    let q = compute_m2c(figure).inverse*p
    
    if idx <= 2+len(figure.positions):
      # upper sliders
      let i = idx-3    
      figure.upper_values[i] = q.y
    else:
      # lower sliders
      let i = idx-3-len(figure.positions)
      figure.lower_values[i] = q.y
      
      
    
      

proc compute_path*(foil: Airfoil, trafo: Mat3): Path =
  result = newPath()
  var p = foil.points[0]
  result.moveTo(trafo*vec2(p.x, p.y)) 
  for p in foil.points[1..^1]:
    result.lineTo(trafo*vec2(p.x, p.y)) 
  result.closePath()
  

method draw*(figure: FoilModel1, ctx: Context, trafo: Mat3) =
  ctx.fillStyle = rgba(0, 0, 255, 100)
  #ctx.strokeStyle = rgba(0, 0, 255, 100)
  ctx.lineWidth = 1

  if figure.fill:
    let m = compute_f2c(figure, figure.airfoil)
    let path = compute_path(figure.airfoil, trafo*m)
    ctx.fill(path)

  draw_modelcs(figure, ctx, trafo) # XXX debug
  
method draw_dragged*(figure: FoilModel1, ctx: Context, trafo: Mat3) =
  figure.draw(ctx, trafo)
  ctx.strokeStyle = rgba(0, 0, 0, 255)
  ctx.lineWidth = 1

  let pt = trafo*figure.pt
  let pa = trafo*figure.pa
  let d = pt-pa
  ctx.strokeSegment(segment(pa-d*0.3, pt))

  let tmp = d.normalize()*20
  let dup = vec2(-tmp.y, tmp.x)
  ctx.strokeSegment(segment(pa-dup, pa+dup))
  
  

method hit*(figure: FoilModel1, position: Vec2, trafo: Mat3): bool =
  let m = trafo*compute_f2c(figure, figure.airfoil)
  let p = m.inverse*position
  overlaps(p, Polygon(figure.airfoil.points))


method match_sliders*(figure: FoilModel1, airfoil: Airfoil): (seq[float], seq[float]) =
  # Sucht die Werte (upper, lower), die airfoil bei gegebenem t am besten beschreiben
  let m = compute_m2c(figure).inverse*compute_f2c(figure, airfoil) # foil -> model
  let foil = airfoil.transformed(m)
  
  var upper_values, lower_values: seq[float]
  for i, pos in figure.positions:
    let (lower, upper) = interpolate_airfoil(pos, foil)
    lower_values.add(lower)
    upper_values.add(upper)    
  return (upper_values, lower_values)


proc set_sliders*(figure: FoilModel1) =
    let (upper, lower) = figure.match_sliders(figure.airfoil)
    figure.upper_values = upper
    figure.lower_values = lower


method badness*(figure: FoilModel1, airfoil: Airfoil): float =
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
  
  suite "testing foilmodel1.nim":
    var foil = newFoilModel1("devel/fx61168-il.dat")
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
          echo $d.path
          try:
            testfoil = load_airfoil($d.path)
          except:
            echo "Kann nicht geladen werden", i, " ", d.path
            if d.path != "foils/oaf095-il.dat":
               continue
            raise
          try:
            let b = foil.badness(testfoil)
          except:
            echo "Kann nicht berechnet werden", i, " ", d.path
            continue
          echo b, ": ",  $d.path 
