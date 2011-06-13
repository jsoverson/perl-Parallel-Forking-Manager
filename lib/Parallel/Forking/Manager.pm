package Parallel::Forking::Manager;

use warnings;
use strict;
use Carp;

our $VERSION = '0.01';

use Moose;
use MooseX::Forkable;

has jobs    => ( is => 'ro', isa => 'ArrayRef', writer => '_jobs', default => sub {[]});
has object  => ( is => 'rw', does => 'MooseX::Role::Forking' );
has clones  => ( is => 'rw', isa => 'Int', default => 0 );

$Parallel::Forking::Manager::SUPPRESS_WARNINGS = 0;

around 'new' => sub {
   my $NEXT = shift;
   my $CLASS = shift;

   my $self = $CLASS->$NEXT(@_);

   $self->_clone_objects if blessed $self->object && $self->clones > 0;

   return $self;
};

sub _clone_objects {
   my $self = shift;
   
   for (1..$self->clones) {
      $self->add_job($self->object->meta->clone_object($self->object));
   }
}

sub add_job {
   my $self = shift;
   my $job = shift;

   my $with_forking = 1;
   $with_forking &&= blessed $job;
   $with_forking &&= $job->can('does');
   $with_forking &&= $job->does('MooseX::Role::Forking');
   
   croak "Can not add a job that does not implement MooseX::Role::Forking. ".
         "If you want to specify forkable behavior on the fly, consider ".
        "\$manager->add_forkable(\&CODE)" if not $with_forking;

   my ($seen) = grep { $_ eq $job } @{$self->jobs};

   if ($seen) {
      carp "It seems as though the same job is being added to the management queue. ".
           "Duplicate Forking objects are ignored, clones can be made via the metaclass ".
           "clone_object method" if not _suppressed();
      return $self;
   }

   push (@{$self->jobs}, $job);

   return $self;
}

sub add_jobs {
   my $self = shift;

   foreach (@_) {
      if (ref $_ eq 'ARRAY') {
         $self->add_jobs(@$_);
      } else {
         $self->add_job($_);
      }
   }

   return $self;
}

sub add_forkable {
   my $self = shift;
   my $code = shift;

   return $self->add_job(MooseX::Forkable->new($code));
}

sub num_jobs {
   my $self = shift;

   return scalar @{$self->jobs};
}

sub run_jobs {
   my $self = shift;

   foreach my $job (@{$self->jobs}) {
      $job->run;
   }

   return $self;
}

sub abandon_filehandles {
   my $self = shift;

   foreach my $job (@{$self->jobs}) {
      $job->abandon_filehandles;
   }

   return $self;
}

sub reset_all {
   my $self = shift;

   foreach my $job (@{$self->jobs}) {
      $job->reset;
   }
   
   return $self;
}

sub free_job {
   my $self = shift;

   my $has_ended = 0;
   while (!$has_ended) {
      foreach my $job (@{$self->jobs}) {
         $has_ended = !$job->forked_pid || $job->has_ended;
         return $job if $has_ended;
      }
      sleep 1;
   }

}

sub wait {
   my $self = shift;
   my $limit = shift;

   my $time = time;

   my $has_ended = 0;
   while (!$has_ended) {
      foreach my $job (@{$self->jobs}) {
         $has_ended = $job->has_ended;
         last if not $has_ended;
      }
      last if $limit && time - $time >= $limit;
      sleep 1 unless $has_ended;
   }

   return $self;
}

sub _suppressed {
   return $Parallel::Forking::Manager::SUPPRESS_WARNINGS;
}

1;
__END__

=head1 NAME

Parallel::Forking::Manager - A class to manage multiple Forkable objects.

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

=head1 AUTHOR

Jarrod Overson, C<< <jsoverson+cpan at googlemail.com> >>

=head1 BUGS

=head1 COPYRIGHT & LICENSE

Copyright 2009 Jarrod Overson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

