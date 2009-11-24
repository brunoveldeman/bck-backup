#! /usr/bin/perl --
# local.pm
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
					type=>"local",
					name=>"Brief description of the operation. ex.: \"Copy my documents\"",
					sourcelist=>"Comma separated list of sources to include in copy. Multiple entries can be used.",
					dest=>"Destination folder."
				};
	$self->{_optional} = 
				{ 	
					#maxsize=>"Maximum bytes for copy, will not copy if larger.",
					histdirs=>"Numeric value indicating the number of historical copies to be kept on destination. (A value of -1 creates a new folder for every run.)",
					options=>"Options to pass to the \"rsync\" command used to copy the files.",
					excludelist=>"List of files/folders to exclude from copy.",
					mtime=>"[n] Exclude by time. If the integer n does not have sign this means exactly n 24-hour periods (days) ago, 0 means today.+n: if it has plus sign, then it means \"more then n 24-hour periods (days) ago\", or older then n, if it has the minus sign, then it means less than n 24-hour periods (days) ago (-n), or younger then n. Can be used with excludelist=."
				};
	$self->{_help} = "Copy files from multiple sources to destination. Complete path is used to recreate dirctory structure on destination.";
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
	use File::Temp qw/ mktemp /;
	my ( $self ) = shift;
	my ( $source, $options );
	my ( $status ) = 0;
	my ( @sources ) = split(/[,\n]/,$self->{_param}{'sourcelist'} );
	#check if histdirs is set
	if ( defined $self->{_param}{'histdirs'} )
	{
		#make history directories
		if ( $self->{_param}{'histdirs'} != -1 )
		{
			#make a number of history directories equal to histdirs
			#copy last directory into hist structure
			move( $self->{_param}{'dest'} . '/' . $self->{_section} , $self->{_param}{'dest'} . '/' . $self->{_section} . '1' );
			#move the oldest directory
			move(  $self->{_param}{'dest'} . '/' . $self->{_section} . $self->{_param}{'histdirs'} , $self->{_param}{'dest'} . '/' . $self->{_section} );
			my ( $count );
			for ( $count = $self->{_param}{'histdirs'} ; $count >= 1; $count-- )
			{
				#shift directories one place
				move( $self->{_param}{'dest'} . '/' . $self->{_section} . ( $count - 1 ), $self->{_param}{'dest'} . '/' . $self->{_section} . $count );
			};
		};
	};
	#end check if histdirs is set
	#loop sources
	foreach $source (@sources)
	{
		# Make sure source ends with "/" if it's a directory
		if ( -d $source )
		{
			$source .= "/" unless $source =~ m/\/$/;
		};
		# Check if source exists
		if ( -e $source )
		{
			#build excludelist string
			my ( $excludelist ) = "";
			if ( defined $self->{_param}{'excludelist'} )
			{
				my ( @excludes ) = split( /[,\n]/, $self->{_param}{'excludelist'} );
				my ( $exclude );
				foreach $exclude (@excludes)
				{
					$excludelist = $excludelist . ' --exclude=' . $exclude;
				};
			};
			#end build excludelist string
			if ( defined $self->{_param}{'options'} )
			{
				$options =  $self->{_param}{'options'} . ' ';
				$options =~ s/--verbose//g;
				$options =~ s/--stats//g;
				$options = "--verbose --stats " . $options;
			}
			else
			{
				$options = '--recursive --no-whole-file --copy-links --relative --verbose --times --delete-after --delete-excluded --delete --modify-window=3 --stats';
			};
			my ( $cmd );
			# Start file date filter
			my ( $filelist, $tempdir );
			if ( defined $self->{_param}{'mtime'} )
			{
				
				$filelist = mktemp( "$self->{_globvar}{'tempdir'}/bckfilterXXXXXX");
				$cmd = "find $source -mtime $self->{_param}{'mtime'} -type f -follow -fprint $filelist";
				$self->{_writelog}->( "Command : " . $cmd , 3 );
				open (DATA, "$cmd 2>&1 |" ) or $status = 1;
				#read stdin
				if ( $status == 0 )
				{
					while ( defined ( my $line = <DATA> )  )
					{
						chomp( $line );
						$self->{_writelog}->( $line , 3 );
					};
					$self->{_writelog}->( "Done filtering files by date.", 1 );
					$options = "--exclude-from=$filelist " . $options;
				}
				else
				{
					$self->{_writelog}->( "Cannot filter file by date.", 1 );
				};
			};
			# End file date filter
			$cmd = 'rsync ' . $options . ' ' . $excludelist . ' "' . $source . '" ' . $self->{_param}{'dest'} . '/' . $self->{_section} . '/';
			$self->{_writelog}->( "Command : " . $cmd , 3 );
			open (DATA, "$cmd 2>&1 |" ) or $status = 1;
			#read stdin
			if ( $status == 0 )
			{
				my ( $flag ) = 0;
				while ( defined ( my $line = <DATA> )  )
				{
							if ( $line =~ m/total size is/ )
							{
								$line =~ m/(\d+)/;
								my ( $num ) = $1;
								$self->{_size} += $num;
							}
					chomp($line);
					if ( $line eq "")
					{
						$flag = 0;
					};
					if ( $flag eq 1 )
					{
						if ( ( $line =~ m/rsync:/ ) or ( $line =~ m/rsync error:/ ) )
						{
							$self->{_writelog}->( $line , 3 );
						}
						else
						{
							$self->{_writelist}->( $line );
						};
					}
					else
					{
						$self->{_writelog}->( $line , 3 );
					};
					if ( $line =~/file list/ )
					{
						$flag = 1;
					};
					
				};
				close DATA;
				$status = $? >> 8;
			};
			#end read stdin
			#check exit status
			if ( $status != 0 )
			{
				if ( $status == 23 )
				{
					$self->{_writelog}->( "Some files could not be copied. " , 1 );
					$self->{_status} = 1 unless ( $self->{_status} ge 1 );
					$self->{_infotext} .= "-$source: partial transfer";
				}
				elsif ( $status == 24 )
				{
					$self->{_writelog}->( "Some files vanished before copying. " , 1 );
					$self->{_status} = 1 unless ( $self->{_status} ge 1 );
					$self->{_infotext} .= "-$source: file(s) vanished on sender side";
				}
				else
				{
					$self->{_writelog}->( "Not copied " , 1 );
					$self->{_status} = 2 unless ( $self->{_status} ge 2 );
					$self->{_infotext} .= "-$source: files not copied";
				};
			};
			#end check exit status
			$self->{_writelog}->( "Exit status : " . $status , 2 );
			# Start delete temp files
			if ( defined $self->{_param}{'mtime'} )
			{
				if ( -e $filelist )
				{
					unlink( $filelist );
				};
			}
			# End delete temp files
			}
		else
		{
			$self->{_status} = 2 unless ( $self->{_status} ge 2 );
			$self->{_writelog}->( " Source " . $source . " does not exist." , 0 );
			$self->{_infotext} .= "-$source: does not exist";
		};
		#end check if source exists
	};
	#end loop sources
	#check status
	if ( $self->{_status} == 0 )
	{
		$self->{_writelog}->( "All files copied." , 1 );
		$self->{_infotext} = "All files copied";
	}
	else
	{
		$self->{_writelog}->( "One or more errors/warning." , 1 );
	};
	#end check status
	#check if histdirs = -1
	if ( defined $self->{_param}{'histdirs'} )
	{
		#make history directories
		if ( $self->{_param}{'histdirs'} == -1 )
		{
			#create new directory for infinite history
			if ( move( $self->{_param}{'dest'} . '/' . $self->{_section} , $self->{_param}{'dest'} . '/' . $self->{_section}. '.' . $self->{_param}{'logdate'} ) )
			{
				$self->{_writelog}->( " Files moved into : " .  $self->{_param}{'dest'} . '/' . $self->{_section} . '.' . time , 0 );
			}
			else
			{
				$self->{_writelog}->( " Could not move files." , 0 );
				$self->{_status} = 1 unless ( $self->{_status} ge 1 );
			};
		};
	};
	#end check if histdirs = -1
	return( $self->{_status}, $self->{_infotext}, $self->{_size}, $self->{_destfree}, $self->{_destsize} );
};

