from "mocha-matvec" import *;

function test(didLoad) -> null {
    // Rotation matrix — eigenvalues are +i and -i
    var m: float[][] = [[0.0, -1.0], [1.0, 0.0]];
    var eigs: Complex[] = m.eigenvalues_qr();
    
    print("eig0: " + str(eigs[0].real) + " + " + str(eigs[0].imag) + "i", newLine=true);
    print("eig1: " + str(eigs[1].real) + " + " + str(eigs[1].imag) + "i", newLine=true);
    
    // 3x3 with known complex eigenvalues
    // [[0,-1,0],[1,0,0],[0,0,2]] 
    // eigenvalues: +i, -i, 2.0
    var m2: float[][] = [[0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 2.0]];
    var eigs2: Complex[] = m2.eigenvalues_qr();
    
    print("3x3 eig0: " + str(eigs2[0].real) + " + " + str(eigs2[0].imag) + "i", newLine=true);
    print("3x3 eig1: " + str(eigs2[1].real) + " + " + str(eigs2[1].imag) + "i", newLine=true);
    print("3x3 eig2: " + str(eigs2[2].real) + " + " + str(eigs2[2].imag) + "i", newLine=true);
};
//                            WORKS NOW