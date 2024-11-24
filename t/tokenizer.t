use strict;
use warnings;
use Test2::V0;
use lib 'lib';
use Logseq::Tokenizer;
use DDP;

# Create a new Tokenizer object
my $Tokenizer = Logseq::Tokenizer->new();

# Test tokenize_line method
subtest 'tokenize_line' => sub {
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
    my $tokenized = $Tokenizer->tokenize_line($line);
    my %tokens = map { $_->value() => $_->type() } $tokenized->tokens()->@*;
    for my $value (keys %test) {
        is $tokens{$value}, $test{$value}, "Token type for $value";
    }
};

subtest 'tokenize' => sub {
    my $document = do { local $/; <DATA> };
    ok $document =~ /^- some content/;
    my $tokenized = $Tokenizer->tokenize($document);
    my $stringified = $tokenized->stringify();
    is $stringified, $document;
    ok 1;
};

subtest 'number weirdness' => sub {
    my $text = '210 ü';
    my $tokenized = $Tokenizer->tokenize_line($text);
    is $tokenized->stringify(), $text;
    my @tokens = $tokenized->tokens()->@*;
    is $tokens[0]->value(), '210';
    is $tokens[1]->value(), ' ';
    is $tokens[2]->value(), 'ü';
};

subtest 'final line break' => sub {
    my $text = "\nFlight\n\n(GRU)\n";
    my $tokenized = $Tokenizer->tokenize($text);
    is $tokenized->stringify(), $text;
};

done_testing();

__DATA__
- some content typical to documents
- [[link ahoy]] is elsewhere and #aaa is a nice tag
    - *text* is also a thing
    - {{weird stuff}} happens all along
- 210 is a lot of müney 🍗