#
#  Drib::Cmd::Setting
# =================================
#  (c) Copyright Travis Kuhl 2009-10
#  
#
# This is free software. You may redistribute copies of it under the terms of
# the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
# There is NO WARRANTY, to the extent permitted by law.
#

# package
package Drib::Cmd::Setting;

# version
our $VERSION => "1.0";

# packages we need
use File::Basename;
use File::Find;
use POSIX;
use Digest::MD5 qw(md5_hex);
use JSON;
use Getopt::Lucid qw( :all );
use Data::Dumper;

# drib
use Drib::Utils;

# new 
sub new {

	# get 
	my($ref,$drib) = @_;
	
	# self
	my $self = {
		
		# drib 
		'drib' => $drib,
		
		# shortcuts
		'tmp' => $drib->{tmp},
		
		# db shortcut
		'db' => new Drib::Db('settings',$drib->{var}),
		
		# commands
		'commands' => [
			{ 
				'name' => 'set',
				'help' => '', 
				'alias' => [],
				'options' => [

				]
			},
			{ 
				'name' => 'unset',
				'help' => '', 
				'alias' => [],
				'options' => [

				]
			}			
		]
		
	};

	# bless and return me
	bless($self); return $self;

}

##
## @brief parse the command line and execute proper sub
##
## @param $cmd the cammand given
## @param $opts command line opts
## @param @args list of arguments
##
sub run {

	# get some stuff
	my ($self, $cmd, $opts) = @_;
	
	# args
	my @args = @{$self->{drib}->{args}};	

	# what cmd
	if ( scalar(@args) >= 2 && ($cmd eq "set" || $cmd eq "unset") ) {
	
		# package
		my $name = shift @args;
	
		# try to get a pid
		my $pkg = $self->{drib}->parsePackageName($name);
	
			# no package
			unless ( $self->{drib}->{packages}->get($pkg->{pid}) ) {
				return {
					'code' => 404,
					'message' => "Could not find package $name"
				};
			}
			
		# set or unset the settings
		if ( $cmd eq "set" ) {
			
			# settings
			my $settings = {};
			
				# loop each arg and set
				foreach my $a ( @args ) {
					
					# get key and value
					my ($key,$val) = split(/=/,$a,2);
				
					# sett it
					$settings->{$key} = $val;
				
				}		
		
				# set them
			$resp = $self->set($pkg->{pid}, $settings);					
			
		}
		else {
			$resp = $self->unset($pkg->{pid}, \@args);
		}
	
		# list
		$self->list( $pkg->{pid} );			

		# return
		return $resp;
	
	}
	else {
	
		# pid
		my $pid = 0;
	
		# is there one cmd
		if ( scalar @args == 1 ) {
			
			# name
			my $name = shift @args;
			
			# try to get a pid
			my $pkg = $self->{drib}->parsePackageName($name);
					
				# no package
				unless ( $self->{drib}->{packages}->get($pkg->{pid}) ) {
					return {
						'code' => 404,
						'message' => "Could not find package $name"
					};
				}			
			
			# set the pid
			$pid = $pkg->{pid};
			
		}
		
		$self->list($pid);
		
		# exit out
		exit();
		
	}

	
}


##
## @brief set a package setting
##
## @param $pid package id
## @param $settings hashref of settings to set
##
sub set {

	# get
	my ($self, $pid, $settings) = @_;

	# get the current list of settings
	my $cur = $self->get($pid) || {};
	
	# num
	my $i = 0;
	
	# loop and add
	foreach my $key ( keys %$settings ) {
		if ( $key ne "" ) {
			$cur->{$key} = $settings->{$key}; $i++;
		}
	}

	# now save it 
	$self->{db}->set($pid,$cur);

	# rebuild files
	$self->_rebuild_files($pid);
	
	# rebuild setting files
	$self->_rebuild_settings_file();
			
	return {
		'code' => 200,
		'message' => "Updated $i settings for " . $self->{drib}->getFullPackageName(0,$pid)
	};

}

