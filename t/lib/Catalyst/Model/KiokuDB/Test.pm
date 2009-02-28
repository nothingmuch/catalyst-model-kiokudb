package # hide from PAUSE
Catalyst::Model::KiokuDB::Test;

use Catalyst qw(-Debug);

{
    package FakeLogger;

    sub clear { @{$_[0]} = () }

    sub str { join "\n", map { "$_->[0] - $_->[1]" } @{$_[0]} }

    sub AUTOLOAD {
        my $self = shift;
        my ( $method ) = ( our $AUTOLOAD =~ /(\w+)$/ );
        push @$self, [ $method => @_ ];
    }
}

our $log = bless [], "FakeLogger";

__PACKAGE__->log($log);

__PACKAGE__->setup();

__PACKAGE__

__END__