1;
##################################################################################
#
# To parse the rsync output, I could not find a complete documentation on
# what text it prints to stdout, so I went to the sources. :-) 
#
##################################################################################
#
# Extract from rsync sources: log.c
#
#const rerr_names[] = {
#	{ RERR_SYNTAX     , "syntax or usage error" },
#	{ RERR_PROTOCOL   , "protocol incompatibility" },
#	{ RERR_FILESELECT , "errors selecting input/output files, dirs" },
#	{ RERR_UNSUPPORTED, "requested action not supported" },
#	{ RERR_STARTCLIENT, "error starting client-server protocol" },
#	{ RERR_SOCKETIO   , "error in socket IO" },
#	{ RERR_FILEIO     , "error in file IO" },
#	{ RERR_STREAMIO   , "error in rsync protocol data stream" },
#	{ RERR_MESSAGEIO  , "errors with program diagnostics" },
#	{ RERR_IPC        , "error in IPC code" },
#	{ RERR_CRASHED    , "sibling process crashed" },
#	{ RERR_TERMINATED , "sibling process terminated abnormally" },
#	{ RERR_SIGNAL1    , "received SIGUSR1" },
#	{ RERR_SIGNAL     , "received SIGINT, SIGTERM, or SIGHUP" },
#	{ RERR_WAITCHILD  , "waitpid() failed" },
#	{ RERR_MALLOC     , "error allocating core memory buffers" },
#	{ RERR_PARTIAL    , "some files/attrs were not transferred (see previous errors)" },
#	{ RERR_VANISHED   , "some files vanished before they could be transferred" },
#	{ RERR_TIMEOUT    , "timeout in data send/receive" },
#	{ RERR_CONTIMEOUT , "timeout waiting for daemon connection" },
#	{ RERR_CMD_FAILED , "remote shell failed" },
#	{ RERR_CMD_KILLED , "remote shell killed" },
#	{ RERR_CMD_RUN    , "remote command could not be run" },
#	{ RERR_CMD_NOTFOUND,"remote command not found" },
#	{ RERR_DEL_LIMIT  , "the --max-delete limit stopped deletions" }

