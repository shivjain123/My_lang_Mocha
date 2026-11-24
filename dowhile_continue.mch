function d_o(didLoad){
    var i: int = 0;
    do {
        i++;
        if (i < 5) { continue; };
    } while (i < 3);
    print(i);
};