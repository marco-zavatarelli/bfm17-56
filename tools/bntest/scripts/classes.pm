#!/usr/bin/perl -w


# DESCRIPTION
#   Classes for configuration generator
#
# AUTHORS
#   Esteban Gutierrez esteban.gutierrez@cmcc.it
#   Tomas Lovato toma.lovato@cmcc.it
#
# COPYING
#  
#   Copyright (C) 2013 BFM System Team ( bfm_st@lists.cmcc.it )
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation;
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTEABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# -----------------------------------------------------

use strict;
use warnings;

use Data::Dumper;

###############Class Test
package Test;

my @OPTIONS= ('PRESET', 'ARCH', 'FORCING', 'VALGRIND');
sub get_options{ my ( $self ) = @_; return @OPTIONS; }

sub new{
   my $class = shift;
   my $self = {
       _name     => shift,
       _preset   => shift,
       _arch     => shift,
       _forcing  => shift,
       _valgrind => shift,
   };
   return bless $self, $class;   
}

sub DESTROY{}

sub getName    { my( $self ) = @_; return $self->{_name}    ; }
sub getPreset  { my( $self ) = @_; return $self->{_preset}  ; }
sub getArch    { my( $self ) = @_; return $self->{_arch}    ; }
sub getForcing { my( $self ) = @_; return $self->{_forcing} ; }
sub getValgrind{ my( $self ) = @_; return $self->{_valgrind}; }

sub setName    { my ( $self, $name      ) = @_; $self->{_name}    = $name      if defined($name)    ; }
sub setPreset  { my ( $self, $preset    ) = @_; $self->{_preset}  = $preset    if defined($preset)  ; }
sub setArch    { my ( $self, $arch      ) = @_; $self->{_arch}    = $arch      if defined($arch)    ; }
sub setForcing { my ( $self, $forcing   ) = @_; $self->{_forcing} = $forcing   if defined($forcing) ; }
sub setValgrind{ my ( $self, $valgrind  ) = @_; $self->{_valgrind} = $valgrind if defined($valgrind); }

sub print{
    my ( $self ) = @_;
    print "Test ";
    if($self->{_name})     { print "Name: "    . $self->getName()       . "; "; }
    if($self->{_preset})   { print "Preset: "  . $self->getPreset()     . "; "; }
    if($self->{_arch})     { print "Arch: "    . $self->getArch()       . "; "; }
    if($self->{_forcing})  { print "Forcing: " . $self->getForcing()    . "; "; }
    if($self->{_valgrind}) { print "Valgrind: " . $self->getValgrind() . "; "; }
}

#generate options to execute bfm_configure
sub generate_opt{
    my ( $self ) = @_;
    my $cmd = '';
    if($self->{_name})   { $cmd .= " -x "  . $self->getName()      . " "; }
    if($self->{_preset}) { $cmd .= " -p "  . $self->getPreset()    . " "; }
    if($self->{_arch})   { $cmd .= " -a "  . $self->getArch()      . " "; }
    return $cmd;
}

sub printAll{
    my ($self, $lst_test) = @_;
    print "Test list: \n";
    foreach my $test (@$lst_test){ print "\t" ; $test->print(); print "\n"; }
}


1;
