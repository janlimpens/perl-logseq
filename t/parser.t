use strict;
use warnings;
use Test2::V0;
use lib 'lib';
use Logseq::Parser;
use DDP;

# Create a new parser object
my $parser = Logseq::Parser->new();

# Test parse_line method
subtest 'parse_line' => sub {
    my %test = (
        '-' => 'word',
        'so' => 'word',
        '[[link ahoy]]' => 'bracket',
        '#some_tag' => 'tag',
        'some' => 'word',
        '*text*' => 'word',
        '{{weird stuff}}' => 'bracket',
        '[Duck Duck Go]' => 'bracket',
        '(https://duckduckgo.com)' => 'bracket',
    );
    my $line = join ' ', keys %test;
    my $parsed = $parser->parse_line($line);
    my %tokens = map { $_->value() => $_->type() } $parsed->tokens()->@*;
    for my $value (keys %test) {
        is $tokens{$value}, $test{$value}, "Token type for $value";
    }
};

subtest 'parse' => sub {
    my $document = do { local $/; <DATA> };
    my $tokens = $parser->parse($document);
    ok 1;
};

subtest 'number weirdness' => sub {
    my $text = '210 ü';
    my $parsed = $parser->parse_line($text);
    is $parsed->stringify(), $text;
    my @tokens = $parsed->tokens()->@*;
    is $tokens[0]->value(), '210';
    is $tokens[1]->value(), ' ';
    is $tokens[2]->value(), 'ü';
};

done_testing();

__DATA__

- some content typical to documents
- [[link ahoy]] is elsewhere and #aaa is a nice tag
    - *text* is also a thing
    - {{weird stuff}} happens all along
- 210 is a lot of müney