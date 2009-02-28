package # hide from CPAN
Catalyst::Model::KiokuDB::Test::Controller::Root;
use Moose;

use Test::More;

use namespace::clean -except => 'meta';

BEGIN { extends qw(Catalyst::Controller) }

__PACKAGE__->config( namespace => '' );

our $ran;

sub insert : Local {
    my ( $self, $c ) = @_;

    ok( my $m = $c->model("KiokuDB"), "got a model" );

    isa_ok( $m, "Catalyst::Model::KiokuDB" );    

    can_ok( $m, "directory" );

    {
        my $foo = { bar => "lala" };
        $m->store( foo => $foo );
    }

    isa_ok( $m->directory, "KiokuDB" );

    $ran++;
}

sub fetch : Local {
    my ( $self, $c ) = @_;

    ok( my $m = $c->model("KiokuDB"), "got a model" );

    isa_ok( $m, "Catalyst::Model::KiokuDB" );    

    can_ok( $m, "directory" );

    {
        my $foo = $m->lookup('foo');
        is( $foo->{bar}, "lala", "correct value in loaded object" );
    }

    isa_ok( $m->directory, "KiokuDB" );

    $ran++;
}

sub leak : Local {
    my ( $self, $c ) = @_;

    ok( my $m = $c->model("KiokuDB"), "got a model" );

    isa_ok( $m, "Catalyst::Model::KiokuDB" );    

    can_ok( $m, "directory" );

    {
        my $foo = $m->lookup('foo');
        $foo->{self} = $foo;
        $foo->{bar} = "gorch";
    }

    isa_ok( $m->directory, "KiokuDB" );

    $ran++;
}

sub fresh : Local {
    my ( $self, $c ) = @_;

    ok( my $m = $c->model("KiokuDB"), "got a model" );

    isa_ok( $m, "Catalyst::Model::KiokuDB" );    

    can_ok( $m, "directory" );

    {
        my $foo = $m->lookup('foo');
        is( $foo->{bar}, "lala", "object loaded again (despite leak)" );
    }

    isa_ok( $m->directory, "KiokuDB" );

    $ran++;
}

__PACKAGE__

__END__
