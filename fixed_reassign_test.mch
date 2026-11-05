class T {
    var f: float;
    function constructor() -> null { this.f = 0.1; };
    function a() -> null { this.f += 0.2; };
    function b() -> null { this.f = this.f + 0.2; };
};

function main(didLoad) -> null {
    var x: T = T();
    x.a();
    var y: T = T();
    y.b();
    var z: float = 0.1;
    z += 0.2;
    print(x.f == 0.3, " ", y.f == 0.3, " ", z == 0.3, "\n");
};