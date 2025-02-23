import canvas
import foilmodel
import nigui
import pixie


when isMainModule:

  app.init()

  var window = newWindow()
  var c = newCanvasCtrl()
  c.trafo = mat3(
      0.5, 0.0, 0.0,
      0.0, 0.5, 0.0,
      0.0, 0.0, 1.0
    )


  c.widthMode = WidthMode_Fill
  c.heightMode = HeightMode_Expand
  window.add(c)


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

    
  var foil = newFoilFigure(open("devel/fx61168-il.dat"))

  foil.pa = vec2(100, 400)
  foil.pb = vec2(500, 400)
  foil.alpha = 90
  foil.l = 100
  foil.su0 = 0.1
  #foil2.pt = vec2(20, 0)
  c.figures.add(foil)


  echo "Benutze +, -, left, right, up, down"

  window.show()
  app.run()
