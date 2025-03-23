import airfoil
import canvas
import vmath




type FoilModel* = ref object of Figure
  airfoil*: Airfoil
  mirror*: bool
  fill*: bool


method set_sliders*(figure: FoilModel) {.base.} =
  discard

method badness*(figure: FoilModel, airfoil: Airfoil): float {.base.} =
  99


# Spiegelt die X-Achse und Verschiebt sie um 1
let flipx* = scale(vec2(-1.0, 1.0))*translate(vec2(-1, 0))
# Spiegelt die Y-Achse und Verschiebt sie um 1
let flipy* = scale(vec2(1.0, -1.0))*translate(vec2(0, -1))
let mirrory* = scale(vec2(1.0, -1.0))



proc compute_trafo*(a0, b0, a1, b1: Vec2): Mat3 =
  # Erzeugt eine Transformation, die die Strecke a0b0 auf a1b1
  # abbildet und verwendet dabei Rotation Streckung und Verschieben.

  let d0 = b0-a0
  let d1 = b1-a1
  
  let f = d1.length/d0.length
  let beta = arctan2(d1.y, d1.x)-arctan2(d0.y, d0.x)

  # den Punkt a0 in den Ursprung schieben
  let b = translate(-a0) 

  # Um beta drehen    
  let r = rotate(-beta)

  # Skalieren
  let s = scale(vec2(f, f))

  # a0 auf a1 schieben
  let t = translate(a1)
  
  return t*s*r*b
