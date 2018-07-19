! Copyright (C) 2017 OCEAN collaboration
!
! This file is part of the OCEAN project and distributed under the terms 
! of the University of Illinois/NCSA Open Source License. See the file 
! `License' in the root directory of the present distribution.
!
!
! by John Vinson 03-2017
!
!
module screen_paral
  use ai_kinds, only : DP
#ifdef MPI_F08
  use mpi_f08, only : MPI_COMM
#endif
  implicit none
  private

  type site_parallel_info
    integer :: total_procs  ! this is (often) copy of ocean_mpi : nproc
    integer :: nprocs   ! how many procs assigned to this site
    integer :: num_groups   ! how many groups exist
    integer :: mygroup  ! group index
    integer :: myid   ! mpi index w/i site group
    integer :: root = 0
#ifdef MPI_F08
    type( MPI_COMM ) :: comm
#else
    integer :: comm
#endif
  end type site_parallel_info


  public :: site_parallel_info
  public :: screen_paral_init
  public :: screen_paral_siteIndex2groupIndex, screen_paral_procID2groupID, screen_paral_procID2groupIndex, &
            screen_paral_NumLocalSites, screen_paral_isMySite, screen_paral_siteIndexID2procID, &
            screen_paral_isYourSite

  contains


  subroutine screen_paral_init( n_sites, pinfo, ierr )
    use OCEAN_mpi, only : myid, comm, nproc, MPI_SUCCESS, MPI_COMM_SPLIT, MPI_COMM_RANK, MPI_COMM_SIZE
    !
    integer, intent( in ) :: n_sites
    type( site_parallel_info ), intent( out ) :: pinfo
    integer, intent( inout ) :: ierr
    !
!    integer, parameter :: rank_primes = 10
!    integer, parameter :: primes( rank_primes ) = (/ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29 /)
    integer :: test_size

    call how_many_groups( n_sites, nproc, pinfo%num_groups )
    !
    pinfo%nprocs = nproc / pinfo%num_groups
    pinfo%total_procs = pinfo%num_groups * pinfo%nprocs
    !
    ! integer division will give us pinfo%nprocs for group 0, and etc
    !pinfo%mygroup = myid / pinfo%nprocs
    pinfo%mygroup = screen_paral_procID2groupIndex( pinfo, myid )

    call MPI_COMM_SPLIT( comm, pinfo%mygroup, myid, pinfo%comm, ierr )
    if( ierr .ne. MPI_SUCCESS ) return
    !
    call MPI_COMM_RANK( pinfo%comm, pinfo%myid, ierr )
    if( ierr .ne. MPI_SUCCESS ) return
    !
    call MPI_COMM_SIZE( pinfo%comm, test_size, ierr )
    if( ierr .ne. MPI_SUCCESS ) return
    if( test_size .ne. pinfo%nprocs ) then
      write( 6, * ) 'Problems creating site comms', myid, test_size, pinfo%nprocs
      ierr = -101
      return
    endif
    
    
    if( pinfo%myid .ne. screen_paral_procID2groupID( pinfo, myid ) ) then
      write( 6, * ) 'Failure with screen_paral_procID2groupID:'
      write(6,*) myid, pinfo%myid, screen_paral_procID2groupID( pinfo, myid )
      ierr = 1
    endif


    call write_paral_summary( myid, pinfo )

  end subroutine screen_paral_init


  subroutine write_paral_summary( myid, pinfo )
    type( site_parallel_info ), intent( in ) :: pinfo
    integer, intent( in ) :: myid

    write(1000+myid,*) "### SCREEN_PARAL Summary ###"
    write(1000+myid,*) "############################"
    write(1000+myid,*) "Total procs =  ", pinfo%total_procs
    write(1000+myid,*) "N procs/site = ", pinfo%nprocs
    write(1000+myid,*) "Num groups =   ", pinfo%num_groups
    write(1000+myid,*) "My group =     ", pinfo%mygroup
    write(1000+myid,*) "My ID =        ", pinfo%myid
    write(1000+myid,*) "############################"

  end subroutine write_paral_summary

  pure function screen_paral_siteIndexID2procID( pinfo, SiteIndex, SiteID ) result( procID )
    type( site_parallel_info ), intent( in ) :: pinfo
    integer, intent( in ) :: siteIndex, SiteID
    integer :: procID
    integer :: groupIndex

    groupIndex = screen_paral_siteIndex2groupIndex( pinfo, siteIndex )
    procID = groupIndex * pinfo%nprocs + SiteID

  end function screen_paral_siteIndexID2procID

  pure function screen_paral_isMySite( pinfo, siteIndex ) result( isMySite )
    type( site_parallel_info ), intent( in ) :: pinfo
    integer, intent( in ) :: siteIndex
    logical :: isMySite

    isMySite = ( screen_paral_siteIndex2groupIndex( pinfo, siteIndex ) .eq. pinfo%mygroup )
  end function screen_paral_isMySite

  pure function screen_paral_isYourSite( procID, pinfo, siteIndex ) result ( isYourSite )
    type( site_parallel_info ), intent( in ) :: pinfo
    integer, intent( in ) :: procID, siteIndex
    logical :: isYourSite

    isYourSite = ( screen_paral_procID2groupIndex( pinfo, procID ) .eq. & 
                   screen_paral_siteIndex2groupIndex( pinfo, siteIndex ) )
    
  end function screen_paral_isYourSite

  pure function screen_paral_siteIndex2groupIndex( pinfo, siteIndex ) result( groupIndex )
    type( site_parallel_info ), intent( in ) :: pinfo
    integer, intent( in ) :: siteIndex
    integer :: groupIndex
    !
    groupIndex = mod( siteIndex - 1, pinfo%num_groups )
  end function screen_paral_siteIndex2groupIndex

  pure function screen_paral_NumLocalSites( pinfo, nsites ) result( NumLocalSites )
    type( site_parallel_info ), intent( in ) :: pinfo
    integer, intent( in ) :: nsites
    integer :: NumLocalSites

    integer :: i, j

    j = nsites
    do i = 0, pinfo%mygroup
      NumLocalSites = j / ( pinfo%num_groups - i )
      j = j - NumLocalSites
    enddo
  end function screen_paral_NumLocalSites

  pure function screen_paral_procID2groupIndex( pinfo, procID ) result( groupIndex )
    type( site_parallel_info ), intent( in  ) :: pinfo
    integer, intent( in ) :: procID
    integer :: groupIndex

    groupIndex = procID / pinfo%nprocs

    if( groupIndex .ge. pinfo%num_groups ) groupIndex = -1

  end function screen_paral_procID2groupIndex

  pure function screen_paral_procID2groupID( pinfo, procID ) result( groupID )
    type( site_parallel_info ), intent( in  ) :: pinfo
    integer, intent( in ) :: procID
    integer :: groupID

    if( procID .ge. pinfo%total_procs ) then
      groupID = -1
      return
    endif

    groupID = mod( procID, pinfo%nprocs )

  end function screen_paral_procID2groupID

  subroutine how_many_groups( n_sites, nproc, ngroups )
    use OCEAN_mpi, only : myid, root
    integer, intent( in ) :: n_sites, nproc 
    integer, intent( out ) :: ngroups
    !
    real( DP ) :: score, best_score
    integer :: i, j, best_ngroup

    if( n_sites .eq. 1 .or. nproc .eq. 1 ) then
      ngroups = 1
      return
    endif

    if( mod( nproc, n_sites ) .eq. 0 ) then
      ngroups = n_sites
      return
    endif

    if( mod( n_sites, nproc ) .eq. 0 ) then
      ngroups = nproc
      return
    endif

    best_ngroup = 1
    best_score = 0.0_DP

    do i = 1, n_sites
      ! i groups, j per group, i * j being used
      j = nproc / i
      score = real( j * i, DP ) / real( nproc, DP )
      ! and then if mod( n_sites, ngroups ) .ne. 0 then more idle
      if( mod( n_sites, i ) .ne. 0 ) then
        score = score * real( mod( n_sites, i ), DP ) / real( i, DP )
      endif

      if( score .gt. best_score ) then
        best_score = score
        best_ngroup = i
      endif
    enddo


    ngroups = best_ngroup
    if( myid .eq. root ) write( 6, * ) 'Using groups: ', ngroups, best_score

    return

  end subroutine how_many_groups    
    

  subroutine make_primes( num, np, plist, num_out, pout )
    use OCEAN_mpi, only : myid, root
    integer, intent( in ) :: num, np
    integer, intent( in ) :: plist( np )
    integer, intent( out ) :: num_out, pout( np )
    !
    integer :: i, j, k, tmp
    !
    tmp = num
    pout( : ) = 0
    !
    do i = 1, np
      k = tmp / plist( i ) + 1
      do j = 1, k
        if( mod( num,  plist( i ) ) .eq. 0 ) then
          tmp = tmp / plist( i )
          pout( i ) = pout( i ) + 1
        else
          exit
        endif
      enddo
    enddo

    if( tmp .ne. 1 ) then
      if( myid .eq. root ) write(6,*) 'Failed to factorize number of processors. Will use fewer', tmp
    endif

    tmp = 0
    do i = 1, np
      tmp = tmp + plist( i ) ** pout( i )
    enddo
    num_out = tmp

    if( myid .eq. root ) then
      write(6,* ) num_out
      write(6,'(10(I4))') plist( : )
      write(6,'(10(I4))') pout( : )
    endif

  end subroutine make_primes
    

!  subroutine make_sub_comms( color, ierr )
!    use OCEAN_mpi, only : myid, comm
!    
!    call MPI_COMM_SPLIT( )

end module screen_paral