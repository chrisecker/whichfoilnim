import airfoil
import json
import streams

    
type
  ViewBase* = ref object of RootObj
  Document* = ref object of RootObj
    pp1, pp2: point
    views*: seq[ViewBase]

proc save*(m: Document, path: string) =
  # TODO:
  # "views" nicht schreiben
  # "p1" statt "pp1"  
  writeFile(path, pretty(%m))

proc load*(path: string): Document =
  let s = readFile(path)
  let jsonObject = parseJson(s)
  to(jsonObject, Document)
  
method p1_changed*(v: ViewBase, m: Document, old: point, value: point) =
  echo "p1 changed", old, "->", value

method p2_changed*(v: ViewBase, m: Document, old: point, value: point) =
  echo "p2 changed", old, "->", value

proc `p1=`*(m: var Document, value: point) {.inline.} =
  let old = m.pp1
  m.pp1 = value
  for v in m.views:
    v.p1_changed(m, old, value)

proc p1*(m: Document): point {.inline.} =
  m.pp1
  
proc `p2=`*(m: var Document, value: point) {.inline.} =
  let old = m.pp2
  m.pp2 = value
  for v in m.views:
    v.p2_changed(m, old, value)

proc p2*(m: Document): point {.inline.} =
  m.pp2
    
when isMainModule:
  import unittest
  
  suite "testing model.nim":
    test "set p1":
      var m = Document()
      let v = ViewBase()
      m.views &= v
      m.p1 = point(x:1.0, y:1.1)
      m.p2 = point(x:1.0, y:1.1)
    test "save":
      var m = Document()
      m.p1 = point(x:1.0, y:1.1)
      m.p2 = point(x:2.0, y:2.1)
      m.save("tmp.json")
      var clone = load("tmp.json")
      check(clone.p1 == m.p1)
      check(clone.p2 == m.p2)
        
      

