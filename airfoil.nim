import std/strutils
import std/strformat
import std/enumerate
import std/algorithm
import vmath


const eps = 1.0e-7 ## Epsilon used for float comparisons.

proc `=~` *(x, y: float): bool =
  result = abs(x - y) < eps

type
  ParseError* = object of CatchableError

  Airfoil* = object
    doc*: string
    points*: seq[Vec2]

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

    let nupper = int(p0.x+eps)
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

    discard # nothing to do
    
  close(f)      
  return Airfoil(doc: doc, points: points)
#         l = next()
    
#     for l in f:
#         if not l.strip():
#             continue
#         if not is_coord(l):
#             continue # raise ParseError("Expected coordinate tuple: "+repr(l))
#         x, y = [float(s) for s in l.split()]
#         values.append((x, y))

#     px, py = values[0]
#     if px>1.5 or py > 1.5: # assume Letnicer's format
    
#         # Lednicer's format lists points on the upper surface (from leading
#         # edge to trailing edge), then points on the lower surface (from
#         # leading edge to trailing edge). 

#         nupper, nlower = int(px), int(py)
#         upper = values[1:nupper+1]
#         lower = values[nupper+1:]
#         values = upper+lower
#         upper.reverse()
#         values = lower+upper
#     else:
#         # assume Selig's format

#         # Selig's format starts from the trailing edge of the airfoil,
#         # goes over the upper surface, then over the lower surface, to
#         # go back to the trailing edge.

#         pass # nothing to do

#     # remove values outside -0.001 ... 1.001
#     coordinates = [p for p in values if p[0]>-0.001 and p[0]<1.001]
#     xv, yv = zip(*coordinates)
#     return '\n'.join(comments), (xv, yv)



func interpolate[T](x, x1, x2 : float, y1, y2: T): T =
  if not (x1 <= x and x <= x2):
    #echo "x=", x, "[", x1, "; ", x2, "]"
    raise newException(ValueError, fmt"{x} not in interval {x1} .. {x2}. ")
  if x1 == x2:
    return y1
  let f = (x-x1)/(x2-x1)
  return y1+(y2-y1)*f  

func interpolate_airfoil*(t: float, foil: Airfoil): (float, float) =
  # Determines the intersection of the profile coordinates with x=t
  #
  # Returns a tuple (upper, lower).
  
  if t<0 or t>1:
     raise newException(ValueError, "{t} not in interval 0 .. 1. ")
  var upper = -1.0
  var lower = -1.0
  var ap = vec2(float(-1.0), float(-1.0))
  for i, p in enumerate(foil.points):
    let x = p.x
    let ax = ap.x
    if ax >= 0:
      if (ax<t and t<=x): 
        lower = interpolate(t, ax, x, ap.y, p.y)
      elif (x<t and t<=ax): 
        upper = interpolate(t, x, ax, p.y, ap.y)
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
    test "ag03":
      let f = load_airfoil("foils/ag03-il.dat")
      check(len(f.points) == 180)
      let (y1, y2) = interpolate_airfoil(0.1, f)
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
