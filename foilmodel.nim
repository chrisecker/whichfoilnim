import airfoil
import canvas




type FoilModel* = ref object of Figure
  airfoil*: Airfoil
  mirror*: bool
  fill*: bool


method match_sliders*(figure: FoilModel, airfoil: Airfoil): (seq[float], seq[float]) {.base.} =
  return (@[], @[])
  
method set_sliders*(figure: FoilModel) {.base.} =
  discard

method badness*(figure: FoilModel, airfoil: Airfoil): float {.base.} =
  99