##
## @brief unset a package sett
##
## @param $pid package id
## @param $settings hashref of setting to unset
##
sub unset {
	
    # stuff
    my ($self, $pid, @vars) = @_;
        
    # make sure package is installed
    unless ( $self->{drib}->{packages}->get($pid) ) {
        return {
        	'code' => 404,
        	'message' => "Package is not installed"
        };
    }

    # get all settings
    my $settings = $self->get($pid);
    
    # new settings
    my $new_settings = {};
    
    # now loop through and get settings
	foreach my $key ( keys %{$settings} ) {
		unless ( in_array(@vars, $key) || $key eq "" ) {
			$new_settings->{$key} = $settings->{$key};	
		}
    }
	
    # reset settings
    $self->{db}->set($pid, $new_settings);

    # regen text files
	$self->_rebuild_files();
	
	# rebuild setting files	
	$self->_rebuild_settings_file();

	# done
	return {
		'code' => 200,
		"message" => "Settings removed!"
	}

}

##
## @brief get all settings for a package
##
## @param $pid package id
##
sub get {

    # stuff
    my ($self, $pid) = @_;

	# return
	return $self->{db}->get($pid);

}

##
## @brief add a list of settings files
##
## @param $pid package id
## @param $files settings files
##
sub files {

    # stuff
    my ($self, $pid, $files) = @_;

	# files
	$self->{db}->set($pid, $files,'files');

	# rebuild or build
	$self->_rebuild_files();

}


##
## @brief list of all settings
##
## @param $args array of argvals
##
sub list {
	
	# self
	my ($self, $pid) = @_;

    # get all settings
    my $settings = $self->{db}->all();
    
    # project 
    my $packages = 0;
    
	# first cmd
	if ( $pid ) {
		
		# set packages
		$packages = { $pid => $self->{drib}->{packages}->get($pid) };
	
	}
	
	# need to get packages
	if ( $packages == 0 ) {
		
		# all packages
		$packages = $self->{drib}->{packages}->all();
	
	}
	
    # print them
    foreach my $p ( keys %{$packages} ) {
        
        # settings
        my $s = $settings->{$p};
        
        # only show if we have at least one setting
        if ( $s != 0 && ( ref $s eq "HASH" && scalar(keys %{$s}) > 0 ) ) {
                
        	# project 
        	if ( ($pid == 0) || ( $pid != 0 && $pid eq $p ) ) {
	        
	            # print the package name            
	            msg("$packages->{$p}->{project}/$packages->{$p}->{meta}->{name}");
	              
	            # deref
				my %vals = %$s;           
	                
	            # loop and show
	            foreach my $key ( sort keys %vals ) {
	                msg(" $key: $vals{$key} ");
	            }
	            
	            msg();
	            
	        }
            
        }
        
    }

}


##
## @brief rebuild package settings files
##
## @param $pid package file
##
sub _rebuild_files {

	# get 
	my ($self, $pid) = @_;

	# get the manifest
	my $manifest = $self->{drib}->{packages}->get($pid);

    # what 
    my $files = $manifest->{set_files};
    my $settings = $self->{db}->get($pid);

    # open each file
    foreach my $item ( @{$files} ) {
            
        # file
        my $file = $item->{file};
        
        # content            
        my $content =  $item->{tmpl};
    
        # loop through each setting
        foreach my $key ( keys %{$settings} ) {
            $content =~ s/\$\($key\)/$settings->{$key}/g;
        }
        
        # write back the file
        file_put($file,$content);
    
    }

}


##
## @brief rebuild the settings txt file
##
sub _rebuild_settings_file {

	# self
	my ($self) = @_;

	# file
	$txt = "";

    # packages
	my $packages = $self->{drib}->{packages}->all();    

    # get all settings
    my $settings = $self->{db}->all();

    # print them
    foreach my $pid ( keys %{$packages} ) {
        
        # settings
        my $s = $settings->{$pid};
        
        # only show if we have at least one setting
        if ( $s != 0 && ( ref $s eq "HASH" && scalar(keys %{$s}) > 0 ) ) {
        
   
            # loop and show
            foreach my $key ( keys %{$s} ) {
                
                # key
                $keyn = $key;
                
                # replace any .
                $keyn =~ s/\./\_/g;
                
				# set it 
				$txt .= $packages->{$pid}->{project}."_".$packages->{$pid}->{meta}->{name}."__".$keyn."|".$s->{$key}."\n";
                
            }

        }
        
    }	
    
    # where is the flat settings file
    my $file = $self->{drib}->{modules}->{Config}->get('flat-settings-file') || $self->{drib}->{var}."/settings.txt";

	# save it
	file_put($file, $txt);

}