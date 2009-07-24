#!/usr/bin/perl
# Skeleton.pm
# This a a bck-backup plugin skeleton.
# Use it to create plugins.
#
# Written & Copyright (c) by : Bruno Veldeman
#
#################################################################################
#																				#
#   This program is free software: you can redistribute it and/or modify		#
#   it under the terms of the GNU General Public License as published by		#
#   the Free Software Foundation, either version 3 of the License, or			#
#   (at your option) any later version.											#
#																				#
#   This program is distributed in the hope that it will be useful,				#
#   but WITHOUT ANY WARRANTY; without even the implied warranty or				#
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the				#
#   GNU General Public License for more details.								#
#																				#
#   You should have received a copy of the GNU General Public License			#
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.		#
#																				#
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
		_optional	=> {}
	};
	$self->{_required} =	
				{	# This is a named hash with the required options and it's description.
					# Here goes the type (required) option, this must be the same as the filename without the extension (.pm).
					type=>"skeleton", 
					# Here goes the name (required) option and it's description.
					name=>"name", 
					# Here go all the other options.
					# Ex.: sourcelist option.
					sourcelist=>"Comma separated list of sources to include. Multiple entries can be used."
				};
	$self->{_optional} = 	
				{ 	# This is a named hash with the optional options and it's description.
					# Ex.: histdirs
					myoption=>"My optional option for this plugin."
				};
	bless( $self, $class );
	return( $self );
};
#############################################################################
#
# Run : Starts the work
#
#############################################################################
#
# Here you can do whatever you like, just return a status value indicating the exit $status, optional values for $info, $datasize, $destfree and $destsize can be returned.
#   $status = 0: OK; $status = 1: Warning; $status = 2: ERROR; $status = 3: INVALID
#	$info: Optional, short description of what was done.
#	$datasize: Optional, size information.
#	$destfree: Optional, disk free information.
#	$destsize: Optional, total size where operation took place.
#	$self->{_section} holds the name of the section.
#	There are 2 callback functions passed:
#		$self->{_writelog}->( $text , $lvl ) # Writes the text to the logfile and onscreen if --verbose or --debug is used, depending on $lvl
#		$self->{_writelist}->( $text ) # Writes the text to the filelist file, intended to use a a list of files processed (copied, moved, deleted, ...).
#	All the options are passed as a hash:
#		$self->{_param} 
#		Use $self->{_param}->{'option'} to access the values, where 'option' is the option you want the value for.
sub Run # () -> ( $status, $errortext, $warningtext [, $size [, destfree [, destsize] ] ] )
{
	my ( $self ) = shift;
	my ( $source );
	my ( $status ) = 0;
	my ( @sources ) = split(/[,\n]/,$self->{_param}{'sourcelist'} );
	#check if histdirs is set
	#loop sources
	foreach $source (@sources)
	{
		my $cmd = 'ls -lah ' . $source;
		$self->{_writelog}->( "Command : " . $cmd , 3 );
		open (DATA, "$cmd 2>&1 |" ) or $status = 1;
		#read stdin
		if ( $status == 0 )
		{
			while ( defined ( my $line = <DATA> )  )
			{
				chomp($line);
				$self->{_writelog}->( $line , 3 );
				$self->{_writelist}->( $line );
			};
			close DATA;
			$status = $? >> 8;
		};
		#end read stdin
		if ( $status ne 0)
		{
			$self->{_status} = 	2;
		};
		$self->{_writelog}->( "Exit status : " . $status , 2 );
	};
	#check status
	if ( $self->{_status} == 0 )
	{
		$self->{_writelog}->( "skeleton ok." , 1 );
	}
	else
	{
		$self->{_writelog}->( "skeleton warning/error." , 1 );
	};
	#end check status
	return( $self->{_status} , "Infotext", "0", "0", "0" );
};

1;