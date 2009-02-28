package # hide from CPAN
Catalyst::Model::KiokuDB::Test::Model::KiokuDB;
use Moose;

use namespace::clean -except => 'meta';

BEGIN { extends qw(Catalyst::Model::KiokuDB) }

__PACKAGE__->config->{dsn} = "hash";

__PACKAGE__

__END__
