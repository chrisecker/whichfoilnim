# Foilmodel 2
#
# Conventional model based on thickness and camber


import pixie
import std/strformat
import std/math
import std/strutils
import std/times
import std/hashes
import airfoil
import canvas
import foilmodel


  
type FoilModel2* = ref object of FoilModel
  pa*: Vec2 # Nose
  pb*: Vec2 # Tail
  pt1*: Vec2 # Thickness upper point (in model coordinates)
  pt2*: Vec2 # Thickness lower point (in model coordinates)
  pc*: Vec2 # Height and position of max (abs) camber (in model coordinates)


  
proc newFoilModel2*(): FoilModel2 =
  result = new FoilModel2
  result.pa = vec2(0, 0)
  result.pb = vec2(1, 0)
  result.pt1 = vec2(0.3, 0.1)
  result.pt2 = vec2(0.3, -0.05)
  result.pc = vec2(0.5, 0.05)
  



proc compute_f2c*(figure: FoilModel2, airfoil: Airfoil): Mat3 =
  # Berechnet foil->canvas.
  # Achtung: figure.airfoil wird nicht benutzt!
  let lhs2rhs = scale(vec2(1.0, -1.0))*translate(vec2(0, -1))
  
  let pa = figure.pa
  let pb = figure.pb

  var pa0, pb0: Vec2
  
  if figure.mirror:
    pa0 = lhs2rhs*airfoil.points[0] # trailing edge, upper
    pb0 = lhs2rhs*vec2(0, 0) # Origin -- usually leading edge
  else:
    pa0 = lhs2rhs*vec2(0, 0)
    pb0 = lhs2rhs*airfoil.points[0]
    

  # jetzt müssen wir eine Trafo finden mit der pa0 auf pa und pb0 auf
  # pb abgebildet wird.

  let d = pb-pa
  let d0 = pb0-pa0
  var f = 1.0
  
  let fx = d.length/d0.length
  let fy = fx
  var beta = arctan2(d.y, d.x)*f+arctan2(d0.y, d0.x)

  let b = translate(-pa0) # den Punkt pa0 in den Ursprung schieben
  let r = rotate(-float32(beta))  # Um beta drehen    
  let s = scale(vec2(fx, fy)) # Skalieren
  let t = translate(pa) # pa0 auf pa schieben
  result = t*s*r*b*lhs2rhs
  

proc compute_m2c*(figure: FoilModel2): Mat3 =
  # berechnet model->canvas
  #
  # Im Modellsystem ist A auf (0, 0) und B auf (1, 0). Das gilt auch,
  # wenn eine Tangentenwinkel alpha>0 eingestellt ist und ensprechend
  # A nicht in der Leading Edge liegt.
  var pa, pb: Vec2
  
  if figure.mirror:
    pa = figure.pb
    pb = figure.pa
  else:
    pa = figure.pa
    pb = figure.pb

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

  
proc draw_modelcs*(figure: FoilModel2, ctx: Context, trafo: Mat3) =
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

  
proc percent(f: float): string =
  (f*100).formatFloat(ffDecimal, 2) & "%"
  
method get_handles*(figure: FoilModel2): seq[Handle] =
  result = @[]
  result.add(SimpleHandle(position:figure.pa, idx:0))
  result.add(SimpleHandle(position:figure.pb, idx:1))
  
  let m = figure.compute_m2c()
  let t = (figure.pt2-figure.pt1).length
  let tc = 0.5*(figure.pt2.x+figure.pt1.x)
  let lt = "thickness:" & percent(t) & " (@" & percent(tc) & ")"

  let d = m*figure.pt1-m*figure.pt2
  result.add(Slider(position:m*figure.pt1, idx:2, labeL:lt, direction: d))
  result.add(Slider(position:m*figure.pt2, idx:3, label:lt, direction: -d))
  #let tc = (figure.pt1+figure.pt2)*0.5
  #result.add(SmallHandle(position:m*tc, idx:4))
  
  let c = figure.pc.y
  let lc = "camber: " & percent(c) & " (@" & percent(figure.pc.x) & ")"
  result.add(SmallHandle(position:m*figure.pc, idx:5, label:lc))

  
      
