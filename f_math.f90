function f_square(x) bind(C, name="f_square")
    use iso_c_binding, only: c_int
    integer(c_int), value :: x
    integer(c_int) :: f_square
    f_square = x * x
end function f_square

function f_hello() bind(C, name="f_hello")
    use iso_c_binding, only: c_int
    integer(c_int) :: f_hello
    print *, "hello from fortran"
    f_hello = 7
end function f_hello