package Catalyst::Model::KiokuDB;
use Moose;

use KiokuX::Model;
use Scope::Guard;
use Scalar::Util qw(weaken);
use overload ();
use Hash::Util::FieldHash::Compat qw(fieldhash);
use Carp;

sub format_table;

use namespace::clean -except => 'meta';

our $VERSION = "0.10";

extends qw(Catalyst::Model);

fieldhash my %scopes;

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;

    $self->save_scope($c) if $self->manage_scope;

    return $self->model;
}

has manage_scope => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

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

    # Don't pass Catalyst specific parameters into the model, as this will
    # break things using MX::StrictConstructor
    my %params = %$params;
    delete $params{$_} for (grep { /^_?catalyst/ } keys %params);

    $self->_model( $self->_new_model(%params) );
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

=head1 NAME

Catalyst::Model::KiokuDB - use L<KiokuDB> in your L<Catalyst> apps

=head1 SYNOPSIS

    package MyApp::Model::KiokuDB;
    use Moose;

    BEGIN { extends qw(Catalyst::Model::KiokuDB) }

    # this is probably best put in the catalyst config file instead:
    __PACKAGE__->config( dsn => "bdb:dir=root/db" );



    $c->model("kiokudb")->lookup($id);

=head1 DESCRIPTION

=head1 ATTRIBUTES

=over 4

=item manage_scope

If true (the default), C<new_scope> will be called once per request
automatically.

=item clear_leaks

If true (the default) and C<manage_scope> is also enabled, the live object set
will be cleared at the end of every request.

This also reports any leaked objects.

Note that in order to work the stash is cleared. Since this is run after C<$c>
is already destroyed this should not be an issue, but if it causes problems for
you you can disable it.

Under C<-Debug> mode statistics on loaded objects will be printed as well.

=item model_class

Defaults to L<KiokuX::Model>.

See L<KiokuX::Model> for more details. This is the proper place to provide
convenience methods for your model that are reusable outside of your
L<Catalyst> app (e.g. in scripts or model unit tests).

=back

=head1 SEE ALSO

L<KiokuDB>, L<KiokuX::Model>, L<Catalyst::Authentication::Store::Model::KiokuDB>

=head1 VERSION CONTROL

KiokuDB is maintained using Git. Information about the repository is available
on L<http://www.iinteractive.com/kiokudb/>

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

    Copyright (c) 2009 Yuval Kogman, Infinity Interactive. All
    rights reserved This program is free software; you can redistribute
    it and/or modify it under the same terms as Perl itself.

=cut
