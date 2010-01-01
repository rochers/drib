package external;

use Data::Dumper;

# what we can export
our @EXPORT = qw(
    @PROJECTS
);

# function map
my %mapper = (
    'yum' => \&yum,
    'pear' => \&pear,
    'pecl' => \&pecl,
  #  'cpan' => \&cpan
);

# projects
our @PROJECTS = keys %mapper;

# go 
sub _map {

    # pkg
    my $project = shift;
    my $pkg = shift;
    my $ver = shift;
    my $branch = shift;

    # execute
    $mapper{$project}($pkg,$ver,$branch);

}

sub pear {
    
    # my
    my $name = shift;
    my $ver = shift;
    my $branch = shift;

    # see if this version exist
    print `sudo pear install $name-$ver`;
    
}

sub yum {
    # my
    my $name = shift;
    my $ver = shift;
    my $branch = shift;

    print `sudo yum install $name --version=$ver`;

}

sub pecl {

    # my
    my $name = shift;
    my $ver = shift;
    my $branch = shift;

    print `sudo pecl install $name-$ver`;

}

# todo
sub cpan {

}