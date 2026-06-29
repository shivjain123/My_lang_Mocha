"""function test(didLoad) -> null {

    // Test 1: basic try/rescue with binding
    try {
        fail "something went wrong";
    } rescue, e {
        print("Caught: ".format("$0".format(e)), newLine=true);
    };

    // Test 2: rescue without binding
    try {
        fail "ignored message";
    } rescue {
        print("caught without binding", newLine=true);
    };

    // Test 3: no exception — rescue not entered
    try {
        print("no fail here", newLine=true);
    } rescue, e {
        print("should not print", newLine=true);
    };

    // Test 4: nested try/rescue
    try {
        try {
            fail "inner fail";
        } rescue, e {
            print("inner caught: $0".format(e), newLine=true);
            fail "rethrown from inner";
        };
    } rescue, e {
        print("outer caught: $0".format(e), newLine=true);
    };

    // Test 5: unhandled — should print runtime error and exit
    // uncomment to test:
    // fail "unhandled!";

};"""

function test(didLoad) -> null {
    print("before try", newLine=true);
    try {
        print("inside try", newLine=true);
        fail "test error";
        print("after fail", newLine=true);
    } rescue, e {
        print("inside rescue", newLine=true); //Until here and even this prints.
        //but gets stuck and does not exit rescue
    };
    print("after try", newLine=true); //This never prints
};