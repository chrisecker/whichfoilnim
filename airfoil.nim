import std/strutils
import std/strformat
import std/algorithm
import std/os
import vmath
import pixie


const eps = 1.0e-7 ## Epsilon used for float comparisons.

proc `=~` *(x, y: float): bool =
  result = abs(x - y) < eps

type
  ParseError* = object of CatchableError

  Airfoil* = object
    doc*: string
    points*: seq[Vec2]
    nupper*: int
    path*: string
    

func parse_coord(l: string): (float, float) =
  let s = l.strip().splitWhitespace()
  if len(s) != 2:
    raise newException(ParseError, "not a coordinate: " & l)
  try:
    let x = parseFloat(s[0])
    let y = parseFloat(s[1])
    return (x, y)
  except:
    raise newException(ParseError, "not a coordinate: " & l)


func is_coord(l: string): bool =
  try:
    discard parse_coord(l)    
  except:
    return false
  return true


  
proc load_airfoil*(path: string): Airfoil =
  var doc: string
  var points: seq[Vec2]
  var nupper: int

  # n Zeilen Kommentare. Ab der ersten Koordinate kein Kommentar mehr
  
  var l: string
  var i = 0
  var f = open(path)
  while readline(f, l):
    i += 1
    if l.strip() == "":
      continue
    if is_coord(l): 
      let (x, y) = parse_coord(l)
      points.add(vec2(x, y))
    else:
      if false and len(points)>0: # Problem: Kommentare am Ende, daher deaktiviert
        raise newException(
          ParseError, fmt"Error in line {i}: expected a point")
      if len(doc)>0:
        doc &= "\n"&l
      else:
        doc &= l

  let p0 = points[0]
  if p0.x>1.5 or p0.y > 1.5: # assume Letnicer's format
    
    # Lednicer's format lists points on the upper surface (from leading
    # edge to trailing edge), then points on the lower surface (from
    # leading edge to trailing edge). 

    nupper = int(p0.x+eps)
    #let nlower = int(p0.y+eps) ## could be used for assertion
    let upper = points[1..nupper].reversed()
    #echo upper.reversed()
    let lower = points[(nupper+1)..^1]
    points = upper & lower
  else:
    # assume Selig's format

    # Selig's format starts from the trailing edge of the airfoil,
    # goes over the upper surface, then over the lower surface, to
    # go back to the trailing edge.

    nupper = 0
    var ap = points[0]
    for p in points[1..^1]:
      if p.x > ap.x:
        break
      nupper += 1
      ap = p    
  close(f)      
  return Airfoil(doc: doc, points: points, nupper: nupper, path: path)

proc loadAirfoils*(path: string): seq[AirFoil] =
  # scan path (and sub paths) for airfoils and read them
  var r: seq[AirFoil]
  var foil: AirFoil
  
  for d in walkDir("foils", relative=false):
    if d.kind == pcFile and d.path.toLowerAscii.endsWith(".dat"):
      try:
        foil = load_airfoil($d.path)
      except:
        echo "Kann nicht geladen werden", d.path
        continue
      r.add(foil)

  proc myCmp(x, y: AirFoil): int =
    cmp(x.path, y.path)      
  r.sort(myCmp)
  return r
  
func upper_points*(foil: Airfoil): seq[Vec2] =
  foil.points[0..foil.nupper-1]
  
func lower_points*(foil: Airfoil): seq[Vec2] =
  foil.points[foil.nupper..^1]

func transformed*(foil: Airfoil, m: Mat3): Airfoil =
  var points: seq[Vec2]
  for p in foil.points:
    points.add(m*p)    
  return Airfoil(doc: foil.doc, points: points, nupper: foil.nupper)

func rotated*(foil: Airfoil, alpha: float): Airfoil =
  let m = rotate(float32(alpha))
  return foil.transformed(m)
  
func interpolate[T](x, x1, x2 : float, y1, y2: T): T =
  let s1 = min(x1, x2)
  let s2 = max(x1, x2)
  if not (s1 <= x and x <= s2):
    raise newException(ValueError, fmt"{x} not in interval {s1} .. {s2}. ")
  if x1 == x2:
    return y1
  let f = (x-x1)/(x2-x1)
  return y1+(y2-y1)*f  

proc interpolate_airfoil*(foil: Airfoil, t: float): (float, float) =
  # Determines the intersection of the profile coordinates with x=t
  #
  # Returns a tuple (lower, upper).
  
  var upper = -1.0
  var lower = -1.0

  # Upper coordinates, x is decreasing
  var points = foil.upper_points
  var ap = points[0]
  if t>ap.x or t<points[^1].x:
    raise newException(ValueError, fmt"A{t} not in interval {points[0].x}..{ap.x}. ")    
  for p in points[1..^1]:
    if (p.x<t and t<=ap.x): 
      upper = interpolate(t, p.x, ap.x, p.y, ap.y)
      break
    ap = p

  # Lower coordinates, x is increasing    
  points = foil.lower_points
  
  ap = points[0]
  if t<ap.x or t>points[^1].x:
    raise newException(ValueError, fmt"B{t} not in interval {ap.x}..{points[^1].x}. ")
  for p in points[1..^1]:
    if (ap.x<t and t<=p.x): 
      lower = interpolate(t, ap.x, p.x, ap.y, p.y)
      break
    ap = p
  return (lower, upper)
    
proc scalarprd*(p1, p2: Vec2): float =
  let p = p1*p2
  p.x+p.y

func deg(alpha: float): string =
  &"{round(alpha*180/PI, 2)}°"
  
