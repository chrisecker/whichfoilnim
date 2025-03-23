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
  pa*, pb*: Vec2 # Points a and b in canvas coordinates
  alpha*: float  # angle of tangent
  l*: float      # length of tangent line (model coordinates)
  positions*: seq[float]
  upper_values*: seq[float]
  lower_values*: seq[float]

  
proc newFoilModel1*(): FoilModel1 =
  result = new FoilModel1
  result.positions = @[0.05, 0.1, 0.3, 0.5, 0.7]
  result.upper_values = @[0.01, 0.01, 0.01, 0.01, 0.01]
  result.lower_values = @[-0.01, -0.01, -0.01, -0.01, -0.01]
  result.pa = vec2(0, 0)
  result.pb = vec2(1, 0)
  result.alpha = 90
  result.l = 0.3

  
proc newFoilModel1*(path: string): FoilModel1 =
  result = newFoilmodel1()
  result.airfoil = load_airfoil(path)

const DEG = PI/180.0
const RAD = 180.0/PI

proc compute_f2c*(figure: FoilModel1, airfoil: Airfoil): Mat3 =
  # computes foil->canvas.
  
  let pa = figure.pa
  let pb = figure.pb

  var alpha = figure.alpha*DEG

  let h0 = find_tangent(airfoil, alpha)
  let t0 = airfoil.points[0] # trailing edge, upper

  if figure.mirror:
    return compute_trafo(h0, t0, pb, pa)
  else:
    return compute_trafo(mirrory*h0, mirrory*t0, pa, pb)*mirrory

proc compute_m2c*(figure: FoilModel1): Mat3 =
  # berechnet model->canvas
  #
  # Im Modellsystem ist A auf (0, 0) und B auf (1, 0). Das gilt auch,
  # wenn eine Tangentenwinkel alpha>0 eingestellt ist und ensprechend
  # A nicht in der Leading Edge liegt.
  let pa = figure.pa
  let pb = figure.pb

  let h0 = mirrory*vec2(0, 0)
  let t0 = mirrory*vec2(1, 0)

  if figure.mirror:
    return compute_trafo(h0, t0, pb, pa)
  else:
    return compute_trafo(mirrory*h0, mirrory*t0, pa, pb)*mirrory
  

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

  
proc pt*(figure: FoilModel1): Vec2 =
  # Computes pt in model coordinates. Pt is the handle of the tangent
  # line.
  let alpha = figure.alpha*DEG
  let l = figure.l
  return vec2(cos(alpha), sin(alpha))*l
  
    
method get_handles*(figure: FoilModel1): seq[Handle] =
  # Gibt alle Handles in Canvas-Koordinaten
  let m2c = compute_m2c(figure)
  let label = figure.alpha.formatFloat(ffDecimal, 1) & "°"
  result = @[]
  result.add(SimpleHandle(position:figure.pa, idx:0))
  result.add(SimpleHandle(position:figure.pb, idx:1))
  result.add(SmallHandle(position:m2c*figure.pt, idx:2, label:label))

  let v = figure.pa-figure.pb
  let l = v.length
  var up = vec2(-v.y, v.x)
  var down = up*(-1)

  var idx = 3
  # upper sliders
  for i, pos in figure.positions:
    let y = figure.upper_values[i]
    let c = m2c*vec2(pos, y)
    let label = (y*100).formatFloat(ffDecimal, 1) 
    result.add(Slider(position:c, direction:up, idx:idx, label:label))
    idx += 1

  # lower sliders
  for i, pos in figure.positions:
    let y = figure.lower_values[i]
    let c = m2c*vec2(pos, y)    
    let label = (y*100).formatFloat(ffDecimal, 1) 
    result.add(Slider(position:c, direction:down, idx:idx, label:label))
    idx += 1
    
  # center sliders
  for pos in figure.positions:
    let c = m2c*vec2(pos, 0)    
    let label = (pos*100).formatFloat(ffDecimal, 1) 
    result.add(SmallHandle(position:c, idx:idx, label:label))
    idx += 1
    
    

  
