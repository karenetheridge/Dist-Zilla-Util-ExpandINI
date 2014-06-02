use 5.008;    # pragma utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::Util::ExpandINI;

our $VERSION = '0.001000';

# ABSTRACT: Read an INI file and expand bundles as you go.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo 1.000008 qw( has );
use Dist::Zilla::Util::BundleInfo 1.001000;




































has '_data' => (
  is      => 'rw',
  lazy    => 1,
  default => sub { [] },
);

has '_reader_class' => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    require Dist::Zilla::Util::ExpandINI::Reader;
    return 'Dist::Zilla::Util::ExpandINI::Reader';
  },
  handles => {
    _read_file   => read_file   =>,
    _read_string => read_string =>,
    _read_handle => read_handle =>,
  },
);
has '_writer_class' => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    require Dist::Zilla::Util::ExpandINI::Writer;
    return 'Dist::Zilla::Util::ExpandINI::Writer';
  },
  handles => {
    _write_file   => write_file   =>,
    _write_string => write_string =>,
    _write_handle => write_handle =>,
  },
);

sub _load_file {
  my ( $self, $name ) = @_;
  $self->_data( $self->_read_file($name) );
  return;
}

sub _load_string {
  my ( $self, $content ) = @_;
  $self->_data( $self->_read_string($content) );
  return;
}

sub _load_handle {
  my ( $self, $handle ) = @_;
  $self->_data( $self->_read_handle($handle) );
  return;
}

sub _store_file {
  my ( $self, $name ) = @_;
  $self->_write_file( $self->_data, $name );
  return;
}

sub _store_string {
  my ($self) = @_;
  return $self->_write_string( $self->_data );
}

sub _store_handle {
  my ( $self, $handle ) = @_;
  $self->_write_handle( $self->_data, $handle );
  return;
}

sub filter_file {
  my ( $class, $input_fn, $output_fn ) = @_;
  my $self = $class->new;
  $self->_load_file($input_fn);
  $self->_expand();
  $self->_store_file($output_fn);
  return;
}

sub filter_handle {
  my ( $class, $input_fh, $output_fh ) = @_;
  my $self = $class->new;
  $self->_load_handle($input_fh);
  $self->_expand();
  $self->_store_handle($output_fh);
  return;
}

sub filter_string {
  my ( $class, $input_string ) = @_;
  my $self = $class->new;
  $self->_load_string($input_string);
  $self->_expand();
  return $self->_store_string;
}

sub _expand {
  my ($self) = @_;
  my @out;
  my @in = @{ $self->_data };
  while (@in) {
    my $tip = shift @in;
    if ( $tip->{name} and '_' eq $tip->{name} ) {
      push @out, $tip;
      next;
    }
    if ( $tip->{package} and $tip->{package} !~ /\A\@/msx ) {
      push @out, $tip;
      next;
    }

    # Handle bundle
    my $bundle = Dist::Zilla::Util::BundleInfo->new(
      bundle_name    => $tip->{package},
      bundle_payload => $tip->{lines},
    );
    for my $plugin ( $bundle->plugins ) {
      my $rec = { package => $plugin->short_module };
      $rec->{name}  = $plugin->name;
      $rec->{lines} = [ $plugin->payload_list ];
      push @out, $rec;
    }
  }
  $self->_data( \@out );
  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Util::ExpandINI - Read an INI file and expand bundles as you go.

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  # Write a dist.ini with a bundle anywhere you like
  my $string = <<"EOF";
  name = Foo
  version = 1.000

  [@Some::Author]
  EOF;

  path('dist.ini.meta')->spew( $string );

  # Generate a copy with bundles inlined.
  use Dist::Zilla::Util::ExpandINI;
  Dist::Zilla::Util::ExpandINI->filter_file( 'dist.ini.meta' => 'dist.ini' );
  # Hurrah, dist.ini has all the things!

=head1 DESCRIPTION

This module builds upon the previous work L<< C<:Util::BundleInfo>|Dist::Zilla::Util::BundleInfo >> ( Which can extract
configuration from a bundle in a manner similar to how dzil does it ) and integrates it with some I<very> minimal C<INI>
handling to provide a tool capable of generating bundle-free C<dist.ini> files from bundle-using C<dist.ini> files!

At present its very naïve and only keeps semantic ordering, and I've probably gotten something wrong due to cutting the
complexity of Config::MVP out of the loop.

But at this stage, bundles are the I<only> thing modified in transit.

Every thing else is practically a token-level copy-paste.

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
