#!/usr/bin/perl -w
#####################################################################
#
# autossh4 -- automated SSH logins using autossh.autossh dump files
#
# Updated 2012 - James Otting
# This is heavily based on work by Greg, Kevin, Lee, and Jackson.
#
# Updated 2016 - Kenneth Smith
# Fixed compatibility with server tabs that were added for pacha/macha.
#
#
# NOTE: This script EXPLICITLY DISABLES host key checking!
#       Use when appropriate!
#
#####################################################################
use strict;
use JSON::PP;
use File::Slurp;

$| = 1;

my @sshexpects = (
    90,
    [ 'No such file or directory',  sub { &fail("WTF? SSH missing"); } ],
    [ 'REMOTE HOST IDENTIFICATION', sub { &fail("Hax0red... or the hostkey just changed."); } ],
    [ 'Name or service not known',  sub { &fail("Return to sender, hostname unknown."); } ],
    [ 'Connection closed',          sub { &fail("How rude, the connection was closed."); } ],
    [ 'No route to host',           sub { &fail("You no can haz route."); } ],
    [ 'Connection refused',         sub { &fail("No SSH for you, connnection refused."); } ],
    [   'Permission denied',
        sub { &fail("I am the Gatekeeper! Are you the Keymaster? Zuul demands a key!"); }
    ],
    [ '-re', 'timed?\s?out', sub { &fail("All that waiting for nothing, timed out."); } ],
);

my $pacha_conf = "$ENV{HOME}/.autossh_pacha";
my $pachahost  = "pacha";
unless ( -r $pacha_conf ) {

    # Comment out the following line to skip Sagan.
    fail(
        "~/.autossh_pacha not found.\nCreate it with the following template:\n\n~/.ssh/id_rsa\npachauser\n\n"
    );
}

# $rcremote is a flat file containing a set of commands to run once logged
# into a server. input with read may or may not be successful
# you can change this to what you want, I figure ~ would be a good place
my $rcremote = "$ENV{HOME}/.rc_remote";
unless ( -r $rcremote ) {
    print "\n~/.rc_remote not found, creating a new one...\n";
    open( RCREMOTE, ">", $rcremote );
    close(RCREMOTE);
}

my $autossh = "";
if ( defined $ARGV[0] ) {
    $autossh = $ARGV[0];
}
else {
    fail("Usage: autossh4.pl filename.autossh");
}

my $expectok = 0;
eval {
    require Expect;
    import Expect;
    $expectok = 1;
};
if ( !$expectok ) {
    fail("Please install the Expect perl module!");
}

unless ( -r $autossh ) { &fail("$autossh\: file not found..."); }

my $autossh_config_ref = eval { JSON::PP::decode_json( read_file($autossh) ) };
if ($@) {
    die("Failed to parse JSON in file $autossh\n");
}
my $ticket_id  = $autossh_config_ref->{ticket_id};
my $server_num = $autossh_config_ref->{server_num};

my $exp;
my $got_pacha;

pacha_connect();
$exp->send("ticket $ticket_id $server_num ; exit\n");

# Things should be good at this point...

# WINdow size CHanged (WINCH) signal propagation
$exp->slave->clone_winsize_from( \*STDIN );

sub pacha_connect {
    print "\nConnecting to $pachahost\.cpanel.net...\n";
    open( my $pacha_fh, "<", $pacha_conf );
    local $/ = 1;
    my ( $privatekey, $pachauser ) = split( /\n/, readline($pacha_fh) );
    chomp($privatekey);
    chomp($pachauser);
    $privatekey =~ s/\~/$ENV{HOME}/;
    close($pacha_fh);
    if ( !-r $privatekey || $pachauser eq "" ) { &fail("~/autossh_pacha format invalid"); }

    my @SSHCMD_pacha = ( "ssh", "-C", "-i", "$privatekey", "$pachauser\@$pachahost\.cpanel.net" );

    $exp = new Expect();

    #$exp->log_file("/tmp/expect.log", "w");
    $exp->spawn(@SSHCMD_pacha);
    $exp->expect(
        @sshexpects,
        [   '-re',
            'id_[dr]sa\'\:',
            sub {
                $exp->interact( \*STDIN, '\n' );
                $exp->send("\n");
                Expect::exp_continue();
            }
        ],
        [   '-re',
            '\.key\'\:',
            sub {
                $exp->interact( \*STDIN, '\n' );
                $exp->send("\n");
                Expect::exp_continue();
            }
        ],
        [ 'assword:', sub { fail("Umm... your key was rejected by Sagan\n"); } ],
        [ '-re', '\]\s?', sub { $got_pacha = 1 } ],
        [ '-re', '\$\s?', sub { $got_pacha = 1 } ],
        [ '-re', '\#\s?', sub { $got_pacha = 1 } ],
        [ '-re', '\%\s?', sub { $got_pacha = 1 } ]
    );
    if ( !$got_pacha ) { fail("Blast! Couldn't get Pacha access.") }
}

sub winch {
    $exp->slave->clone_winsize_from( \*STDIN );
    kill WINCH => $exp->pid if $exp->pid;
    $SIG{WINCH} = \&winch;
}
$SIG{WINCH} = \&winch;    # best strategy

print "Waiting for 'ready for cPanel support'\n";

$exp->expect( 20, 'ready for cPanel support' );

if ( -r "$rcremote" ) {
    my ( $myrc, $line );
    open $myrc, "<", $rcremote;
    foreach $line (<$myrc>) {
        chomp($line);
        if ( $line ne '' ) {
            $exp->send("$line\n");
            $exp->expect( 90, '-re', '\]\s?', '-re', '\$\s?', '-re', '\#\s?', '-re', '\%\s?', 'eof',
                "\n" );
        }
    }
}

$exp->interact();
exit 0;

sub fail {
    print "\n$_[0]\nPress ENTER to exit.\n";
    my $line = <STDIN>;
    exit 1;
}

sub bork {
    print "\n$_[0]\n Autopilot: Disengaged!\n";
    $exp->send("\n");
    $exp->interact();
    exit 0;
}

