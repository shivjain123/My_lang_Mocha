extend Complex{
    function addition (b: int) -> int {var a: int = 2; return a+b;};
};
function ext(didLoad){
    var d: Complex = 4+5im;
    print(d.addition(3), newLine=true);
};