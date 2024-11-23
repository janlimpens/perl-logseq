package Logseq::Parser;
use v5.40;
use feature qw(class);
no warnings 'experimental::class';
use DDP;

class Logseq::Parser::Token
{
    field $type :param :reader;
    field $value :param :reader //= '';
    field $start :param :reader;
    field $is_dirty :reader = 0;

    method add_char($char) {
        $value .= $char
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

class Logseq::Parser::Line
{
    field $tokens :param :reader = [];

    method push($token) {
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

class Logseq::Parser::Document
{
    field $lines :param :reader = [];
    field $line_break :param = "\n";

    method push($line) {
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

class Logseq::Parser
{
    use Log::Any;

    field $log :param = Log::Any->get_logger();
    field %brackets = (
        '[' => ']',
        '{' => '}',
        '(' => ')',
        '<' => '>' );
    field $line_break :param = "\n";

    method parse_line($string) {
        my @chars = split(//, $string);
        # p @chars;
        my $line = Logseq::Parser::Line->new();
        my $token;
        my $in_bracket = undef;
        my $bracket_count = 0;
        for (my $i = 0; $i < @chars; $i++) {
            my $char = $chars[$i];
            my $next_char = ($i + 1) < @chars ? $chars[$i + 1] : '';
            if ($brackets{$char} && !$in_bracket) {
                $line->push($token)
                    if $token;
                $token = Logseq::Parser::Token->new(
                    type => 'bracket', value => $char, start => $i);
                $in_bracket = $char;
                $log->trace("Bracket in $char at $i");
            } elsif ($in_bracket && $brackets{$in_bracket} eq $char && !$bracket_count) {
                $token->add_char($char);
                $line->push($token);
                $token = undef;
                $in_bracket = undef;
                $log->trace("Bracket out $char at $i");
            } elsif ($char eq '#' && $next_char =~ /\w/) {
                $line->push($token)
                    if $token;
                $token = Logseq::Parser::Token->new(
                    type => 'tag', value => $char, start => $i);
                $log->trace("Tag in $char at $i");
            } elsif ($char =~ /\s/) {
                if ($token && $token->type() eq 'bracket') {
                    $token->add_char($char);
                    $log->trace("Bracket whitespace space $char at $i");
                } else {
                    $line->push($token)
                        if $token;
                    $token = Logseq::Parser::Token->new(
                        type => 'whitespace', value => $char, start => $i);
                    $log->trace("Whitespace in $char at $i");
                }
            } else { # some character, not whitespace
                if ($token && $token->type() eq 'whitespace') {
                    $line->push($token);
                    $token = undef;
                    $log->trace("Whitespace ends at $i");
                }
                if ($token && $token->type() eq 'tag') {
                    if ($char !~ /\w|_|-/) {
                        $line->push($token);
                        $token = undef;
                    }
                    $log->trace("Tag ends at $i");
                }
                $bracket_count++
                    if $in_bracket && $char eq $in_bracket;
                $bracket_count--
                    if $in_bracket && $char eq $brackets{$in_bracket};
                $token //= Logseq::Parser::Token->new(
                    type => 'word', start => $i);
                $token->add_char($char);
                $log->trace("'$char' in word at $i");
            }
            if ($token && $next_char eq '') {
                $line->push($token);
                $log->trace("End of line at $i");
            }
        }
        return $line
    }

    method parse($md) {
        my @lines =
            map { $self->parse_line($_) }
            split($line_break, $md);
        return Logseq::Parser::Document->new(lines => \@lines)
    }
}