##################################################################################
#
# Extract from rsync sources: errcode.h
#
#define RERR_OK         0
#define RERR_SYNTAX     1       /* syntax or usage error */
#define RERR_PROTOCOL   2       /* protocol incompatibility */
#define RERR_FILESELECT 3       /* errors selecting input/output files, dirs */
#define RERR_UNSUPPORTED 4      /* requested action not supported */
#define RERR_STARTCLIENT 5      /* error starting client-server protocol */

#define RERR_SOCKETIO   10      /* error in socket IO */
#define RERR_FILEIO     11      /* error in file IO */
#define RERR_STREAMIO   12      /* error in rsync protocol data stream */
#define RERR_MESSAGEIO  13      /* errors with program diagnostics */
#define RERR_IPC        14      /* error in IPC code */
#define RERR_CRASHED    15      /* sibling crashed */
#define RERR_TERMINATED 16      /* sibling terminated abnormally */

#define RERR_SIGNAL1    19      /* status returned when sent SIGUSR1 */
#define RERR_SIGNAL     20      /* status returned when sent SIGINT, SIGTERM, SIGHUP */
#define RERR_WAITCHILD  21      /* some error returned by waitpid() */
#define RERR_MALLOC     22      /* error allocating core memory buffers */
#define RERR_PARTIAL    23      /* partial transfer */
#define RERR_VANISHED   24      /* file(s) vanished on sender side */
#define RERR_DEL_LIMIT  25      /* skipped some deletes due to --max-delete */

#define RERR_TIMEOUT    30      /* timeout in data send/receive */
#define RERR_CONTIMEOUT 35      /* timeout waiting for daemon connection */

#define RERR_CMD_FAILED 124		124 if the command exited with status 255
#define RERR_CMD_KILLED 125		125 if the command is killed by a signal
#define RERR_CMD_RUN	126		126 if the command cannot be run
#define RERR_CMD_NOTFOUND 127	127 if the command is not found

##################################################################################
#
# Extract from rsync sources: generator.c
#
# rprintf(FINFO, "delete_item(%s) mode=%o flags=%d\n",
# rprintf(FINFO, "cannot delete non-empty directory: %s\n",
# rsyserr(FERROR, errno, "delete_file: %s(%s) failed",
# rprintf(FERROR_XFER, "could not make way for new %s: %s\n",
# rprintf(FINFO, "mount point, %s, pins parent directory\n",
# rprintf(FINFO, "cannot delete non-empty directory: %s\n",
# rprintf(FINFO, "NOTE: Unable to create delete-delay temp file%s.\n",
# rprintf(FERROR, "ERROR: unexpected EOF in delete-delay file.\n");
# rsyserr(FERROR, errno, "reading delete-delay file");
# rprintf(FERROR, "ERROR: invalid data in delete-delay file.\n");
# rprintf(FERROR, "ERROR: filename too long in delete-delay file.\n");
# rprintf(FINFO, "IO error encountered -- skipping file deletion\n");
# rprintf(FINFO, "cannot delete mount point: %s\n",
# rprintf(FINFO, "fuzzy size/modtime match for %s\n",
# rprintf(FINFO, "fuzzy distance for %s = %d.%05d\n",
# rsyserr(FINFO, errno, "copy_file %s => %s",
# rprintf(FERROR, "internal: try_dests_non() called with invalid mode (%o)\n",
# rsyserr(FERROR_XFER, errno, "failed to hard-link %s with %s",
# rprintf(FERROR_XFER, "skipping daemon-excluded %s \"%s\"\n",
# rsyserr(FERROR_XFER, errno, "recv_generator: mkdir %s failed",
# rprintf(FINFO, "not creating new %s \"%s\"\n",
# rsyserr(FERROR_XFER, errno, "recv_generator: mkdir %s failed",
# rsyserr(FERROR_XFER, errno, "failed to modify permissions on %s",
# rprintf(FINFO, "ignoring unsafe symlink %s -> \"%s\"\n",
# rsyserr(FERROR_XFER, errno, "symlink %s -> \"%s\" failed",
# rprintf(FINFO, "skipping non-regular file \"%s\"\n", fname);
# rprintf(FINFO, "%s is over max-size\n", fname);
# rprintf(FINFO, "%s is under min-size\n", fname);
# rprintf(FINFO, "%s is newer\n", fname);
# rprintf(FINFO, "fuzzy basis selected for %s: %s\n",
# rsyserr(FERROR_XFER, stat_errno, "recv_generator: failed to stat %s",
# rsyserr(FERROR, errno, "failed to open %s, continuing",
# rprintf(FINFO, "gen mapped %s of size %.0f\n",
# rprintf(FINFO, "generating and sending sums for %d\n", ndx);
# rprintf(FWARNING, "WARNING: file is too large for checksum sending: %s\n",
# rprintf(FWARNING, "Deletions stopped due to --max-delete limit (%d skipped)\n",
# rprintf(FINFO, "generate_files finished\n");
# 
