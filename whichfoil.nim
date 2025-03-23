import canvas
import foilmodel1
#import foilmodel2
import airfoil
import foilbrowser
import matchbrowser
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

  var airfoils = loadAirfoils("foils/")
  var window = newWindow()

  var p = newLayoutContainer(Layout_Horizontal)
  window.add(p)
  p.widthMode = WidthMode_Fill
  p.heightMode = HeightMode_Expand

  var ctrl = newCanvasCtrl()
  ctrl.fixedCurrent = true
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

  var l_airfoil = newLabel("xxxx")
  box.add(l_airfoil)
  
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

    
  var model = newFoilModel1()
  model.airfoil = load_airfoil("devel/fx61168-il.dat")

  model.pa = vec2(100, 400)
  model.pb = vec2(500, 400)
  model.alpha = 90
  model.l = 0.5
  model.set_sliders()
  model.fill = true
  ctrl.figures.add(model)
  
  #ctrl.onCurrentChanged = proc(ctrl: Canvas) =
  #  discard # echo "current changed"

  
  ctrl.onCurrentChanged = proc(control: CanvasCtrl) =
    echo "current"
    let current = control.current
    if current != nil:
      l_airfoil.text = FoilModel1(current).airfoil.path      
  ctrl.current = model


  b_choose.onClick = proc(event: ClickEvent) =
    var browser = newFoilBrowser("foils/") # XXX argument should be list of airfoils
    browser.listCtrl.onItemActivate = proc(control: ListCtrlBase, index: int) =
      model.airfoil = browser.listCtrl.items[index]
      l_airfoil.text = model.airfoil.path            
      ctrl.forceRedraw
    browser.window.show()
  
  b_set.onClick = proc(event: ClickEvent) =
    model.set_sliders()
    ctrl.forceRedraw

  b_search.onClick = proc(event: ClickEvent) =
    var matches: seq[(AirFoil, float)]
    var testfoil: Airfoil
    
    var b: float
    for foil in airfoils:
      try:
        b = model.badness(foil)
      except:
        echo "Kann nicht berechnet werden", foil.path
        continue

      matches.add((foil, b))

    proc myCmp(x, y: (AirFoil, float)): int =
      cmp(x[1], y[1])      
    matches.sort(myCmp)

    echo "Matches:"
    for i, (foil, b) in matches:
      let b2 = model.badness(foil)
      echo i, " ", round(b*100, 3), " ", foil.path, " ", b2
      if i>5:
        break


    var browser = newMatchBrowser(matches)
    browser.listCtrl.onItemActivate = proc(control: ListCtrlBase, index: int) =
      model.airfoil = browser.listCtrl.items[index][0]
      l_airfoil.text = model.airfoil.path            
      ctrl.forceRedraw
    
    browser.window.show()
    

  cb_fill.onToggle = proc(event: ToggleEvent) =
    model.fill = not model.fill
    ctrl.forceRedraw
  cb_fill.checked = model.fill
    
  cb_mirror.onToggle = proc(event: ToggleEvent) =
    model.mirror = not model.mirror
    echo "setze mirror auf ", model.mirror
    ctrl.forceRedraw

  var b_badness = newButton("Profil bewerten")
  box.add(b_badness)
  b_badness.onClick = proc(event: ClickEvent) =
    let b= badness_debug(model, model.airfoil)
    
    
  window.show()
  app.run()
