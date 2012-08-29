use v6;

use Net::IRC::Bot;
use LWP::Simple;
use JSON::Tiny;

my $ua = LWP::Simple.new();

my $max-twitter-id;
my $base-url        = "http://search.twitter.com/search.json?q=";
my $search-criteria = "%23perl6%20OR%20%23p6p5%20OR%20%23p5p6%20OR%20%22perl%206%22";

my $nick = "cjbot";
my $chan = "#perl6";

class Help {
    multi method said($e where { $e.what ~~ /^ $nick ':' <.ws> [ '?' | 'help' | 'h'] /}) {
        $e.msg: "Run by Coke, I relay tweets about Perl 6.";
    }
}

my $bot = Net::IRC::Bot.new(
    :$nick,
    server   => 'irc.freenode.net',
    channels => $chan,
    modules  => [ Help.new ],
    debug    => True
);

my @tweets;

sub get-tweets($opts) {
    my $url = $base-url ~ $search-criteria ;
    if defined($opts) {
        $url = $url ~ "&" ~ $opts;
    }
    my $c = $ua.get( $url ); 
    return from-json($c);
}

# preload a slightly old tweet.
# TODO: remember where we left off.
{
    my $age = 1;
    my $tweets = get-tweets("rpp=$age");
    my $tweet = $tweets<results>[*-1];
    say "Adding initial tweet created: " ~ $tweet<created_at>;
    # @tweets = $tweet;
    $max-twitter-id = $tweet<id>;
}

# MuEvent is eager, so add something to save the CPU.
MuEvent::idle(
    cb => sub { sleep 30; }
);

# dump a single pending tweet, if any
MuEvent::timer(
   after => 60,
   interval => 30,
   cb       => sub {
        return unless @tweets;

        my $tweet = @tweets.shift;
        my $msg = 'https://twitter.com/' ~ $tweet<from_user> ~ '/status/' ~
            $tweet<id> ~ ' : ' ~ $tweet<text>;
        $bot.sendmsg($msg, $chan);
    }
);

# get any new tweets
MuEvent::timer(
   after => 30,
   interval => 180,
   cb       => sub {
        my $tweets = get-tweets("since_id=" ~ $max-twitter-id);
        $max-twitter-id = $tweets<max_id>;
        for $tweets<results>.reverse -> $tweet {
            say "Adding a tweet created: " ~ $tweet<created_at>;
            @tweets.push($tweet);
        }
    }
);
   

# Temporarily need both runs.
$bot.run;
MuEvent::run;
