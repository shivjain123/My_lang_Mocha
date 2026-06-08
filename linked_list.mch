class Node {
    var value: int;
    var next: Node;

    function constructor(v: int) -> null {
        this.value = v;
        this.next = null;
    };
};

function main(didLoad) -> null {
    var n: Node = Node(42);
    print(n.value);
};