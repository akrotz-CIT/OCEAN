! Copyright (C) 2013 OCEAN collaboration
!
! This file is part of the OCEAN project and distributed under the terms 
! of the University of Illinois/NCSA Open Source License. See the file 
! `License' in the root directory of the present distribution.
!
!
! Reads through ximat and checks against a reference ximat

program builder_check
  implicit none

  integer, parameter :: DP = kind(1.0d0)
  integer :: npt, ipt, jpt
  real(DP), allocatable :: xi_ref(:,:), xi(:,:)

  real(DP) :: max_diff, diff
  real(DP), parameter :: tol = 1.0d-12



  open(unit=99,file='rbfile.bin',form='unformatted',status='old')
  rewind(99)
  read(99) npt
  close(99)
  write(6,*) npt

  allocate( xi_ref( npt, npt ), xi( npt, npt ) )

  write(6,*) 'Reading in ximat_reference'
  open(unit=99,file='ximat_reference',form='unformatted',status='old')
  rewind(99)
  do ipt = 1, npt
    read( 99 ) xi_ref( :, ipt )
  enddo
  close(99)
  
  write(6,*) 'Reading in ximat'
  open(unit=99,file='ximat',form='unformatted',status='old')
  rewind(99)
  do ipt = 1, npt
    read( 99 ) xi( :, ipt )
  enddo
  close(99)

  max_diff = 0.0_DP
  do jpt = 1, npt
    do ipt = 1, npt
      diff = abs( xi_ref( ipt, jpt ) - xi( ipt, jpt ) )
      if( diff .gt. max_diff ) then 
        max_diff = diff
        write(6,*) ipt, jpt, diff
      endif
    enddo
  enddo

  write(6,*) 'Max difference: ', max_diff
  if( max_diff .gt. tol ) write(6,*) 'Diff larger than tol'

  deallocate( xi, xi_ref)

end program builder_check
