#!/usr/bin/perl
# Copyright (C) 2017 OCEAN collaboration
#
# This file is part of the OCEAN project and distributed under the terms 
# of the University of Illinois/NCSA Open Source License. See the file 
# `License' in the root directory of the present distribution.
#
#

use strict;

my $MNGKV = 0;
my $NKPT = 0;
my $NBND = 0;
my $NSPN = 0;
my $NSPINOR = 0;
my $GAMMA = 0;


open IN, $ARGV[0] or die "$!";

while( my $line=<IN> )
{
  if( $line =~ m/<MAX_NUMBER_OF_GK-VECTORS/ )
  {
    <IN> =~ m/(\d+)/;
    $MNGKV = $1;
    <IN>;
  }
  elsif( $line =~ m/<NUMBER_OF_K-POINTS/ )
  {
    <IN> =~ m/(\d+)/;
    $NKPT = $1;
    <IN>;
  }
  elsif( $line =~ m/<NUMBER_OF_BANDS/ )
  {
    <IN> =~ m/(\d+)/;
    $NBND = $1;
    <IN>;
  }
  elsif( $line =~ m/<NUMBER_OF_SPIN_COMPONENTS/ )
  {
    <IN> =~ m/(\d+)/;
    $NSPN = $1;
    <IN>;
  }
  elsif( $line =~m/<NON-COLINEAR_CALCULATION/ )
  {
    if( <IN> =~ m/T/ )
    {
      $NSPINOR = 2;
    }
    else
    {
      $NSPINOR = 1;
    }
  }
  elsif( $line =~m/<GAMMA_ONLY/ )
  {
    if( <IN> =~ m/T/ )
    {
      $GAMMA = 2;
    }
    else
    {
      $GAMMA = 1 ;
    }
  }


  last if( $GAMMA * $MNGKV * $NKPT * $NBND * $NSPN * $NSPINOR > 0 );
}
close IN;


open OUT, ">qe_data.txt" or die "$!";
print OUT "$NBND $MNGKV $NSPN $NSPINOR $NKPT $GAMMA\n";

if( scalar @ARGV > 1 )
{
  $MNGKV = 0;
  $NKPT = 0;
  $NBND = 0;
  $NSPN = 0;
  $NSPINOR = 0;

  open IN, $ARGV[1] or die "$!";

  while( my $line=<IN> )
  {
    if( $line =~ m/<MAX_NUMBER_OF_GK-VECTORS/ )
    {
      <IN> =~ m/(\d+)/;
      $MNGKV = $1;
      <IN>;
    }
    elsif( $line =~ m/<NUMBER_OF_K-POINTS/ )
    {
      <IN> =~ m/(\d+)/;
      $NKPT = $1;
      <IN>;
    }
    elsif( $line =~ m/<NUMBER_OF_BANDS/ )
    {
      <IN> =~ m/(\d+)/;
      $NBND = $1;
      <IN>;
    }
    elsif( $line =~ m/<NUMBER_OF_SPIN_COMPONENTS/ )
    {
      <IN> =~ m/(\d+)/;
      $NSPN = $1;
      <IN>;
    }
    elsif( $line =~m/<NON-COLINEAR_CALCULATION/ )
    {
      if( <IN> =~ m/T/ )
      {
        $NSPINOR = 2;
      }
      else
      {
        $NSPINOR = 1;
      }
    }
    elsif( $line =~m/<GAMMA_ONLY/ )
    {
      if( <IN> =~ m/T/ )
      {
        $GAMMA = 2;
      }
      else
      {
        $GAMMA = 1 ;
      }
    }


    last if( $GAMMA * $MNGKV * $NKPT * $NBND * $NSPN * $NSPINOR > 0 );

  }
  close IN;
}

# print two lines regardless (if only one DFT then this will be a duplicate)
print OUT "$NBND $MNGKV $NSPN $NSPINOR $NKPT $GAMMA\n";
close OUT;

exit 0;
