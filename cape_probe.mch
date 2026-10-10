from "mocha-meteoro" import *;

function main(didLoad) -> null {
    print("LCL pressure 28/18:", newLine=true);
    print(lcl_pressure(28.0, 18.0, 890.0), newLine=true);
    print("LCL pressure 28/28:", newLine=true);
    print(lcl_pressure(28.0, 28.0, 890.0), newLine=true);
    print("theta_e 28/18:", newLine=true);
    print(equiv_potential_temp(28.0, 18.0, 890.0), newLine=true);
    print("theta_e 28/28:", newLine=true);
    print(equiv_potential_temp(28.0, 28.0, 890.0), newLine=true);
};