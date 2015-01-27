use utf8;
package Zombies::Schema::Result::BankAccount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Zombies::Schema::Result::BankAccount

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<bank_account>

=cut

__PACKAGE__->table("bank_account");

=head1 ACCESSORS

=head2 player_id

  data_type: 'integer'
  is_auto_increment: 1
  is_foreign_key: 1
  is_nullable: 0

=head2 amount

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "player_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_foreign_key    => 1,
    is_nullable       => 0,
  },
  "amount",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</player_id>

=back

=cut

__PACKAGE__->set_primary_key("player_id");

=head1 RELATIONS

=head2 player

Type: belongs_to

Related object: L<Zombies::Schema::Result::Player>

=cut

__PACKAGE__->belongs_to(
  "player",
  "Zombies::Schema::Result::Player",
  { id => "player_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-27 23:47:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W2GQKY6wsb2ollO/btHg+A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
