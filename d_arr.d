extern(C) double d_sum(const(double)* p, int n) {
    double s = 0;
    foreach (i; 0 .. n) s += p[i];
    return s;
}

extern(C) void d_double_all(double* p, int n) {
    foreach (i; 0 .. n) p[i] *= 2;
}