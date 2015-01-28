use utf8;
package Zombies::Schema::Result::Unit;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Zombies::Schema::Result::Unit

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

=head1 TABLE: C<unit>

=cut

__PACKAGE__->table("unit");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 player_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 ingame_name

  data_type: 'text'
  is_nullable: 0

=head2 experience

  data_type: 'real'
  default_value: 0
  is_nullable: 0

=head2 health

  data_type: 'real'
  is_nullable: 0

=head2 ammo

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "player_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ingame_name",
  { data_type => "text", is_nullable => 0 },
  "experience",
  { data_type => "real", default_value => 0, is_nullable => 0 },
  "health",
  { data_type => "real", is_nullable => 0 },
  "ammo",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

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


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-28 23:51:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FeT0G539nagRHGbYVcicSQ

sub TO_JSON {
    my $self = shift;
    my $return = {
        hqID => $self->id,
        name => $self->ingame_name,
        health => $self->health,
        experience => $self->experience,
    };
    $return->{ammo} = $self->ammo if defined $self->ammo;

    return $return;
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
