#!/usr/bin/perl
# tape.pm
# This a a bck-backup plugin.
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
				{	
					type=>"tape", 
					name=>"Description of the copy.", 
					sourcelist=>"Comma separated list of sources to include. Multiple entries can be used.",
					dest=>"Destination device."
				};
	$self->{_optional} = 	
					eject=>"[yes|no] Eject tape after writing if set to \"yes\".",
					label=>"[yes|no] Read label before writing if set to \"yes\". (tar must be version 1.15.90 or higher)"
				};
	bless( $self, $class );
	return( $self );
};
#############################################################################
#
# Run : Starts the work
#
#############################################################################
sub Run # () -> ( $status, $errortext, $warningtext [, $size [, destfree [, destsize] ] ] )
{
	my ( $self ) = shift;
	my ( $sourcelist );
	my ( $online ) = 0;
	my ( $cleaning ) = 0;
	my ( $status ) = 0;
	my ( @sources ) = split(/[,\n]/,$self->{_param}{'sourcelist'} );
	#loop sources
	foreach $source ( @sources )
	{
		if ( -e $source )
		{
			$sourcelist = $sourcelist . ' "' . $source . '"';
		}
		else
		{
			$self->{_status} = 1 unless ( $self->{_status} ge 1 );
			$self->{_writelog}->( "Source $source does not exist", 3 );
		};
	};
	# Check tape status
	my $cmd = "mt -f " . $self->{_param}{'dest'} . " status";
	my ( $status ) = 0;
	open (DATA, "$cmd 2>&1 |" ) or $status = 1;
	$self->WriteLog( "Command : " . $cmd , 3 );
	if ( $status == 0 )
	{
		my ( $flag ) = 0;
		while ( defined ( my $line = <DATA> )  )
		{
			chomp($line);
			$self->WriteLog->( $line , 1 );
			#  Check for ONLINE
			if ( $line =~ m/ONLINE/ )
			{
				$online = 1
				$self->{_writelog}->( "Tape " . $self->{_param}{'dest'} . "online.", 3 );
			};
			if ( $line =~ m/CLN/ )
			{
				$cleaning = 1
				$self->{_writelog}->( "Tape " . $self->{_param}{'dest'} . " needs cleaning.", 3 );
				$self->{_status} = 1 unless ( $self->{_status} ge 1 );
				$self->{_infotext} .= "-Tape device $self->{_param}{'dest'} needs cleaning";
			};
		};
		close DATA;
		$status = $? >> 8;
	};
	$self->{_writelog}->( "Exit status : " . $status , 2 );
	 # End check tape status
	if ( $online ne 0 )
	{
		if ( defined 
		# Read label from tape (tar must be at least 1.15.90)
		$status = 0;
		my $cmd = 'tar --test-label --file ' . $self->{_dest};
		open (DATA, "$cmd 2>&1 |" ) or $status = 1;
		$self->WriteLog->( "Command : " . $cmd , 3 );
		if ( $status == 0 )
		{
			while ( defined ( my $line = <DATA> )  )
			{
				chomp($line);
				my ( $label ) = $line;
				if ( defined $label )
				{
					$self->WriteLog( "Using tape with label: " . $line , 3 );
				}
				else
				{
					$self->WriteLog( "Using tape with no label" , 3 );
				};
			};
			close DATA;
			$status = $? >> 8;
		};
		if ( $status ne 0 )
		{
			$self->{_status} = 1 unless ( $self->{_status} ge 1 );
			$self->WriteLog( "Cannot read tape label." , 1 );
		};
		# End read label
		# Tar command
		$cmd = 'tar --create  --dereference --verbose --totals --label ' . $self->{_section} . "." . $self->{_logdate} . ' ' . $excludelist . ' --file ' . $self->{_dest} . ' ' . $sourcelist;
		$status = 0;	
		open (DATA, "$cmd 2>&1 |" ) or $status = 1;
		$self->WriteLog->( "Command : " . $cmd , 3 );
		if ( $status == 0 )
		{
			while ( defined ( my $line = <DATA> )  )
			{
				chomp($line);
				if ( $line =~ m/^\// )
				{
					$self->WriteList->( $line );
				}
				else
				{
					if ( $line =~ m/tar:/ )
					{
						$self->WriteLog->( $line , 1 );
					}
					else
					{
						$self->WriteLog->( $line , 3 );
					};
				};
			};
			close DATA;
			$status = $? >> 8;
		};
		$self->WriteLog->( "Exit status : " . $status , 2 );
		# End tar command
		# mt rewoffl if eject = yes
		if ( $self->{_eject} eq "yes" )
		{
			my $cmd = "mt -f " . $self->{_dest} . " rewoffl";
			$status = 0;
			open (DATA, "$cmd 2>&1 |" ) or $status = 1;
			$self->WriteLog( "Command : " . $cmd , 3 );
			if ( $status == 0 )
			{
				while ( defined ( my $line = <DATA> )  )
				{
					chomp($line);
					if ( $line =~ m/:/ )
					{
						$self->WriteLog( $line , 1 );
					}
					else
					{
						$self->WriteLog( $line , 3 );
					}
				};
				close DATA;
				$status = $? >> 8;
			};
			if ( $status != 0 )
			{
				$self->WriteLog( "Tape eject error" , 1 );
			}
			else
			{
				$self->WriteLog( "Tape ejected" , 1 );
			};
		};
	}
	else
	{
		$self->{_writelog}->( "No tape in tape device " . $self->{_dest} . " or defective tape", 0 );
		$self->{_status} = 2 unless ( $self->{_status} ge 2 );
		$self->{_infotext} .= "-No tape in tape device $self->{_dest}.";
	};
	#check status
	if ( $self->{_status} eq 0 )
	{
		$self->{_writelog}->( "$self->{_section} ok." , 1 );
	}
	else
	{
		$self->{_writelog}->( "$self->{_section} warning/error." , 1 );
	};
	#end check status
	return( $self->{_status} , $self->{_infotext}, "0", "0", "0" );
};

1;

####################################################################################3
	}
	else
	{
		$self->WriteLog ( "Tape status error, no tape found in device or wrong/defective tape.", 0);
	};
	if ( $status == 0 )
	{
		$self->WriteLog( "All files copied." , 1 );
	}
	else
	{
		$self->WriteLog( "One or more errors/warning." , 1 );
	};
	return ( $status );
};