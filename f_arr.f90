function f_dot(x, y, n) bind(C, name="f_dot")
    use iso_c_binding, only: c_double, c_int
    real(c_double), intent(in) :: x(*), y(*)
    integer(c_int), value :: n
    real(c_double) :: f_dot
    integer :: i
    f_dot = 0.0_c_double
    do i = 1, n
        f_dot = f_dot + x(i) * y(i)
    end do
end function f_dot

subroutine f_scale(p, n, k) bind(C, name="f_scale")
    use iso_c_binding, only: c_double, c_int
    real(c_double), intent(inout) :: p(*)
    integer(c_int), value :: n
    real(c_double), value :: k
    integer :: i
    do i = 1, n
        p(i) = p(i) * k
    end do
end subroutine f_scale