#!/usr/bin/perl
# optical.pm
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
					type=>"optical", 
					name=>"name", 
					sourcelist=>"Comma separated list of sources to include. Multiple entries can be used.",
					dest=>"Destination device (Must be CD or DVD writer)",
					medium=>"[CD|CDRW|DVD|DVDRW] Type of medium used."
				};
	$self->{_optional} = 	
				{ 	
					excludelist=>"List of files/folders to exclude from copy.",
					label=>"Label de cd/dvd if set.",
					eject=>"[yes|no] Eject after writing if set to yes.",
					load=>"[yes|no] Load before writing if set to yes."
				};
	$self->{_help} = "Copy multiple sources on CD/DVD, medium can rewritable. !!!! Work in progress !!!!";
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
	my ( $sourcelist ) = "";
	my ( $source );
	my ( $excludelist ) = "";
	my ( $cleaning ) = 0;
	my ( $status ) = 0;
	my ( $size ) = 0;
	my ( $cmd );
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
	# Check if dest is block device.
	if ( -b $self->{_param}{'dest'} )
	{
		# Close tray if needed
		$self->{_param}{'load'} = "no" unless defined  $self->{_param}{'load'};
		if ( $self->{_param}{'load'} eq "yes")
		{
			my $cmd = "cdrecord dev=" . $self->{_param}{'dest'} . " -load";
			$status = 0;
			open (DATA, "$cmd 2>&1 |" ) or $status = 1;
			$self->{_writelog}->( "Command : " . $cmd , 3 );
			if ( $status == 0 )
			{
				while ( defined ( my $line = <DATA> )  )
				{
					chomp($line);
					$self->{_writelog}->( $line , 3 );
				};
				close DATA;
				$status = $? >> 8;
				$self->{_writelog}->( "Exit status : " . $status , 2 );
			};
		}
		else
		{
			$self->{_writelog}->( "Error closing tray on $self->{_param}{'dest'}.", 0 );
			$self->{_infotext} .= "-Error closing tray on $self->{_param}{'dest'}.";
		};
		# End close tray
	}
	else
	{
		$self->{_writelog}->( "$self->{_param}{'dest'} does not look like a cd/dvd writer.", 0 );
		$self->{_infotext} .= "-$self->{_param}{'dest'} does not look like a cd/dvd writer.";
	};
	if ( $status eq 0 )
	{
		$self->{_param}{'label'} = "no" unless defined  $self->{_param}{'label'};
		if ( $self->{_param}{'label'} eq "yes" )
		{

		};
		# Create CD command
		$cmd = 'tar --create  --dereference --verbose --totals --label ' . $self->{_section} . "." . time . ' ' . $excludelist . ' --file ' . $self->{_param}{'dest'} . ' ' . $sourcelist;
		$status = 0;	
		open (DATA, "$cmd 2>&1 |" ) or $status = 1;
		$self->{_writelog}->( "Command : " . $cmd , 3 );
		if ( $status == 0 )
		{
			while ( defined ( my $line = <DATA> )  )
			{
				chomp($line);
				if ( $line =~ m/^\// )
				{
					$self->{_writelist}->( $line );
				}
				else
				{
					if ( ( $line =~ m/tar:/ ) and ( $line !~ m/Removing leading/ ) )
					{
						$self->{_writelog}->( $line , 1 );
					}
					else
					{
						$self->{_writelog}->( $line , 3 );
					};
				};
				if ( $line =~ m/^Total bytes written: (.*) \(.*, (.*)\)/ )
				{
					$size = $1;
					$self->{_writelog}->( "Total bytes written: $size", 1 );
					$self->{_infotext} .= "-Data troughput: $2";
					$self->{_writelog}->( "Data troughput: $2", 1 );
				}
			};
			close DATA;
			$status = $? >> 8;
		};
		$self->{_writelog}->( "Exit status : " . $status , 2 );
		if ( $status ne 0 )
		{
			$self->{_status} = 2 unless ( $self->{_status} ge 2 );
			
		};
		# End tar command
		if ( -c $self->{_param}{'dest'} )
		{
		# Close tray if needed
		$self->{_param}{'load'} = "no" unless defined  $self->{_param}{'load'};
		if ( $self->{_param}{'load'} eq "yes")
		{
			my $cmd = "cdrecord dev=" . $self->{_param}{'dest'} . " -eject";
			$status = 0;
			open (DATA, "$cmd 2>&1 |" ) or $status = 1;
			$self->{_writelog}->( "Command : " . $cmd , 3 );
			if ( $status == 0 )
			{
				while ( defined ( my $line = <DATA> )  )
				{
					chomp($line);
					$self->{_writelog}->( $line , 3 );
				};
				close DATA;
				$status = $? >> 8;
				$self->{_writelog}->( "Exit status : " . $status , 2 );
			};
		}
		else
		{
			$self->{_writelog}->( "Error opening tray on $self->{_param}{'dest'}.", 0 );
			$self->{_infotext} .= "-Error opening tray on $self->{_param}{'dest'}.";
		};
		# End close tray
		};
	}
	else
	{
		$self->{_writelog}->( "No tape in tape device " . $self->{_param}{'dest'} . " or defective tape", 0 );
		$self->{_status} = 2 unless ( $self->{_status} ge 2 );
		$self->{_infotext} .= "-No tape in tape device $self->{_param}{'dest'}.";
	};
	return( $self->{_status} , $self->{_infotext}, $size, "0", "0" );
};

