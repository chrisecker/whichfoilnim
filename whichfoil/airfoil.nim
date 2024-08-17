import std/strutils
import std/strformat
import std/enumerate
import std/algorithm


const eps = 1.0e-7 ## Epsilon used for float comparisons.

proc `=~` *(x, y: float): bool =
  result = abs(x - y) < eps

type
  ParseError* = object of Exception

  point* = object
    x*: float
    y*: float

  airfoil* = object
    doc*: string
    points*: seq[point]

    
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
    parse_coord(l)    
  except:
    return false
  return true


  
proc load_airfoil*(f: File): airfoil =
  var doc: string
  var points: seq[point]

  # n Zeilen Kommentare. Ab der ersten Koordinate kein Kommentar mehr
  
  var l: string
  var i = 0
  while readline(f, l):
    i += 1
    if l.strip() == "":
      continue
    if is_coord(l): 
      let (x, y) = parse_coord(l)
      points.add(point(x: x, y: y))
    else:
      if len(points)>0:
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
    let lower = points[(nupper+1)..^0]
    points = lower & upper
  else:
    # assume Selig's format

    # Selig's format starts from the trailing edge of the airfoil,
    # goes over the upper surface, then over the lower surface, to
    # go back to the trailing edge.

    discard # nothing to do
    
      
  return airfoil(doc: doc, points: points)
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


func interpolate(x, x1, x2, y1, y2 :float): float =
  if not (x1 <= x and x <= x2):
    raise newException(ValueError, "{x} not in interval {x1} .. {x2}. ")
  return y1+(y2-y1)/(x2-x1)*(x-x1) 

func interpolate_airfoil(t: float, foil: airfoil): (float, float) =
  # Determines the intersection of the profile coordinates with x=t
  #
  # Returns a tuple (upper, lower).
  
  if t<0 or t>1:
     raise newException(ValueError, "{t} not in interval 0 .. 1. ")
  var upper = -1.0
  var lower = -1.0
  var ap = point(x:float(-1.0), y:float(-1.0)) # ohne float gibt es
                                               # Fehler: attempting to
                                               # call routine: 'point'
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
    test "load_airfoil":
      let f = load_airfoil(open("foils/ag03-il.dat"))
      check(len(f.points) == 180)
      let (y1, y2) = interpolate_airfoil(0.1, f)
      check(y1 =~ -0.0131572867921)
      check(y2 =~ 0.0406201664946)
      

