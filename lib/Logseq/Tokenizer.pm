package Logseq::Tokenizer;
use v5.40;
use feature qw(class);
no warnings 'experimental::class';
use DDP;

class Logseq::Tokenizer::Token
{
    field $type :param :reader;
    field $value :param :reader //= '';
    field $start :param :reader;
    field $is_dirty :reader = 0;

    method add_char($char) {
        $value .= $char;
        return
    }

    method stringify() {
        my $pos = defined($start) ? $start : '?';
        return "'$value'; $type/$pos"
    }

    method set_value($v//= '') {
        return
            if $v eq $value;
        $value = $v;
        $start = undef;
        $is_dirty = 1;
        return
    }
}

class Logseq::Tokenizer::Line
{
    field $tokens :param :reader = [];

    method add_token($token) {
        push $tokens->@*, $token;
        return
    }

    method stringify() {
        return join '', map { $_->value() } $tokens->@*
    }

    method is_dirty() {
        return grep { $_->is_dirty() } $tokens->@*
    }
}

class Logseq::Tokenizer::Document
{
    field $lines :param :reader = [];
    field $line_break :param = "\n";

    method add_line($line) {
        push $lines->@*, $line;
        return
    }

    method stringify() {
        return join $line_break, map { $_->stringify() } $lines->@*
    }

    method is_dirty() {
        return grep { $_->is_dirty() } $lines->@*
    }
}

class Logseq::Tokenizer
{
    use Log::Any;
    use constant {
        WHITESPACE => 'whitespace',
        PUNCTUATION => 'punctuation',
        TAG => 'tag',
        BRACKET => 'bracket',
        WORD => 'word'
    };
    field $log :param = Log::Any->get_logger();
    field %brackets = (
        '[' => ']',
        '{' => '}',
        '(' => ')',
        '<' => '>' );
    field $bracket_regexp = join '|', map { quotemeta($_) } (keys %brackets, values %brackets);
    field $punctuation_regexp = qr/[\.,:;?¿!…]/;
    field $line_break :param = "\n";

    method tokenize_line($string) {
        my @chars = split(//, $string);
        my $line = Logseq::Tokenizer::Line->new();
        my $token;
        my $in_bracket = undef;
        my $bracket_count = 0;
        my $add_token = sub {
            $line->add_token($token)
                if $token;
            $token = undef;
        };
        for (my $i = 0; $i < @chars; $i++) {
            my $char = $chars[$i];
            my $next_char = ($i + 1) < @chars ? $chars[$i + 1] : '';
            if ($brackets{$char} && !$in_bracket) {
                $add_token->();
                $token = Logseq::Tokenizer::Token->new(
                    type => BRACKET, value => $char, start => $i);
                $in_bracket = $char;
                $log->trace("Bracket in $char at $i");
            } elsif ($in_bracket && $brackets{$in_bracket} eq $char && !$bracket_count) {
                $token->add_char($char);
                $add_token->();
                $in_bracket = undef;
                $log->trace("Bracket out $char at $i");
            } elsif ($char eq '#' && $next_char =~ /\w/) {
                $add_token->();
                $token = Logseq::Tokenizer::Token->new(
                    type => 'tag', value => $char, start => $i);
                $log->trace("Tag in $char at $i");
            } elsif ($char =~ /\s|$punctuation_regexp/) { # whitespace or punctuation
                my $type = $char =~ /\s/ ? WHITESPACE : PUNCTUATION;
                if ($token && $token->type() eq BRACKET) {
                    $token->add_char($char);
                    $log->trace("Bracket $type $char at $i");
                } else {
                    $add_token->();
                    $token = Logseq::Tokenizer::Token->new(
                        type => $type, value => $char, start => $i);
                    $log->trace("$type char at $i");
                }
            } else { # some character, not whitespace or punctuation
                if ($token && $token->type() eq WHITESPACE) {
                    $add_token->();
                    $log->trace("Whitespace ends at $i");
                }
                if ($token && $token->type() eq TAG) {
                    if ($char !~ /\w|_|-/) {
                        $add_token->();
                    }
                    $log->trace("Tag ends at $i");
                }
                $bracket_count++
                    if $in_bracket && $char eq $in_bracket;
                $bracket_count--
                    if $in_bracket && $char eq $brackets{$in_bracket};
                $token //= Logseq::Tokenizer::Token->new(
                    type => WORD, start => $i);
                $token->add_char($char);
                $log->trace("'$char' in word at $i");
            }
            if ($token && $next_char eq '') {
                $add_token->();
                $log->trace("End of line at $i");
            }
        }
        return $line
    }

    method tokenize($md) {
        my @lines =
            map { $self->tokenize_line($_) }
            split($line_break, $md);
        return Logseq::Tokenizer::Document->new(lines => \@lines)
    }
}