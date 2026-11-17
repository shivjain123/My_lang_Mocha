from "mocha-math" import round_even();

function main(didLoad){
    print(newLine=true);
    print("2.5: ", round_even(2.5), newLine=true);
    print("3.5: ", round_even(3.5), newLine=true);
    print("-2.5: ", round_even(-2.5), newLine=true);
    print("-3.5: ", round_even(-3.5), newLine=true);
    print("0.5: ", round_even(0.5), newLine=true);
    print("-0.5: ", round_even(-0.5), newLine=true);
    print("2.1: ", round_even(2.1), newLine=true);
    print("2.8: ", round_even(2.8), newLine=true);
    print("2.499999999: ", round_even(2.499999999), newLine=true);
    //print("3000000000.0: ", round_even(3000000000.0), newLine=true);
};