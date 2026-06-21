from "mocha-ink" import *;
from "mocha-meteoro" import *;

function didMount(didLoad){
    var pressure:   float[] = [1000.0, 925.0, 850.0, 700.0, 500.0, 300.0, 200.0];
    var temp:       float[] = [28.0,   22.0,  16.0,   4.0, -12.0, -40.0, -56.0];
    var dewpoint:   float[] = [22.0,   18.0,  10.0,  -2.0, -20.0, -50.0, -65.0];
    var wind_speed: float[] = [15.0,   20.0,  35.0,  55.0,  80.0, 120.0, 100.0];
    var wind_dir:   float[] = [180.0, 200.0, 220.0, 250.0, 270.0, 280.0, 290.0];

    var st: SkewTPlot = skewt(pressure, temp, dewpoint, wind_speed, wind_dir);
    st.title("Bhopal Sounding — 00Z");
    st.show_mixing_ratios();
    st.save("sounding.svg");
    print("Saved", newLine=true);
};