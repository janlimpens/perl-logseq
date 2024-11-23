package Logseq::AutoTagger;
use feature qw(class);
no warnings 'experimental::class';
use lib 'lib';
use Log::Any;
use Logseq::Parser;

class Logseq::AutoTagger {
    use Path::Tiny;
    use DDP;
    field $dry_run :param = 0;
    field $dir :param = Path::Tiny->cwd();
    field $verbose :param = 0;
    field $log :param = Log::Any->get_logger();

    method get_all_files($path) {
        my @children = $path->children();
        my @files =
            grep { $_->is_file() && $_->basename() =~ m/\.md$/ }
            @children;
        my @directories =
            grep { $_->is_dir() && $_->basename() !~ m/^(\.|logseq$)/ }
            @children;
        for my $dir (@directories) {
            push @files, $self->get_all_files($dir);
        }
        return @files
    }

    method process() {
        $log->info("Processing $dir for tags");
        my %files =
            map { $_->absolute() => { file => $_ } }
            $self->get_all_files(path($dir));
        my $parser = Logseq::Parser->new(log => $log);
        for my $path (keys %files) {
            my $file = $files{$path}->{file};
            my $content = path($file)->slurp();
            $files{$path}{parsed} = $parser->parse($content);
        }
        my %tags =
            map { $_ => 1 }
            map { lc $_->value() =~ s/^#//r }
            grep { $_->type() eq 'tag' }
            map { $_->tokens()->@* }
            map { $_->{parsed}->lines()->@* }
            values %files;
        for my $path (keys %files) {
            my $file = $files{$path}->{file};
            my @words =
                grep { $tags{lc $_->value()} }
                grep { $_->type() eq 'word' }
                map { $_->tokens()->@* }
                $files{$path}{parsed}->lines()->@*;
            for my $word (@words) {
                my $value = $word->value();
                $word->set_value("#$value");
                # p $word;
            }
        }
        for my $file (sort values %files) {
            my $parsed = $file->{parsed};
            next unless $parsed->is_dirty();
            my $content = $parsed->stringify();
            if ($dry_run) {
                $log->info("Would write to $file->{file}");
                $log->info($content);
            } else {
                $log->info("Writing to $file->{file}");
                $file->{file}->spew($content);
            }
        }
        return
    }
}

1;