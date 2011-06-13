package t::Parallel::Forking::Manager;

use strict;
use warnings;

use Test::Class;
use base 'Test::Class';

use Test::More;
use Scalar::Util qw(blessed refaddr);

use Parallel::Forking::Manager;

sub test_add_incorrect_type : Tests {
   my $manager = new Parallel::Forking::Manager;

   ok(not eval {$manager->add_jobs('a')});
   ok(not eval {$manager->add_job('a')});
   ok(not eval {$manager->add_jobs(['a'])});
   ok(not eval {$manager->add_job(['a'])});

   is($manager->num_jobs, 0);
}

sub test_add_correct_type : Tests {
   my $manager = new Parallel::Forking::Manager;

   ok($manager->add_job(SimpleForkable->new()));
   ok($manager->add_jobs(SimpleForkable->new()));
   ok($manager->add_jobs([SimpleForkable->new()]));

   is($manager->num_jobs, 3);
}

sub test_add_forkable : Tests {
   my $manager = new Parallel::Forking::Manager;

   ok($manager->add_forkable(\&sample_code));
   is($manager->num_jobs, 1);
}

sub test_multiple_adds_and_re_adds : Tests {
   my $manager = new Parallel::Forking::Manager;

   $manager->add_job(SimpleForkable->new());

   my @jobs = map { SimpleForkable->new() } (1..5);

local $Parallel::Forking::Manager::SUPPRESS_WARNINGS = 1;
   $manager->add_jobs(@jobs);
   $manager->add_jobs(\@jobs); # should not re-add them

   $manager->add_forkable(\&sample_code);

   $manager->add_forkable(sub { print 'code_ref' });

   is ($manager->num_jobs, 8);
}

sub test_runthrough : Tests {
   my $manager = Parallel::Forking::Manager->new();

   my @jobs;

   for (0..4) {
      my $job = SimpleForkable->new();
      $job->arguments($_);
      is ((@{$job->arguments}), @{[$_]});
      push (@jobs, $job);
   }

   $manager->add_jobs(@jobs);

   $manager->abandon_filehandles;

   $manager->run_jobs;

   $manager->wait;

   for (0..4) {
      ok($manager->jobs->[$_]->has_ended);
      is($manager->jobs->[$_]->exit_code, $_);
   }
}

sub test_cloned_run : Tests {
   my $object = SimpleForkable->new();

   my $manager = Parallel::Forking::Manager->new(
         object   => SimpleForkable->new(),
         clones   => 5
   );

   is ($manager->num_jobs, 5);

   foreach my $job (@{$manager->jobs}) {
      ok (not (refaddr $job == refaddr $object));
      is (blessed $job, blessed $object);
   }
   
   $manager->jobs->[$_]->arguments($_) for (0..4);

   $manager->abandon_filehandles;

   $manager->run_jobs;

   $manager->wait;

   for (0..4) {
      ok($manager->jobs->[$_]->has_ended);
      is($manager->jobs->[$_]->exit_code, $_);
   }

}

sub test_expired_wait : Tests {
   my $manager = Parallel::Forking::Manager->new();

   my $code = sub {
      sleep (20);
   };

   $manager->add_forkable($code);

   $manager->run_jobs;

   $manager->wait(1);

   ok(not $manager->jobs->[0]->has_ended);
   
   ok($manager->jobs->[0]->kill_job);

   ok($manager->jobs->[0]->has_ended);
}

sub test_incremental_runs : Tests {
   my $manager = Parallel::Forking::Manager->new();

   my @jobs;

   for (0..4) {
      my $job = SimpleForkable->new();
      $job->arguments($_);
      push (@jobs, $job);
   }

   $manager->add_jobs(@jobs);

   $manager->abandon_filehandles();

   my $i = 0;

   while (my $job = $manager->free_job) {
      if ($job->has_ended) {
         is(@{[$job->exit_code]},@{$job->arguments});
         $job->reset;
      }
      $job->arguments(++$i);
      $job->run;
      last if $i > 10;
   }

   $manager->wait;

   foreach my $job (@{$manager->jobs}) {
      ok($job->has_ended);
      is(@{[$job->exit_code]},@{$job->arguments});
   }
}

sub sample_code {
   print __PACKAGE__.'::job';
}

package SimpleForkable;
use Moose;

with 'MooseX::Role::Forking';

sub job {
   my $self = shift;
   my $rv = shift;
   print __PACKAGE__.'::job';
   return $rv;
}

1;
