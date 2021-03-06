! Copyright (C) 2010 OCEAN collaboration
!
! This file is part of the OCEAN project and distributed under the terms 
! of the University of Illinois/NCSA Open Source License. See the file 
! `License' in the root directory of the present distribution.
!
!
subroutine hpload( hptab, nr, ind2 )
  implicit none
  !
  integer :: nr, ind2
  real( kind = kind( 1.0d0 ) ) :: hptab( nr, 2 )
  !
  integer :: i
  real( kind = kind( 1.0d0 ) ) :: dum
  !
  open( unit=99, file='hapot', form='formatted', status='unknown' )
  rewind 99
  do i = 1, nr
     read ( 99, * ) dum, hptab( i, ind2 )
  end do
  close( unit=99 )
  !
  return
end subroutine hpload
