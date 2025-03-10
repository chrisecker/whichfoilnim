import canvas
import foilmodel1
import airfoil
import foilbrowser
import listctrl
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

  var p = newLayoutContainer(Layout_Horizontal)
  window.add(p)
  p.widthMode = WidthMode_Fill
  p.heightMode = HeightMode_Expand

  var ctrl = newCanvasCtrl()
  ctrl.trafo = mat3(
      0.5, 0.0, 0.0,
      0.0, 0.5, 0.0,
      0.0, 0.0, 1.0
    )
  ctrl.widthMode = WidthMode_Expand
  ctrl.heightMode = HeightMode_Expand
  p.add(ctrl)

  var box = newLayoutContainer(Layout_Vertical)
  p.add(box)
  box.widthMode = WidthMode_Auto
  box.heightMode = HeightMode_Expand
  
  
  if paramCount() >= 1:
    let fn = commandLineParams()[0]
    ctrl.bgimage = readImage(fn)

  var b_choose = newButton("Profil auswählen")
  box.add(b_choose)
    
  var cb_mirror = newCheckbox("Profil spiegeln")
  box.add(cb_mirror)

  var cb_fill = newCheckbox("Profil zeichnen")
  box.add(cb_fill)
  
  var b_set = newButton("Schieber einstellen")
  box.add(b_set)

  var b_search = newButton("Profil suchen")
  box.add(b_search)


  window.onKeyDown = proc(event: KeyboardEvent) =
    if event.key == Key_Plus:
      ctrl.trafo = ctrl.trafo*scale(vec2(1.1, 1.1))
      ctrl.forceRedraw
    elif event.key == Key_Minus:
      const f = 1/1.1
      ctrl.trafo = ctrl.trafo*scale(vec2(f, f))
    elif event.key == Key_Left:
      ctrl.trafo = ctrl.trafo*translate(vec2(5, 0))
    elif event.key == Key_Right:
      ctrl.trafo = ctrl.trafo*translate(vec2(-5, 0))
    elif event.key == Key_Up:
      ctrl.trafo = ctrl.trafo*translate(vec2(0, 5))
    elif event.key == Key_Down:
      ctrl.trafo = ctrl.trafo*translate(vec2(0, -5))
    elif Key_Q.isDown() and Key_ControlL.isDown():
      app.quit()    
    ctrl.forceRedraw

    
  var model = newFoilModel1("devel/fx61168-il.dat")

  model.pa = vec2(100, 400)
  model.pb = vec2(500, 400)
  model.alpha = 90
  model.l = 100
  model.set_sliders()
  model.fill = true
  ctrl.figures.add(model)

  b_choose.onClick = proc(event: ClickEvent) =
    var browser = newFoilBrowser("foils/")
    browser.listCtrl.onItemActivate = proc(control: ListCtrlBase, index: int) =
      model.airfoil = browser.listCtrl.items[index]
      ctrl.forceRedraw
    browser.window.show()
  
  b_set.onClick = proc(event: ClickEvent) =
    model.set_sliders()
    ctrl.forceRedraw

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
            b = model.badness(testfoil)
          except:
            echo "Kann nicht berechnet werden", i, " ", d.path
            continue
            
          if best_penalty<0 or b<best_penalty:
            best_penalty = b
            best_name = $d.path
            best = testfoil
      model.airfoil = best
      ctrl.forceRedraw()
      echo "Best: ", best_name, " ", best_penalty

  cb_fill.onToggle = proc(event: ToggleEvent) =
    model.fill = not model.fill
    ctrl.forceRedraw
  cb_fill.checked = model.fill
    
  cb_mirror.onToggle = proc(event: ToggleEvent) =
    model.mirror = not model.mirror
    echo "setze mirror auf ", model.mirror
    ctrl.forceRedraw
    
  window.show()
  app.run()
