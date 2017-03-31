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
    pinfo%mygroup = myid / pinfo%nprocs
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
    
    

  end subroutine screen_paral_init


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