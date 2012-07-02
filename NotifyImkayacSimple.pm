package NotifyImkayacSimple;
use strict;
use warnings;
use 5.10.0;
use base 'ZNC::Module';

use Time::Piece;
use LWP::UserAgent;

sub infof {
    print "[INFO] ", @_, "\n";
}

sub critf {
    print "[CRIT] ", @_, "\n";
}

sub description {
    "Notifify to im.kayac.com perl module for ZNC"
}

# arguments will be processed as space-separated <key>=<value> pairs
sub OnLoad {
    my $self = shift;
    my $arg  = shift;
    for my $param (split / +/, $arg) {
        my ($key, $value) = $param =~ /([^=]+)=(.*)/;
        next unless $key && $value;
        given ($key) {
            when (/(?:username|type|password|secret_key)/) {
                $self->{config}{$key} = $value;
            }
            when ('keyword') {
                $self->{config}{keywords} = [ split /,/, $value ];
            }
            default {}
        }
        infof($param);
    }

    if ($self->{config}{username} && $self->{config}{keywords}) {
        return 1;
    }
    else {
        $_[0] = 'missing mandatory parameter "username" or "keyword"';
        return 0;
    }
}

sub OnChanMsg {
    my $self = shift;
    my ($nick, $channel, $message) = @_;

    if ($self->_judge($message)) {
        $self->_notify($nick, $channel, $message);
    }

    return $ZNC::CONTINUE;
}

sub OnPrivMsg {
    my $self = shift;
    my ($nick, $message) = @_;

    if ($self->_judge($message)) {
        $self->_notify($nick, undef, $message);
    }

    return $ZNC::CONTINUE;
}

# match keywords
sub _judge {
    my $self = shift;
    my ($message) = @_;

    my $flg = 0;
    for my $keyword (@{ $self->{config}{keywords} }) {
        if ($message =~ qr/$keyword/) {
            $flg = 1;
            last;
        }
    }
    return $flg;
}

sub _notify {
    my $self = shift;
    my ($nick, $channel, $message) = @_;

    # notification message
    my $notification = sprintf '(%s) %s <%s>: %s', (
        localtime->strftime('%Y-%m-%d %T'),
        $channel ? $channel->GetName : 'privmsg',
        $nick->GetNick,
        $message,
    );
    infof("notify: $notification");

    # notify to im.kayac.com
    my $ua = LWP::UserAgent->new();
    my $res = $ua->post('http://im.kayac.com/api/post/' . $self->{config}->{username});
    $res->is_success or die $res->status_line;
    infof($res->content);
}

1;
