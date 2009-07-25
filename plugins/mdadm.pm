#!/usr/bin/perl
# mdadm.pm
# This a a bck-backup plugin.
#
# Written & Copyright (c) by : Bruno Veldeman
#
#################################################################################
#										#
#   This program is free software: you can redistribute it and/or modify	#
#   it under the terms of the GNU General Public License as published by	#
#   the Free Software Foundation, either version 3 of the License, or		#
#   (at your option) any later version.						#
#										#
#   This program is distributed in the hope that it will be useful,		#
#   but WITHOUT ANY WARRANTY; without even the implied warranty or		#
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the		#
#   GNU General Public License for more details.				#
#										#
#   You should have received a copy of the GNU General Public License		#
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.	#
#										#
#################################################################################
#
#

package Plugin;
use strict;
use warnings;
no warnings 'redefine';
# Plugin version
my( $version ) = "0.0.1";
#############################################################################
#
# Constructor
#
#############################################################################
sub new
{
	my ( $class ) = shift;
	my $self =
	{
		_section	=> shift,
		_writelog	=> shift, 
		_writelist	=> shift,
		_param		=> @_,
		_status   	=> 0,
		_infotext	=> undef,
		_required	=> {},
		_optional	=> {},
		_help	=> undef
	};
	$self->{_required} =	
				{	
					type=>"mdadm", 
					name=>"Description field", 
					raid=>"Comma separated list of raids to check. Multiple entries can be used."
				};
	$self->{_optional} = 	
				{ 
					proc=>"[yes|no] If set to yes will also log info from proc"
				};
	$self->{_help} = "Check raid status";
	bless( $self, $class );
	return( $self );
};
#############################################################################
#
# Run : Starts the work
#
#############################################################################
#
sub Run # () -> ( $status, $errortext, $warningtext [, $size [, destfree [, destsize] ] ] )
{
	my ( $self ) = shift;
	my ( $raidsize ) = 0;
	my ( $status ) = 0;
	my ( @raidlist ) = split(/[,\n]/,$self->{_param}{'raid'} );
	#loop sources
	foreach my $raid (@raidlist)
	{
		my $cmd = 'mdadm --detail ' . $raid;
		$self->{_writelog}->( "Command : " . $cmd , 3 );
		open (DATA, "$cmd 2>&1 |" ) or $status = 1;
		#read stdin
		if ( $status == 0 )
		{
			while ( defined ( my $line = <DATA> )  )
			{
				chomp($line);
				$self->{_writelog}->( $line , 3 );
				#first line shoud be the raid device, so we look for that
				if ( $line =~ m/^(\/dev\/.*):/ )
				{
					if ( $1 ne $raid )
					{
						$self->{_status} = 2 unless ( $self->{_status} ge 2 );
						$self->{_writelog}->( "Raid $raid error. Device: $1" , 1 );
					}
					else
					{
						$self->{_writelog}->( "Raid $raid info. Device: $1" , 1 );
					};
				};
				if ( $line =~ m/^State : (.*)/g )
				{
					my ( $mdstate ) = $1;
					if ( $mdstate ne "clean" )
					{
						$self->{_status} = 2 unless ( $self->{_status} ge 2 );
						$self->{_infotext} .= "$raid state: $mdstate";
						$self->{_writelog}->( "Raid $raid error. State: $mdstate" , 1 );
					}
					else
					{
						$self->{_writelog}->( "Raid $raid ok. State: $mdstate\n" , 1 );
					};
				}
				if ( $line =~ m/^Array Size : (.*) \(/g )
				{
					$raidsize += ( $1 * 1000 );
				};
				
			};
			close DATA;
			$status = $? >> 8;
		};
		#end read stdin
		if ( $status ne 0 )
		{
			$self->{_status} = 2 unless ( $self->{_status} ge 2 );
			$self->{_infotext} .= "mdadm error: $status";
		};
		$self->{_writelog}->( "Exit status : " . $status , 2 );
	};
	#end loop sources
	#check status
	if ( $self->{_status} == 0 )
	{
		$self->{_writelog}->( "Raid ok." , 1 );
	}
	else
	{
		$self->{_writelog}->( "Raid error." , 1 );
	};
	#end check status
	return( $self->{_status} , $self->{_infotext}, $raidsize, "0", "0" );
};

1;
