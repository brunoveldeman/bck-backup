#!/usr/bin/perl
# mtime.pm
# This a a bck-backup filter.
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
package Filter;
use strict;
use warnings;
no warnings 'redefine';
# Filter version
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
		_inputlist	=> shift,
		_filter		=> shift, 
		_outputlist	=> shift,
		_param		=> shift,
		_globvar	=> shift,
		_status   	=> 0,
		_infotext	=> undef,
		_required	=> {},
		_optional	=> {},
		_help	=> undef
	};
	$self->{_required} =	
				{	
					filter=>"mtime", 
					name=>"Filter files based on timestamps.", 
					inputlistlist=>"Comma separated list of sources to include. Multiple entries can be used.",
					filter=>"Filter expression",
					outputlist=>"Destination device."
				};
	$self->{_optional} = 
				{
					type=>"[mod|acc|cha] Modification time, access time or change time filter."
				};
	$self->{_help} = "Filter files on time.";
	bless( $self, $class );
	return( $self );
};
