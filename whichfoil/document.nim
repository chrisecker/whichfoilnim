import airfoil
import json
import nigui

    
type
  ViewBase* = ref object of ControlImpl


type
  Document* = ref object of RootObj
    pp1, pp2: point
    views*: seq[ViewBase]

method p1_changed*(v: ViewBase, m: Document, old: point, value: point) {.base.} =
  discard

method p2_changed*(v: ViewBase, m: Document, old: point, value: point) {.base.} =
  discard
    
proc save*(m: Document, path: string) =
  let j = %[("p1", %m.pp1), ("p2", %m.pp2)]
  writeFile(path, pretty(%j))

proc load*(path: string): Document =
  let s = readFile(path)
  let j = parseJson(s)
  Document(
    pp1:to(j["p1"], point),
    pp2:to(j["p2"], point))
  #to(jsonObject, Document)
  

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
        
      

