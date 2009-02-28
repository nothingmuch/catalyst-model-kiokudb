package Catalyst::Model::KiokuDB;
use Moose;

use KiokuX::Model;
use Scope::Guard;
use Scalar::Util qw(weaken);
use overload ();
use Hash::Util::FieldHash::Compat qw(fieldhash);

sub format_table;

use namespace::clean -except => 'meta';

extends qw(Catalyst::Model);

fieldhash my %scopes;

if ($Catalyst::VERSION < 5.8 && !__PACKAGE__->isa('Moose::Object')) {
    unshift our @ISA, 'Moose::Object';

    *BUILDARGS = sub {
        my ($self, $app) = @_;
        my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};
        return $self->merge_config_hashes($self->config, $arguments);
    }
}

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;

    $self->save_scope($c);

    return $self;
}

has clear_leaks => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

has model => (
    isa => "KiokuX::Model",
    is  => "ro",
    writer => "_model",
    handles => "KiokuDB::Role::API",
);

has model_class => (
    isa     => "ClassName",
    is      => "ro",
    default => "KiokuX::Model",
);

sub BUILD {
    my ( $self, $params ) = @_;

    $self->_model( $self->_new_model(%$params) );
}

sub _new_model {
    my ( $self, @args ) = @_;

    $self->model_class->new(@args);
}

sub save_scope {
    my ( $self, $c ) = @_;

    my $dir = $self->directory;

    # make sure a live object scope for this kiokudb directory exists
    $scopes{$c}{overload::StrVal($dir)} ||= do {
        my $scope = $dir->new_scope;

        if ( $self->clear_leaks ) {
            $self->setup_leak_helper($c, $scope);
        } else {
            $scope;
        }
    };
}

sub format_table {
    my @objects = @_;

    require Text::SimpleTable;
    my $t = Text::SimpleTable->new( [ 60, 'Class' ], [ 8, 'Count' ] );

    my %counts;
    $counts{ref($_)}++ for @objects;

    foreach my $class ( sort { $counts{$b} <=> $counts{$a} } keys %counts ) {
        $t->row( $class, $counts{$class} );
    }

    return $t->draw;
}

sub setup_leak_helper {
    my ( $self, $c, $scope ) = @_;

    # gotta capture this early
    my $log = $c->log;
    my $debug = $c->debug;
    my $stash = $c->stash;

    return Scope::Guard->new(sub {
        # we need to be sure all real references to the objects are cleared
        # if the stash clearing is problematic clear_leaks should be disabled
        %$stash = ();

        my $l = $scope->live_objects;

        if ( $debug ) {
            my @live_objects = $l->live_objects;

            my $msg = "Loaded " . scalar(@live_objects) . " objects:\n" . format_table(@live_objects);

            $log->debug($msg);

            @live_objects = ();
        }

        undef $scope;

        {
            # anything still live at this point is a leak
            if ( my @leaked_objects = $l->live_objects ) {
                $log->warn("leaked objects:\n" . format_table(@leaked_objects));
            }
        }

        # finally, we clear the live object set to ensure there are no problems
        # WRT immortal objects (it doesn't solve leaks but it at least keeps
        # the behavior consistent for subsequent lookups)
        $l->clear();
    });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__
