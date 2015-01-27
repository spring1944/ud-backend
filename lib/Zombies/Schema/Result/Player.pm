use utf8;
package Zombies::Schema::Result::Player;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Zombies::Schema::Result::Player

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

=head1 TABLE: C<player>

=cut

__PACKAGE__->table("player");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 handle

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "handle",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<handle_unique>

=over 4

=item * L</handle>

=back

=cut

__PACKAGE__->add_unique_constraint("handle_unique", ["handle"]);

=head1 RELATIONS

=head2 bank_account

Type: might_have

Related object: L<Zombies::Schema::Result::BankAccount>

=cut

__PACKAGE__->might_have(
  "bank_account",
  "Zombies::Schema::Result::BankAccount",
  { "foreign.player_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 units

Type: has_many

Related object: L<Zombies::Schema::Result::Unit>

=cut

__PACKAGE__->has_many(
  "units",
  "Zombies::Schema::Result::Unit",
  { "foreign.player_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-27 23:47:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CcdmrH5FfvRP5F8A5yCv8g

use Mojo::JSON qw(encode_json);

sub TO_JSON {
    my $self = shift;
    my $return = {
        name => $self->ingame_name,
        units => $self->units,
        money => $self->bank_account->amount,
    };

    return encode_json $return;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
