import canvas
import foilmodel
import airfoil
import nigui
import pixie
import std/os
import std/strutils
# import std/unicode
import algorithm 

when isMainModule:
  import std/cmdline

  app.init()

  var window = newWindow()

  var p = newLayoutContainer(Layout_Vertical)
  window.add(p)
  p.widthMode = WidthMode_Fill
  p.heightMode = HeightMode_Expand

  var c = newCanvasCtrl()
  c.trafo = mat3(
      0.5, 0.0, 0.0,
      0.0, 0.5, 0.0,
      0.0, 0.0, 1.0
    )

  p.add(c)


  c.widthMode = WidthMode_Fill
  c.heightMode = HeightMode_Expand

  
  if paramCount() >= 1:
    let fn = commandLineParams()[0]
    c.bgimage = readImage(fn)

  # gtk_combo_box_text_new_with_entry
  var b = newComboBox()
  var options: seq[string] = @[]

  var i = -1
  for d in walkDir("foils", relative=false):
    i += 1
    if d.kind == pcFile:
      options.add(d.path)
  options.sort(system.cmp)
  
  b.options = options
  p.add(b)

  var b_set = newButton("Schieber einstellen")
  p.add(b_set)

  var b_search = newButton("Profil suchen")
  p.add(b_search)
  
  
  window.onKeyDown = proc(event: KeyboardEvent) =
    if event.key == Key_Plus:
      c.trafo = c.trafo*scale(vec2(1.1, 1.1))
      c.forceRedraw
    elif event.key == Key_Minus:
      const f = 1/1.1
      c.trafo = c.trafo*scale(vec2(f, f))
    elif event.key == Key_Left:
      c.trafo = c.trafo*translate(vec2(5, 0))
    elif event.key == Key_Right:
      c.trafo = c.trafo*translate(vec2(-5, 0))
    elif event.key == Key_Up:
      c.trafo = c.trafo*translate(vec2(0, 5))
    elif event.key == Key_Down:
      c.trafo = c.trafo*translate(vec2(0, -5))
    elif Key_Q.isDown() and Key_ControlL.isDown():
      app.quit()    
    c.forceRedraw

    
  var foil = newFoilFigure("devel/fx61168-il.dat")

  foil.pa = vec2(100, 400)
  foil.pb = vec2(500, 400)
  foil.alpha = 90
  foil.l = 100
  #foil.su0 = 0.1
  #foil2.pt = vec2(20, 0)
  c.figures.add(foil)

  b_set.onClick = proc(event: ClickEvent) =
    let (upper, lower) = foil.match_sliders(foil.airfoil)
    foil.upper_values = upper
    foil.lower_values = lower
    c.forceRedraw

  b_search.onClick = proc(event: ClickEvent) =
      var testfoil: Airfoil
      var best: Airfoil
      var best_penalty = -1.0
      var best_name: string
      var b: float
      var i = -1
      for d in walkDir("foils", relative=false):
        i += 1
        if d.kind == pcFile and d.path.toLowerAscii.endsWith(".dat"):
          #toLower.endswith(".dat"):
          try:
            testfoil = load_airfoil($d.path)
          except:
            echo "Kann nicht geladen werden", i, " ", d.path
            continue

          try:
            b = foil.badness(testfoil)
          except:
            echo "Kann nicht berechnet werden", i, " ", d.path
            continue
            
          if best_penalty<0 or b<best_penalty:
            best_penalty = b
            best_name = $d.path
            best = testfoil
      foil.airfoil = best
      c.forceRedraw()
      echo "Best: ", best_name, " ", best_penalty
    
    
  proc on_combo(event: ComboBoxChangeEvent) =
    var path = ComboBox(event.control).value
    foil.airfoil = load_airfoil(path)
    c.forceRedraw
  b.onChange = on_combo



  echo "Benutze +, -, left, right, up, down"

  window.show()
  app.run()
