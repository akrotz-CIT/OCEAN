subroutine OCEAN_get_rho( xmesh, celvol, rho, ierr )
  use AI_kinds
  use OCEAN_mpi
  use iso_c_binding
  implicit none

  include 'fftw3.f03'

  integer, intent( in ) :: xmesh( 3 )
  real(dp), intent( in ) :: celvol
  real(dp), intent( out ) :: rho( xmesh(3), xmesh(2), xmesh(1) )
  integer, intent( inout ) :: ierr

  !
  integer :: nfft( 3 ), dumint, i, j, k, ii, jj, kk
  complex(dp),  allocatable :: rhoofr(:,:,:), rhoofg(:,:,:)
  real(dp) :: dumr, sumrho, norm
  integer*8 :: fftw_plan, fftw_plan2
  integer :: igl(3), igh(3), powlist(3), mul(3), c_nfft(3), iter, offset(3)
  character*1 :: fstr

  integer, parameter :: fac(3) = (/ 2, 3, 5 /)
  integer, parameter :: hicap(3) = (/ 20, 8, 4 /)
  integer, parameter :: nfac = 3

  integer, external :: optim


#ifdef CONTIGUOUS
    CONTIGUOUS :: rhoofr, rhoofg
#endif
#ifdef __INTEL
!dir$ attributes align:64 :: rhoofr, rhoofg
#endif




! Lazy start, only MPI master node does work
  if( myid .eq. root ) then
    open( unit=99, file='nfft', form='formatted', status='old', IOSTAT=ierr )
    if ( ierr .ne. 0 ) goto 111
    read( 99, * ) nfft( : )
    close( 99 )

    allocate( rhoofr( nfft(1), nfft(2), nfft(3) ) )
    call dfftw_plan_dft_3d( fftw_plan, nfft(1), nfft(2), nfft(3), rhoofr, rhoofr, &
            FFTW_FORWARD, FFTW_ESTIMATE )
    rhoofr = 0.0_dp


    sumrho = 0.0_dp
    open( unit=99, file='rhoofr', form='formatted', status='old', IOSTAT=ierr )
    if ( ierr .ne. 0 ) goto 111
    read( 99, * ) fstr
    do k = 1, nfft( 3 )
      do j = 1, nfft( 2 )
        do i = 1, nfft( 1 )
          read( 99, * ) dumint, dumint, dumint, dumr
          sumrho = sumrho + dumr
          rhoofr( i, j, k ) = dumr 
        enddo
      enddo
    enddo
    close( 99 )

    sumrho = sumrho / dble(product( nfft )) * celvol
    write(6,*) '!', sumrho
    write(6,*) '!', minval( real( rhoofr ) )
    !
    call dfftw_execute_dft( fftw_plan, rhoofr, rhoofr )
    call dfftw_destroy_plan( fftw_plan )
    !
    write( 6, * ) dble(rhoofr( 1, 1, 1 ) ) / dble(product( nfft ))  * celvol , &
          anint( dble(rhoofr( 1, 1, 1 ) ) / dble( product( nfft ) ) * celvol )
    ! need to find compatible grids
    do iter = 1, 3
      call facpowfind( xmesh( iter ), nfac, fac, powlist )
      c_nfft( iter ) = optim( nfft( iter ), nfac, fac, powlist, hicap )
      if( mod( c_nfft( iter ), xmesh( iter ) ) .ne. 0 ) then
        write(6,*) 'you are doing something wrong'
        ierr = 14
        goto 111
      endif
    enddo


    allocate( rhoofg( c_nfft( 1 ), c_nfft( 2 ), c_nfft( 3 ) ), STAT=ierr )
    if( ierr .ne. 0 ) goto 111
    call  dfftw_plan_dft_3d( fftw_plan2, c_nfft(1), c_nfft(2), c_nfft(3), rhoofg, rhoofg, &
            FFTW_BACKWARD, FFTW_ESTIMATE )
    rhoofg = 0.d0
    mul( : ) = c_nfft( : ) / nfft( : )
    write(6,*) c_nfft( : )
    write(6,*) nfft( : )
    write(6,*) xmesh( : )
    offset( : ) = c_nfft( : ) - nfft( : )
    write(6,*) offset( : )
    write(6,*) '-----------'
    do k = 1, nfft( 3 ) !/ 2 
      if( k .le. nfft(3)/2 ) then !floor( dble(nfft( 3 )) / 2.0 ) + 1) then
        kk = k
      else
        kk = k + offset( 3 )
      endif
      do j = 1, nfft( 2 ) !/ 2
        if( j .le. nfft(2)/2) then !floor( dble(nfft( 2 ) ) / 2.0) + 1 ) then
          jj = j
        else
          jj  = j + offset( 2 )
        endif
        do i = 1, nfft( 1 ) !/ 2
          if( i .le. nfft(1)/2) then !floor(dble(nfft( 1 ) ) / 2.0) + 1 ) then
            ii = i
          else
            ii = i + offset( 1 )
          endif
          rhoofg( ii, jj, kk ) = rhoofr( i, j, k )
        enddo
      enddo
    enddo
    call dfftw_execute_dft( fftw_plan2, rhoofg, rhoofg )
    call dfftw_destroy_plan( fftw_plan2 )
    !
    norm = dble( product( nfft ) )
    norm = 1.0d0 / norm
    mul( : ) = c_nfft( : ) / xmesh( : )
    write(6,*) mul( : )
    do i = 0, xmesh( 1 ) - 1
      do j = 0, xmesh( 2 ) - 1
        do k = 0, xmesh( 3 ) - 1
          rho( k+1, j+1, i+1 ) = norm * rhoofg( i*mul(1)+1, j*mul(2)+1, k*mul(3)+1 )
          if( rho( k+1, j+1, i+1 ) .le. 0.0d0 ) then
            write(6,*) 'low density', rho( k+1, j+1, i+1 ), k+1, j+1, i+1, rhoofg( i*mul(1)+1, j*mul(2)+1, k*mul(3)+1 )
            if( rho( k+1, j+1, i+1 ) .gt. -1.0d-12 ) then
              rho( k+1, j+1, i+1 ) = 0.d0
            else
              write(6,*) 'Negative density found!', rho( k+1, j+1, i+1 ), k+1, j+1, i+1
              ierr = 11
              goto 111
            endif
          endif
        enddo
      enddo
    enddo

    open( unit=99, file='rho.xpts', form='formatted', status='unknown')
    rewind( 99 )
    sumrho = 0.d0
    do k = 1, xmesh( 3 )
      do j = 1, xmesh( 2 )
        do i = 1, xmesh( 1 )
          write(99,*) i, j, k, rho(k,j,i)
          sumrho = sumrho +  rho(k,j,i)
        enddo
      enddo
    enddo
    close( 99 )
    sumrho = sumrho / dble(product(xmesh)) * celvol
    write(6,*) '!', sumrho
    !
111 continue
    if( allocated( rhoofr ) ) deallocate( rhoofr )
    if( allocated( rhoofg ) ) deallocate( rhoofg )
  endif


#ifdef MPI
  call MPI_BCAST( ierr, 1, MPI_INTEGER, root, comm, ierr )
  if( ierr .ne. 0 ) return
  call MPI_BCAST( rho, product(xmesh), MPI_DOUBLE_PRECISION, root, comm, ierr )
#endif

end subroutine OCEAN_get_rho
