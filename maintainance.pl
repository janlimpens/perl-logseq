#/usr/bin/env perl
use v5.40;
package Maintainance;
use Getopt::Long;
use Log::Any;
use Log::Any::Adapter ('Stdout', log_level => $ENV{LOG_LEVEL} // 'info');
use lib 'lib';
use Logseq::AutoTagger;
my $log = Log::Any->get_logger();

GetOptions(
    'tags' => \my $process_tags,
    'dry-run' => \my $dry_run,
    'dir=s' => \my $dir,
    'verbose' => \my $verbose,
) or die "Usage: $0 --tags\n";
my %args = (
    defined($dry_run) ? (dry_run => $dry_run) : (),
    defined($dir) ? (dir => $dir) : (),
    defined($verbose) ? (verbose => $verbose) : (),
    log => $log);
if ($process_tags) {
    my $tag = Logseq::AutoTagger->new(%args);
    $tag->process();
}

1;