method move_handle*(figure: FoilModel1, idx: int, pos: Vec2, trafo: Mat3) =
  let p = trafo.inverse*pos # pos in canvas-coordinates
  if idx == 0:
    figure.pa = p
  elif idx == 1:
    figure.pb = p
  elif idx == 2:
    let c2m = compute_m2c(figure).inverse
    let q = c2m*p
    figure.l = length(q)
    let alpha = arctan2(q.y, q.x)*180/PI
    figure.alpha = min(90, max(0, alpha))
  else:
    let q = compute_m2c(figure).inverse*p
    let n = len(figure.positions)
    let i1 = 3
    let i2 = 3+n
    let i3 = 3+2*n
    if idx < i2:
      # upper sliders
      let i = idx-i1    
      figure.upper_values[i] = q.y
    elif idx < i3:
      # lower sliders
      let i = idx-i2
      figure.lower_values[i] = q.y
    else:
      # center sliders
      let i = idx-i3
      figure.positions[i] = min(1, max(0, q.x))
      
      
    
      

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

  #draw_modelcs(figure, ctx, trafo) # XXX debug

    
method draw_dragged*(figure: FoilModel1, ctx: Context, trafo: Mat3) =
  figure.draw(ctx, trafo)
  ctx.strokeStyle = rgba(0, 0, 0, 255)
  ctx.lineWidth = 1

  let m2c = compute_m2c(figure)
  let pt = trafo*m2c*figure.pt
  var p: Vec2
  if figure.mirror:
    p = trafo*figure.pb
  else:
    p = trafo*figure.pa
    
  let d = pt-p
  ctx.strokeSegment(segment(p-d*0.3, pt))

  let tmp = d.normalize()*20
  let dup = vec2(-tmp.y, tmp.x)
  ctx.strokeSegment(segment(p-dup, p+dup))
  
  

method hit*(figure: FoilModel1, position: Vec2, trafo: Mat3): bool =
  let m = trafo*compute_f2c(figure, figure.airfoil)
  let p = m.inverse*position
  overlaps(p, Polygon(figure.airfoil.points))


proc match_sliders*(figure: FoilModel1, airfoil: Airfoil): (seq[float], seq[float]) =
  # Sucht die Werte (upper, lower), die airfoil bei gegebenem t am besten beschreiben
  let m = compute_m2c(figure).inverse*compute_f2c(figure, airfoil) # foil -> model
  let foil = airfoil.transformed(m)
  
  var upper_values, lower_values: seq[float]
  for i, pos in figure.positions:
    let (lower, upper) = interpolate_airfoil(foil, pos)
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
    if false:
      let c1 = 0.5*(upper+lower)
      let c2 = 0.5*(figure.upper_values[i]+figure.lower_values[i])    
      let h1 = upper-lower
      let h2 = figure.upper_values[i]-figure.lower_values[i]
      dist += (h1-h2)^2+(c1-c2)^2
    else:
      dist += (upper-figure.upper_values[i])^2+(lower-figure.lower_values[i])^2      
  return dist


proc badness_debug*(model: FoilModel1, airfoil: Airfoil): float =
  result = model.badness(airfoil)
  echo "Badness of ", model.airfoil.path, " against ", airfoil.path, ":", result
  echo "  positions=", model.positions
  echo "  upper_values=", model.upper_values
  echo "  lower_values=", model.lower_values
  echo "  pa=", model.pa
  echo "  pb=", model.pb
  echo "  alpha=", model.alpha

  
when isMainModule:
  import unittest
  import std/os
  
  suite "testing foilmodel1.nim":
    var model = newFoilModel1("foils/fx61168-il.dat")
    model.pa = vec2(100, 400)
    model.pb = vec2(500, 400)
    model.alpha = 90
    
    test "match_sliders":
      let fx61168 = load_airfoil("foils/fx61168-il.dat")
      discard model.match_sliders(fx61168)
      discard model.badness(fx61168)

    test "ag24":
      let f = load_airfoil("foils/ag24-il.dat")
    test "s2060":
      let f = load_airfoil("foils/s2060-il.dat")
    test "oaf095":
      let f = load_airfoil("foils/oaf095-il.dat")
    test "badness":
      var model2 = newFoilModel1("foils/fx61168-il.dat")
      model.set_sliders()
      model2.set_sliders()

      let f = load_airfoil("foils/sg6040-il.dat")
      
      discard model.badness_debug(f)
      
      #assert model2.badness(model2.airfoil) == 0      
      #assert model2.badness(f) == model.badness(f)

      model2.airfoil = f
      var m1 = compute_m2c(model).inverse*compute_f2c(model, f) # foil -> model
      echo $m1
      var m2 = compute_m2c(model2).inverse*compute_f2c(model2, f) # foil -> model
      echo $m2
      assert m1 == m2
      # Foil -> Modell sollte eigentlich nur vom Modell abhängen,
      # nicht von den beiden foils!
      
      assert model2.badness(f) == model.badness(f)
      

      
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
            let b = model.badness(testfoil)
          except:
            echo "Kann nicht berechnet werden", i, " ", d.path
            continue
