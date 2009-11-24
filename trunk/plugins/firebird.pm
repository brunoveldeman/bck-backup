#!/usr/bin/perl
# Local.pm
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
#   along with this program.  If not, see <http://www.gnu.org/licenses/>. 		#
#																				#
#################################################################################
#
#
package Plugin;
use strict;
use warnings;
no warnings 'redefine';
# Plugin version
my( $version ) = "0.0.0.1";
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
		_param		=> shift,
		_globvar	=> shift,
		_status   	=> 0,
		_infotext	=> undef,
		_size		=> 0,
		_destfree	=> 0,
		_destsize	=> 0,
		_required	=> {},
		_optional	=> {},
		_help	=> undef
	};
	$self->{_required} =	
				{
					type=>"firebird",
					name=>"Brief description of the operation. ex.: \"Main database\"",
					sourcelist=>"Database to include in copy. Only one can be specified",
					dest=>"Destination folder."
				};
	$self->{_optional} = 	
				{
					histdirs=>"Numeric value indicating the number of historical copies to be kept on destination. (A value of -1 creates a new folder for every run.)",
					options=>"Options to pass to the \"gbak\" command used to backup the database."
				};
	$self->{_help} = "Create hot backup of firebird database.";
	bless( $self, $class );
	return( $self );
};
#############################################################################
#
# Run : 
#
#############################################################################
sub Run # () -> ( $status, $statustext [, $size [, destfree [, destsize] ] ] )
{
	use File::Copy;
	my ( $self ) = shift;
	my ( $source, $options );
	my ( $status ) = 0;
	my ( @sources ) = split(/[,\n]/,$self->{_param}{'sourcelist'} );
	#check if histdirs is set
	if ( defined $self->{_param}{'histdirs'} )
	{
		#make history files
		if ( $self->{_param}{'histdirs'} != -1 )
		{
			#make a number of history files equal to histdirs
			#copy last file into hist structure
			move( $self->{_param}{'dest'} . '/' . $self->{_section} . '.gbk' , $self->{_param}{'dest'} . '/' . $self->{_section} . '1.gbk' );
			move( $self->{_param}{'dest'} . '/' . $self->{_section} . '.fdb' , $self->{_param}{'dest'} . '/' . $self->{_section} . '1.fdb' );
			#move the oldest file
			move(  $self->{_param}{'dest'} . '/' . $self->{_section} . $self->{_param}{'histdirs'} . '.gbk' , $self->{_param}{'dest'} . '/' . $self->{_section} . '.gbk' );
			move(  $self->{_param}{'dest'} . '/' . $self->{_section} . $self->{_param}{'histdirs'} . '.fdb' , $self->{_param}{'dest'} . '/' . $self->{_section} . '.fdb' );
			my ( $count );
			for ( $count = $self->{_param}{'histdirs'} ; $count >= 1; $count--)
			{
				#shift files one place
				move( $self->{_param}{'dest'} . '/' . $self->{_section} . ( $count - 1 ) . '.gbk', $self->{_param}{'dest'} . '/' . $self->{_section} . $count . '.gbk' );
				move( $self->{_param}{'dest'} . '/' . $self->{_section} . ( $count - 1 ) . '.fdb', $self->{_param}{'dest'} . '/' . $self->{_section} . $count . '.fdb' );
			};
		};
	};
	$source = shift(@sources);
	#check if source exist
	if ( defined $self->{_param}{'options'} )
	{
		$options =  $self->{_param}{'options'} . ' ';
	}
	else
	{
		$options = '-B -V -L -T -USER SYSDBA -PASSWORD masterkey ';
	};
	if ( -e $source )
	{
		my $cmd = $self->{_param}{'cmd'} . " " . $options . $source . " " . $self->{_param}{'dest'} . '/' . $self->{_section} . ".gbk";
		open (DATA, "$cmd 2>&1 |" ) or $status = 1;
		$self->{_writelog}->( "Command : " . $cmd , 3 );
		if ( $status == 0 )
		{
			my ( $flag ) = 0;
			while ( defined ( my $line = <DATA> )  )
			{
				chomp($line);
				if ( $line =~ m/^ERROR:/ )
				{
					$self->{_writelog}->( $line , 1 );
				}
				else
				{
					$self->{_writelist}->( $line , 3 );
				};
			};
			close DATA;
			$status = $? >> 8;
		};
		if ( $status == 0 )
		{
			$self->{_writelog}->( "Database backup (gbk) created." , 1 );
			$self->{_infotext} = "Database backup (gbk) created.";
		}
		else
		{
			$self->{_writelog}->( "One or more errors/warning." , 1 );
			$self->{_status} = 2 unless ( $self->{_status} ge 2 );
			$self->{_infotext} = "One or more errors/warning.";
		};
		# We also copy the database file itself just to be sure
		if ( copy( $source, $self->{_param}{'dest'} . '/' . $self->{_section} . ".fdb" ) )
		{
			$self->{_writelog}->( "Database (fdb) copied." , 1 );
		}
		else
		{
			$self->WriteLog( "One or more errors/warning." , 1 );
			$self->{_status} = 2 unless ( $self->{_status} ge 2 );
		};
		if ( defined $self->{_param}{'histdirs'} )
		{
			#make history files
			if ( $self->{_histdirs} == -1 )
			{
				#create new file for infinite history
				if ( move( $self->{_param}{'dest'} . '/' . $self->{_section} . '.gbk' , $self->{_param}{'dest'} . '/' . $self->{_section}. '.' . time . '.gbk' ) and move( $self->{_param}{'dest'} . '/' . $self->{_section} . '.fdb' , $self->{_param}{'dest'} . '/' . $self->{_section}. '.' . time . '.fdb' ))
				{
					$self->{_writelog}->( " Files moved into : " .  $self->{_param}{'dest'} . '/' . $self->{_section} . '.' . time . '.gbk' , 0 );
				}
				else
				{
					$self->{_writelog}->( " Could not move files." , 0 );
					$self->{_status} = 1 unless ( $self->{_status} ge 1 );
				};
			};
		};
	}
	else
	{
		$self->{_writelog}->( " Database source file does not exist." , 0 );
		$self->{_status} = 2 unless ( $self->{_status} ge 2 );
	};
	return( $self->{_status} );
};

1;
