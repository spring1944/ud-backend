use utf8;
package Zombies::Schema::Result::Game;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Zombies::Schema::Result::Game

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

=head1 TABLE: C<game>

=cut

__PACKAGE__->table("game");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 spring_id

  data_type: 'text'
  is_nullable: 0

=head2 start_time

  data_type: 'integer'
  default_value: strftime('%s', 'now')
  is_nullable: 0

=head2 end_time

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "spring_id",
  { data_type => "text", is_nullable => 0 },
  "start_time",
  {
    data_type     => "integer",
    default_value => \"strftime('%s', 'now')",
    is_nullable   => 0,
  },
  "end_time",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<spring_id_unique>

=over 4

=item * L</spring_id>

=back

=cut

__PACKAGE__->add_unique_constraint("spring_id_unique", ["spring_id"]);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-28 23:51:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4i0uSu3rvo/w+QS6TrUixQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
