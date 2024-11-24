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
);
unless ($process_tags) {
    say do { local $/; <DATA> };
    exit;
}
my %args = (
    defined($dry_run) ? (dry_run => $dry_run) : (),
    defined($dir) ? (dir => $dir) : (),
    defined($verbose) ? (verbose => $verbose) : (),
    log => $log);
if ($process_tags) {
    my $tagger = Logseq::AutoTagger->new(%args);
    $tagger->process();
}

1;

__DATA__
maintainance.pl
allows you to process logseq files in bulk
Usage:
    --tags      process tags
    --dry-run   dry run
    --dir=DIR   directory, default is current directory
    --verbose   verbose output