method move_handle*(figure: FoilModel2, idx: int, pos: Vec2, trafo: Mat3) =
  let p = trafo.inverse*pos # pos in canvas-coordinates
  let pm = figure.compute_m2c().inverse*p # pos in model-coordinates
  if idx == 0:
    figure.pa = p
  elif idx == 1:
    figure.pb = p
  elif idx == 2:
    figure.pt1 = pm
  elif idx == 3:
    figure.pt2 = pm
  #elif idx == 4:
  #  let d = pm-(figure.pt1+figure.pt2)*0.5
  #  figure.pt1 += d
  #  figure.pt2 += d    
  elif idx == 5:
    figure.pc = pm

  
method draw*(figure: FoilModel2, ctx: Context, trafo: Mat3) =
  ctx.fillStyle = rgba(0, 0, 255, 100)
  #ctx.strokeStyle = rgba(0, 0, 255, 100)
  ctx.lineWidth = 1

  if figure.fill:
    let m = compute_f2c(figure, figure.airfoil)
    let path = compute_path(figure.airfoil, trafo*m)
    ctx.fill(path)

  let m = figure.compute_m2c()
  ctx.fillStyle = rgba(255, 255, 0, 100)
  let pt1 = trafo*m*figure.pt1
  let pt2 = trafo*m*figure.pt2
  let c = (pt1+pt2)*0.5
  let r = (pt1-c).length
  ctx.fillCircle(circle(c, r))
  let d = (pt1-pt2)*0.2
  ctx.strokeSegment(segment(pt1+d, pt2-d))


  ctx.strokeStyle = rgba(255, 0, 0, 100)
  ctx.lineWidth = 2
  ctx.stroke(figure.airfoil.compute_camberpath(trafo*m))
  #draw_modelcs(figure, ctx, trafo) # XXX debug
  

method hit*(figure: FoilModel2, position: Vec2, trafo: Mat3): bool =
  let m = trafo*compute_f2c(figure, figure.airfoil)
  let p = m.inverse*position
  overlaps(p, Polygon(figure.airfoil.points))


method match_sliders*(figure: FoilModel2, airfoil: Airfoil): (Vec2, Vec2, Vec2) =
  # Sucht die Werte pt1, pt2 und pc, die airfoil am besten beschreiben
  var
    t, u, l: float
  
  t = find_maxthickness(airfoil)
  (l, u) = interpolate_airfoil(airfoil, t)
  let pt1 = vec2(t, u)
  let pt2 = vec2(t, l)
  
  t = find_maxcamber(airfoil)
  (l, u) = interpolate_airfoil(airfoil, t)
  let pc = vec2(t, 0.5*(l+u))
  
  return (pt1, pt2, pc)

     
proc set_sliders*(figure: FoilModel2) =
  let (pt1, pt2, pc) = match_sliders(figure, figure.airfoil)
  figure.pt1 = pt1
  figure.pt2 = pt2
  figure.pc = pc

method badness*(figure: FoilModel2, airfoil: Airfoil): float =
  let (pt1, pt2, pc) = match_sliders(figure, airfoil)
  result = 0.0
  if false:
    # very simple
    result += length(pt1-figure.pt1)
    result += length(pt2-figure.pt2)
    result += length(pc-figure.pc)
  else:
    # max thickness
    let d0 = length(pt1-pt2)
    let d1 = length(figure.pt1-figure.pt2)
    result += abs(d0-d1)

    # position of max thickness
    let xt0 = (pt1+pt2).x
    let xt1 = (figure.pt1+figure.pt2).x
    result += abs(xt0-xt1)*1e-2

    # max camber
    let c0 = pc.y
    let c1 = figure.pc.y
    result += abs(c0-c1)

    # position of max camber
    let xc0 = pc.x
    let xc1 = figure.pc.x
    result += abs(xc0-xc1)*1e-2
    
    

proc badness_debug*(model: FoilModel2, airfoil: Airfoil): float =
  result = model.badness(airfoil)
  echo "Badness of ", model.airfoil.path, " against ", airfoil.path, ":", result
  echo "  pa=", model.pa
  echo "  pb=", model.pb
  let (pt1, pt2, pc) = match_sliders(model, airfoil)
  echo "  pt1=", pt1, " vs. ", model.pt1
  echo "  pt2=", pt2, " vs. ", model.pt2
  echo "  pc=", pc, " vs. ", model.pc
  
when isMainModule:
  import unittest
  import std/os
  
  suite "testing foilmodel2.nim":
    var model = newFoilModel2()
    model.pa = vec2(100, 400)
    model.pb = vec2(500, 400)
    
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
      var model2 = newFoilModel2()
      model.airfoil = load_airfoil("foils/fx61168-il.dat")
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