proc find_tangent*(foil: Airfoil, alpha: float): Vec2 =
  # Gibt den Punkt auf der Profiloberseite zwischen Vorderkante und
  # max Dicke, an dem eine angelegte Tangente den Winkel alpha zu dem
  # Endpunkt B hat.

  # Hinweis: Selig's format starts from the trailing edge of the
  # airfoil, goes over the upper surface, then over the lower surface,
  # to go back to the trailing edge.

  let q = foil.points[0] # trailing edge, upper
  var ap = q
  var h = foil.points[0]
  var ah = h
  var beta = 0.0
  var abeta = 0.0
  var gamma = 0.0

  #echo "Suche ", arccos(cosalpha)*180/PI, "° (", cosalpha, ")"
  #echo foil.points
  for i, p in foil.points[1..^1]:
    h = (p+ap)*0.5
    if p.x<ap.x and p.y<=ap.y: # wir sind im richtigen Bereich
      beta = arccos(scalarprd((p-ap).normalize, (p-q).normalize))
      gamma = 0.5*(beta+abeta)

      #echo &"alpha={deg(alpha)} beta={deg(beta)} gamma={deg(gamma)} abeta={deg(abeta)}"
      if gamma >= alpha:
        #echo "case II", &" {deg(alpha)} : [{deg(abeta)} ... {deg(gamma)}]"         
        return interpolate(alpha, abeta, gamma, ah, ap)
      if beta >= alpha:        
        #echo "case I", &" {deg(alpha)} : [{deg(gamma)} ... {deg(beta)}]"         
        return interpolate(alpha, gamma, beta, ap, h)
    elif p.x>=ap.x: # wir sind schon auf der Nasenunterseite
      # ap ist der letzte Punkt der Nasenoberseite
      return ap
    ap = p
    ah = h
    abeta = beta
  #echo "Nicht gefunden"
  return q # XXX Besser: Exception?


proc find_maxthickness*(foil: Airfoil): float =
  # Find the x-coordinate of the max. thickness. Very bad algorithm.
  var max_t = -1.0
  var max_x = -1.0
  for p in foil.points[0..foil.nupper-2]:
    let (y1, y2) = interpolate_airfoil(foil, p.x)
    if y2-y1 > max_t:
      max_t = y2-y1
      max_x = p.x
  return max_x
  
  
proc compute_camberline*(foil: Airfoil): seq[Vec2] =
  # Compute the camber line from the airfoils. Again: very bad
  # algorithm.
  result = @[]  
  for p in foil.points[0..foil.nupper-2]:
    let t = p.x
    let (y1, y2) = interpolate_airfoil(foil, t)
    result.add(vec2(t, 0.5*(y1+y2)))

  
proc compute_path*(foil: Airfoil, trafo: Mat3): Path =
  # compute a pixie path from the airfoil shape
  result = newPath()
  if len(foil.points) == 0:
    return result
  var p = foil.points[0]
  result.moveTo(trafo*vec2(p.x, p.y)) 
  for p in foil.points[1..^1]:
    result.lineTo(trafo*vec2(p.x, p.y)) 
  result.closePath()


proc compute_camberpath*(foil: Airfoil, trafo: Mat3): Path =
  # compute a pixie path from the airfoils camber line
  result = newPath()

  let points = foil.compute_camberline()
  var p = points[0]
  result.moveTo(trafo*p) 
  for p in points[1..^1 ]:
    result.lineTo(trafo*p) 


  
when isMainModule:
  import unittest

  suite "testing airfoil.nim":
    test "parse_coord":
      check(parse_coord("1.2 3.4") == (1.2, 3.4))
      check(parse_coord("1.2 3.4 ") == (1.2, 3.4))
    test "is_coord":
      check(is_coord("1.2 3.4") == true)
      check(is_coord("1.2 3.4 ") == true)
      check(is_coord("1.2 ") == false)
    test "selig":
      let f = load_airfoil("foils/ag03-il.dat")
      check(len(f.points) == len(f.upper_points)+len(f.lower_points))
      check(f.nupper == 92)
      check(len(f.points) == 180)
    test "lednicer":
      let f = load_airfoil("foils/fx61168-il.dat")
      check(len(f.points) == len(f.upper_points)+len(f.lower_points))
      check(f.nupper == 49)
      check(len(f.points) == 98)
    test "ag03":
      let f = load_airfoil("foils/ag03-il.dat")
      check(len(f.points) == 180)
      let (y1, y2) = interpolate_airfoil(f, 0.1)
      check(y1 =~ -0.0131572867921)
      check(y2 =~ 0.0406201664946)
    test "ag24":
      let f = load_airfoil("foils/ag24-il.dat")
    test "s2060":
      let f = load_airfoil("foils/s2060-il.dat")
    test "interpolate":
      let y1 = vec2(0, 0)
      let y2 = vec2(1, 1)
      check(interpolate(2.5, 2, 3, y1, y2) == vec2(0.5, 0.5))
      check(interpolate(2.0, 2, 3, y1, y2) == vec2(0.0, 0.0))
      check(interpolate(3.0, 2, 3, y1, y2) == vec2(1.0, 1.0))      
    test "find_tangent":
      let f = load_airfoil("foils/clarky-il.dat")
      let p = find_tangent(f, 45/180.0*PI)
      echo $p
      check(0.007 < p.x and p.x < 0.009)
      check(0.013 < p.y and p.y < 0.014)
    test "find_maxthickness":
      let f = load_airfoil("foils/clarky-il.dat")
      let t = find_maxthickness(f)
      let (l, u) = interpolate_airfoil(f, t)
      # http://airfoiltools.com/airfoil/details?airfoil=clarky-il
      # Max thickness 11.7% at 28% chord.
      check(t =~ 0.28)
      check(round(u-l, 3) =~ 0.117)
    test "loadAirfoils":
        let foils = loadAirfoils("foils/")
        echo "Airfoils found: ", foils.len
