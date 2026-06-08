function main(didLoad){
    for (var i: int = 0; i < 10; i++) {
        if (i == 5) { continue; };
        // i never increments past 5 → infinite loop 💀
    };
};