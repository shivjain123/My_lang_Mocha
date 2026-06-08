from "mocha-ink" import *;
from "mocha-math" import *;

function fresnel_c(t: float) -> float {
    return integral(lambda (x: float) -> float: (x * x).cos(RAD), 0.0, t);
};

function fresnel_s(t: float) -> float {
    return integral(lambda (x: float) -> float: (x * x).sin(RAD), 0.0, t);
};

function euler_spiral_points(t_max: float, steps: int) -> (float[], 2) {
    var xs: float[] = [];
    var ys: float[] = [];
    var dt: float = t_max / float(steps);
    var t: float = 0.0;
    
    while (t <= t_max) {
        xs.push(fresnel_c(t));
        ys.push(fresnel_s(t));
        t = t + dt;
    };
    return (xs, ys);
};

function main(didLoad) -> null {
    print("Computing Euler Spiral...", newLine=true);
    
    var points: (float[], 2) = euler_spiral_points(5.0, 500);
    var xs: float[] = points#0;
    var ys: float[] = points#1;
    
    var p: LinePlot = line(xs, ys);
    p.title("Euler Spiral (Cornu Spiral)");
    p.xlabel("x = ∫ cos(t²) dt");
    p.ylabel("y = ∫ sin(t²) dt");
    p.color("blue");
    p.grid(true);
    p.save("euler_spiral.svg");
    
    print("euler_spiral.svg saved", newLine=true);
    print("The ends never meet — just like my feature list.", newLine=true);
};