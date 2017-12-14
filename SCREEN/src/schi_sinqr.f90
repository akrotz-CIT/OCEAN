! Copyright (C) 2017 OCEAN collaboration
!
! This file is part of the OCEAN project and distributed under the terms 
! of the University of Illinois/NCSA Open Source License. See the file 
! `License' in the root directory of the present distribution.
!
!
! John Vinson
module schi_sinqr
  use ai_kinds, only : DP

  implicit none
  private
  save

  public :: schi_sinqr_printSite
  public :: schi_sinqr_buildCoulombMatrix
  public :: schi_sinqr_project
  public :: schi_sinqr_calcW

  contains

  subroutine schi_sinqr_calcW( grid, Pot, FullChi, FullW, ierr )
    use ocean_constants, only : PI_DP
    use screen_grid, only : sgrid
    use screen_centralPotential, only : potential
    type( sgrid ), intent( in ) :: grid
    type( potential ), intent( in ) :: Pot
    real(DP), intent( in ) :: FullChi(:,:,:,:)
    real(DP), intent( out ) :: FullW(:,:)
    integer, intent( inout ) :: ierr

    real(DP), allocatable :: vipt( : ), basfcn(:,:), qtab(:), rhs(:), potfcn(: ,: )
    real(DP) :: q, pref, arg, su, coul, cterm
    integer :: i, j ,ii
    integer :: nbasis, npt, nr

    nbasis = size( FullChi, 1 ) 
    npt = grid%npt
    nr = grid%nr

    write(6,*) 'mkvipt'
    allocate( vipt( npt ), basfcn( npt, nbasis ), qtab( nbasis ), rhs( nbasis ), potfcn( npt, nbasis ) )
    call Newmkvipt( npt, grid%drel, pot%rad, pot%pot, vipt )

    write(6,*) 'basis'
    do i = 1, nbasis
      q = PI_DP * real( i, DP ) / grid%rmax
      pref = 2.0_DP * PI_DP * grid%rmax / q**2
      pref = 1.0_DP / sqrt( pref )
      qtab( i ) = q
      coul = 4.0_DP * PI_DP / q**2
      cterm = cos( q * grid%rmax )

      do j = 1, npt
        arg = q * grid%drel( j )
        if( arg .gt. 0.0002_DP ) then
          basfcn( j, i ) = grid%wpt(j) * pref * sin( arg ) / arg
          potfcn( j, i ) = pref * coul * ( sin( arg ) / arg - cterm )
        else
          basfcn( j, i ) = grid%wpt(j) * pref * (1.0_DP - arg**2/4.0_DP )
          potfcn( j, i ) = pref * coul * ( 1.0_DP - arg**2/4.0_DP - cterm )
        endif
      enddo
!      do j = 1, nr
!        arg = q * grid%rad( j )
!        if( arg .gt. 0.0002_DP ) then
!          potfcn( j, i ) = pref * coul * ( sin( arg ) / arg - cterm )
!        else
!          potfcn( j, i ) = pref * coul * ( 1.0_DP - arg**2/4.0_DP - cterm )
!        endif
!      enddo
    enddo

    do i = 1, nbasis
       su = 0
       do ii = 1, npt
          su = su + basfcn( ii, i ) * vipt( ii ) !* grid%wpt( ii )
       end do
       rhs( i ) = su
       write(6,'(1i5,2(1x,1e15.8))' ) i, qtab( i ), rhs( i )
    end do



    ! If this is done correctly with the first dimension of FullW being NR not NPT
    ! then we want to average over all angles for a given radius which also means
    ! we need to bring back in the weights which are neglect (wpt)
    open(unit=98, file='xifull', form='formatted', status='unknown' )

    FullW(:,:) = 0.0_DP
    do i = 1, nbasis
      su = 0.0_dp
      do j = 1, nbasis
        su = su + FullChi( i, 1, j, 1 ) * rhs( j )
        write(98, '(2i5,3(1x,1e15.8))' ) i, j, qtab( i ), qtab( j ), FullChi( i, 1, j, 1 )
      enddo

      do ii = 1, npt
        FullW( ii, 1 ) = FullW( ii, 1 ) + su * potfcn( ii, i )
      enddo
      write(98,*)
    enddo
    close ( 98 )

    deallocate( vipt, basfcn, qtab, rhs, potfcn )

  end subroutine


  subroutine schi_sinqr_project( grid, FullSpace, ProjectedSpace, ierr )
    use screen_grid, only : sgrid
    use ocean_constants, only : PI_DP
    use ocean_mpi, only : myid
    type( sgrid ), intent( in ) :: grid
    real(DP), intent( in ) :: FullSpace(:,:)
    real(DP), intent( out ) :: ProjectedSpace(:,:,:,:)
    integer, intent( inout ) :: ierr

    real(DP), allocatable :: basfcn( :, :, : ), temp( : , : ), qtab( : )
    real(DP) :: pref, q, arg
    integer :: i, j, iLM, jLM
    integer :: npt, nbasis, nLM, fullSize

    real(DP), parameter :: d_zero = 0.0_DP
    real(DP), parameter :: d_one = 1.0_DP

    npt = size( FullSpace, 1 )
    nbasis = size( ProjectedSpace, 1 )
    nLM = size( ProjectedSpace, 2 )
    fullSize = nbasis * nLM

    if( ( npt .ne. size( FullSpace, 2 ) ) .or. ( npt .ne. grid%npt ) ) then
      write(myid+1000,'(A,3(I10))') 'schi_project_sinqr', npt, size( FullSpace, 2 ), grid%npt
      ierr = 1
      return
    endif

    if( nbasis .ne. size( ProjectedSpace, 3 ) ) then
      write(myid+1000,'(A,2(I10))') 'schi_project_sinqr', nbasis, size( ProjectedSpace, 3 )
      ierr = 2
      return
    endif

    if( nLM .ne. size( ProjectedSpace, 4 ) ) then
      write(myid+1000,'(A,2(I10))') 'schi_project_sinqr', nLM, size( ProjectedSpace, 4 )
      ierr = 3
      return
    endif


    allocate( basfcn( npt, nbasis, nLM ), qtab( nbasis ) )
    !> At the moment we only do l = 0 for sinqr
    do ilm = 2, nLM
      basfcn( :, :, ilm ) = 0.0_DP
    enddo
    do i = 1, nbasis
      q = PI_DP * real( i, DP ) / grid%rmax
      pref = 2.0_DP * PI_DP * grid%rmax / q**2
      pref = 1.0_DP / sqrt( pref )
      qtab( i ) = q

      do j = 1, npt
        arg = q * grid%drel( j )
        if( arg .gt. 0.0002_DP ) then
          basfcn( j, i, 1 ) = grid%wpt(j) * pref * sin( arg ) / arg
        else
          basfcn( j, i, 1 ) = grid%wpt(j) * pref * (1.0_DP - arg**2/4.0_DP )
        endif
      enddo
    enddo

    allocate( temp( npt, nbasis ), stat=ierr )
    if( ierr .ne. 0 ) return

    call DGEMM( 'N', 'N', npt, fullSize, npt, d_One, FullSpace, npt, basfcn, npt, &
                  d_Zero, temp, npt )

    call DGEMM( 'T', 'N', fullSize, fullSize, npt, d_One, basfcn, npt, temp, npt, &
              d_Zero, ProjectedSpace, nbasis )

    deallocate( temp )
    deallocate( basfcn )
#ifdef DEBUG
    open ( unit=99, file='xibb', form='formatted', status='unknown' )
    rewind 99
    do i = 1, nbasis
      do j = 1, nbasis
        write ( 99, '(2i5,3(1x,1e15.8))' ) i, j, qtab( i ), qtab( j ), ProjectedSpace( i, 1, j, 1 )
      end do
      write ( 99, * )
    end do
    close( unit=99 )
#endif


  end subroutine schi_sinqr_project




  subroutine schi_sinqr_buildCoulombMatrix( grid, cMat, ierr )
    use screen_grid, only : sgrid
    use ocean_constants, only : PI_DP
    use ocean_mpi, only : myid
    type( sgrid ), intent( in ) :: grid
    real(DP), intent( out ) :: cMat(:,:,:,:)
    integer, intent( inout ) :: ierr

    real(DP), allocatable :: qtab( : ), cosQtab( : )
    real(DP) :: eightPi
    integer :: i, j, nbasis, nLM

    nbasis = size( cMat, 1 )
    nLM = size( cMat, 2 )

    if( nbasis .ne. size( cMat, 3 ) ) then
      write(myid+1000,'(A,2(I10))') 'schi_sinqr_buildCoulombMatrix', nbasis, size( cMat, 3 )
      ierr = 2
      return
    endif

    if( nLM .ne. size( cMat, 4 ) ) then
      write(myid+1000,'(A,2(I10))') 'schi_sinqr_buildCoulombMatrix', nLM, size( cMat, 4 )
      ierr = 3
      return
    endif

    allocate( qtab( nbasis ), cosQtab( nbasis ) )
    do i = 1, nbasis
      qtab( i ) = PI_DP * real( i, DP ) / grid%rmax
      cosQtab( i ) = cos( real( i, DP ) * PI_DP )
    enddo

    cMat = 0.0_DP
    eightPi = 8.0_DP * PI_DP

    do j = 1, nbasis
      do i = 1, nbasis
        cMat( i, 1, j, 1 ) = eightPi * cosQtab( i ) * cosQtab( j ) / ( qtab( i ) * qtab( j ) )
      enddo
      cMat( j, 1, j, 1 ) = cMat( j, 1, j, 1 ) + 4.0_DP * PI_DP / ( qtab( j ) ** 2 )
    enddo

    deallocate( qtab, cosQtab )

  end subroutine schi_sinqr_buildCoulombMatrix


  subroutine schi_sinqr_printSite( grid, FullChi, ierr )
    use screen_grid, only : sgrid
    use ocean_constants, only : PI_DP
    type( sgrid ), intent( in ) :: grid
    real(DP), intent( in ) :: FullChi(:,:,:,:)
    integer, intent( inout ) :: ierr

    real(DP), allocatable :: vipt( : ), basfcn(:,:), qtab(:), rhs(:)
    real(DP) :: q, pref, arg, su
    integer :: i, j ,ii
    integer :: nbasis, npt, nr

    nbasis = size( FullChi, 1 )
    npt = grid%npt
    nr = grid%nr

    write(6,*) 'mkvipt'
    allocate( vipt( npt ), basfcn( npt, nbasis ), qtab( nbasis ), rhs( nbasis ) )
    call mkvipt( npt, grid%drel, vipt )

    write(6,*) 'basis'
    do i = 1, nbasis
      q = PI_DP * real( i, DP ) / grid%rmax
      pref = 2.0_DP * PI_DP * grid%rmax / q**2
      pref = 1.0_DP / sqrt( pref )
      qtab( i ) = q

      do j = 1, npt
        arg = q * grid%drel( j )
        if( arg .gt. 0.0002_DP ) then
          basfcn( j, i ) = grid%wpt(j) * pref * sin( arg ) / arg
        else
          basfcn( j, i ) = grid%wpt(j) * pref * (1.0_DP - arg**2/4.0_DP )
        endif
      enddo
    enddo

    write(6,*) 'rhs'
    open( unit=99, file='rhs', form='formatted', status='unknown' )
    rewind 99
    do i = 1, nbasis
       su = 0
       do ii = 1, npt
          su = su + basfcn( ii, i ) * vipt( ii ) !* grid%wpt( ii )
       end do
       rhs( i ) = su
       write ( 99, '(1i5,2(1x,1e15.8))' ) i, qtab( i ), rhs( i )
    end do
    close( unit=99 )



!    open(unit=99, file='xifull', form='formatted', 

    deallocate( vipt, basfcn, qtab )

  end subroutine schi_sinqr_printSite

  subroutine Newmkvipt( npt, drel, rtab, vtab, vipt )
    implicit none
    !
    integer, intent( in ) :: npt
    real(DP), intent( in ) :: drel( npt )
    real(DP), intent( in ) :: rtab( : ), vtab( : )
    real(DP), intent( out ) :: vipt( npt )
    !
    integer :: i, nrtab
    !
    nrtab = size( vtab )
    do i = 1, npt
       call intval( nrtab, rtab, vtab, drel( i ), vipt( i ), 'cap', 'cap' )
    end do
    !
    return
  end subroutine Newmkvipt


  subroutine mkvipt( npt, drel, vipt )
    implicit none
    !
    integer :: npt
    real(DP) :: drel( npt ), vipt( npt )
    !
    integer :: i, nrtab
    real(DP), allocatable :: rtab( : ), vtab( : )
    !
    open( unit=99, file='vpert', form='formatted', status='unknown' )
    rewind 99
    read ( 99, * ) nrtab
    allocate( rtab( nrtab ), vtab( nrtab ) )
    do i = 1, nrtab
       read ( 99, * ) rtab( i ), vtab( i )
    end do
    close( unit=99 )
    do i = 1, npt
       call intval( nrtab, rtab, vtab, drel( i ), vipt( i ), 'cap', 'cap' )
    end do
    deallocate( rtab, vtab )
    !
    return
  end subroutine mkvipt

  subroutine intval( n, xtab, ytab, x, y, lopt, hopt )
    implicit none
    !
    integer, intent( in ) :: n
    real(DP), intent( in) :: xtab( n ), ytab( n ), x
    real(DP), intent( out ) :: y
    character(len=3), intent( in ) :: lopt, hopt
    !
    integer :: ii, il, ih
    real(DP) :: rat
    logical :: below, above, interp
    !
    below = ( x .lt. xtab( 1 ) )
    above = ( x .gt. xtab( n ) )
    if ( below .or. above ) then
       interp = .false.
       if ( below ) then
          select case( lopt )
          case( 'ext' )
             ii = 1
             interp = .true.
          case( 'cap' )
             y = ytab( 1 )
          case( 'err' )
             stop 'error ... we are below!'
          end select
       else
          select case( hopt )
          case( 'ext' )
             ii = n - 1
             interp = .true.
          case( 'cap' )
             y = ytab( n )
          case( 'err' )
             stop 'error ... we are above!'
          end select
       end if
    else
       interp = .true.
       il = 1
       ih = n - 1
       do while ( il + 3 .lt. ih )
          ii = ( il + ih ) / 2
          if ( xtab( ii ) .gt. x ) then
             ih = ii - 1
          else
             il = ii
          end if
       end do
       ii = il
       do while ( xtab( ii + 1 ) .lt. x )
          ii = ii + 1
       end do
    end if
    if ( interp ) then
       rat = ( x - xtab( ii ) ) / ( xtab( ii + 1 ) - xtab( ii ) )
       y = ytab( ii ) + rat * ( ytab( ii + 1 ) - ytab( ii ) )
    end if
    !
    return
  end subroutine intval


end module schi_sinqr