1;

############################################################################
##
## Sub FormatDvd : Format DVD
##
############################################################################
#sub FormatDvd
#{
#	my ( $self ) = shift;
#	my $cmd = SysCommand->new();
#	my $cmdline = $gsection->GetDvdFormat() . " -force " . $self->{_dest};
#	$cmd->Exec($cmdline);
#	my $status = $cmd->GetStatus();
#	$self->{_status} += $status;
#	return(0);
#};
############################################################################
##
## Sub FormatCd : Format CD
##
############################################################################
#sub FormatCd
#{
#	my ( $self ) = shift;
#	my $cmd = SysCommand->new();
#	my $cmdline = $gsection->GetCdRecord() . " -blank=fast -dev=" . $self->{_dest};
#	$cmd->Exec($cmdline);
#	my $status = $cmd->GetStatus();
#	$self->{_status} += $status;
#};
############################################################################
##
## Sub WriteDvd : Write DVD
##
############################################################################
#sub WriteDvd
#{
#	my ( $self ) = shift;
#	my ( $filelist ) = @_;
#	my ( @daynames ) = qw( sunday monday tuesday wednesday thursday friday saturday );
#	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime( time );
#	my ( $wdname ) = $daynames[$wday];
#	my $cmd = SysCommand->new();
#	my ( $excludelist ) = ' ';
#	if ( defined $self->{_excludelist} )
#	{
#		my (@excludes ) = split(/[,\n]/,$self->{_excludelist});
#		my ( $exclude );
#		foreach $exclude (@excludes)
#		{
#			$excludelist = $excludelist . ' -m ' . $exclude;
#		};
#	};
#	my $cmdline = $gsection->GetDvdRecord() . ' -Z ' . $self->{_dest} . ' -joliet-long  -J ' . $excludelist . ' -R -V "' . $gsection->GetClient() . " " . $wdname . '" -graft-points '. $filelist;
#	$cmd->Exec($cmdline);
#	my $status = $cmd->GetStatus();
#	$self->{_status} += $status;
#};
############################################################################
##
## Sub WriteCd : Write CD
##
############################################################################
#sub WriteCd
#{
#	my ( $self ) = shift;
#	my ( $filelist ) = @_;
#	my ( @daynames ) = qw( sunday monday tuesday wednesday thursday friday saturday );
#	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime( time );
#	my ( $wdname ) = $daynames[$wday];
#	my $tmpdir = tempdir("/var/tmp/BCKXXXXXX");
#	my $cmd = SysCommand->new();
#	my ( $excludelist ) = ' ';
#	if ( defined $self->{_excludelist} )
#	{
#		my (@excludes ) = split(/[,\n]/,$self->{_excludelist});
#		my ( $exclude );
#		foreach $exclude (@excludes)
#		{
#			$excludelist = $excludelist . ' -m ' . $exclude;
#		};
#	};
#	my $cmdline = 'mkisofs -joliet-long -o ' . $tmpdir . '/cd.iso -J ' . $excludelist . ' -R -V "' . $gsection->GetClient() . ' ' . $wdname . '" -graft-points '. $filelist;
#	$cmd->Exec($cmdline);
#	my $status = $cmd->GetStatus();
#	$self->{_status} += $status;
#	my $cmd2 = SysCommand->new();
#	$cmdline = "cdrecord -v -speed=8 -dev=" . $self->{_dest} . " " . $tmpdir . "/cd.iso";
#	$cmd2->Exec($cmdline);
#	$status = $cmd2->GetStatus();
#	$self->{_status} += $status;
#	rmtree( $tmpdir );
#}
