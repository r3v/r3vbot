#!/usr/bin/perl
# =============================================================================
#  File:        r3vbot.pl
#
#  Contains:    IRC bot written in perl, using Bot::BasicBot
#               Intended to be very simple. Mostly for !seen functionality.
#
#  Version:     v1.1b4
#
#  Contact:     r3v.zero@gmail.com
#
#  BUGS/FEATURES tracked here: https://github.com/r3v/r3vbot/issues
#
# =============================================================================

use warnings;
use strict;

package TheWatcher;
use base qw( Bot::BasicBot );
use DBI;
use POE::Component::SSLify;
use Config::Simple;
use List::MoreUtils 'any';
use Time::Piece;

my $DEBUG_MODE = "0"; # TODO: Make a command line argument
my $botVersion = "1.1b4";

my $num_args= undef;

$num_args = $#ARGV + 1;
unless ($num_args > 0) {
	print "Requires a config file. Please see -help for help.\n";
	exit 1;
}
if ($num_args > 2) {
	print "Too many arguments. Please see -help for help.\n";
	exit 1;
}

my $cmdlineOption=$ARGV[0];
my $configFile=$ARGV[1];

if (($cmdlineOption eq "-h") || ($cmdlineOption eq "-help")) {
	print "Use the following commandline arguments:\n -h[elp] - this help text\n -c[onfig] <path to config file> - use the settings in the specified config file\n -n[ew] - generate a new, default config file\n";
	exit 0;
} elsif (($cmdlineOption eq "-new") || ($cmdlineOption eq "-n")) {
	#Create a new default configuration file and exit
	createDefaultConfig();
	exit 0;
} elsif  ((($cmdlineOption eq "-config") || ($cmdlineOption eq "-c")) && (!$configFile)) {
	print "Please specify a config file.\n";
	exit 1;
} elsif  ((($cmdlineOption eq "-config") || ($cmdlineOption eq "-c")) && ($configFile)) {
	# TODO: subroutine to check validity of config file
} else {
	print "I do not understand. Please see -help for help.\n";
	exit 1;
}

unless (-r $configFile) {
	print "No readable configuation file found at: $configFile.\n";
	exit 1;
} 
my $seenDatabase = undef; #CLEANUP
my $logFileFoo = undef; # TODO CHANGE VARIABLE NAME

my $seenDatabaseNameDefault="r3vbot-seen.db";
my $logFileNameDefault="r3vbot"; # followed by server name, followed by .log

my $needToCreateTable = undef ;
my $sql = undef ;
my $dbh = undef ;

# Read in from config file
my $cfg = new Config::Simple($configFile) or die "died: $! : $configFile\n" ;
my $ircServer = $cfg->param("Connection.ircServer");
my $serverPort = $cfg->param("Connection.serverPort");
my $useSSL = $cfg->param("Connection.useSSL");
my @defaultChannels = $cfg->param("Connection.defaultChannels"); # ARGH
my $botOwner = $cfg->param("BotInfo.botOwner");
my @botAdmins = $cfg->param("BotInfo.botAdmins");
my $botNick = $cfg->param("BotInfo.botNick");
my @botAltNicks = $cfg->param("BotInfo.botAltNicks");
my $botUsername = $cfg->param("BotInfo.botUsername");
my $botLongName = $cfg->param("BotInfo.botLongName");
my $chattyMode = $cfg->param("OtherConfig.chattyMode");
my $useRegisteredNick = $cfg->param("OtherConfig.useRegisteredNick");
my $NickServPassword = $cfg->param("OtherConfig.NickServPassword");
my $seenDatabasePath = $cfg->param("FileLocations.seenDatabasePath");
my $seenDatabaseName = $cfg->param("FileLocations.seenDatabaseName");
my $logFilePath = $cfg->param("FileLocations.logFilePath");
my $logFileName = $cfg->param("FileLocations.logFileName");

print STDERR "DEBUG: \$ircServer : $ircServer \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$serverPort : $serverPort \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$useSSL : $useSSL \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$botOwner : $botOwner \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$botNick : $botNick \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$botUsername : $botUsername \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$botLongName : $botLongName \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$chattyMode : $chattyMode \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$useRegisteredNick : $useRegisteredNick \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$NickServPassword : $NickServPassword \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$seenDatabasePath : $seenDatabasePath \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$seenDatabaseName : $seenDatabaseName \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$logFilePath : $logFilePath \n" if $DEBUG_MODE;
print STDERR "DEBUG: \$logFileName : $logFileName \n" if $DEBUG_MODE;
print STDERR "DEBUG: \@defaultChannels : @defaultChannels \n" if $DEBUG_MODE;
print STDERR "DEBUG: \@botAltNicks : @botAltNicks \n" if $DEBUG_MODE;
print STDERR "DEBUG: \@botAdmins : @botAdmins \n" if $DEBUG_MODE;

# TODO: check for / at end of path variable 
if ($seenDatabaseName eq "DEFAULT") {
	$seenDatabase = $seenDatabasePath . $seenDatabaseNameDefault ; 
} else {
	$seenDatabase = $seenDatabasePath . $seenDatabaseName ;
}
print STDERR "DEBUG: \$seenDatabase : $seenDatabase \n" if $DEBUG_MODE;

# TODO: check for / at end of path variable 
if ($logFileName eq "DEFAULT") {
	$logFileFoo = $logFilePath . $logFileNameDefault . "." . $ircServer . ".log" ; 
} else {
	$logFileFoo = $logFilePath . $logFileName ; 
}
print STDERR "DEBUG: \$logFileFoo : $logFileFoo \n" if $DEBUG_MODE;

# Explicitly add the owner to the admin list
unshift @botAdmins, $botOwner ;

# Init stuff happens here. Check seen db existence, create if needed.
sub init {
	my $self = shift;
	print STDERR "INFO: Bot (${self}) initializing...\n";

	# TODO : Log file stuff here.

	# Check for $seenDatabase existence, if it's not there, create it and create the table
	unless (-e $seenDatabase) {
		print STDERR "INFO: Creating seen databse.\n";
		$needToCreateTable = 1 ;  # Database file doesn't exist, table needs to be created
	} else {
		print "INFO: Seen database exists.\n";
		$needToCreateTable = 0 ; # Database file exists, assume table exists #TODO: Figure out how to test for existence of table
	}

	my $dsn      = "dbi:SQLite:dbname=$seenDatabase";
	my $user     = "";
	my $password = "";
	$dbh = DBI->connect($dsn, $user, $password, {
	   PrintError       => 0,
	   RaiseError       => 1,
	   AutoCommit       => 1,
	   FetchHashKeyName => 'NAME_lc',
	});

	if ($needToCreateTable == 1 ) {
		$sql = <<'END_SQL';
CREATE TABLE seenDB (
id      INTEGER PRIMARY KEY,
isodt   VARCHAR(19),
uid     VARCHAR(30) UNIQUE NOT NULL,
nick    VARCHAR(30),
rawnick VARCHAR(100),
channel VARCHAR(32),
action  VARCHAR(20),    
message VARCHAR(380)
)
END_SQL
		$dbh->do($sql) or die $dbh->errstr; # DBD::SQLite::db do failed: table seenDB already exists at SQLiteArgsTest.pl 
	};

	print STDERR "INFO: Initialization done.\n";
	
}

# Called upon connecting to the server.
sub connected {
	# BUG? This actually happens AFTER the "Trying to connect to " CHANNEL message.
	print STDERR "INFO: Connected to ${ircServer}.\n";
	
	if ($useRegisteredNick == 1) {
		print STDERR "INFO: Talking to NickServ to authenticate.\n";

		# bot's default nick is registered, so talk to nickserv to authenticate
		# $NickServPassword
	}	

}

# Called when a user directs a help request specifically at the bot. I prefer !help so it
# will be handled by the said routine.
sub help { "There is no help for you, but for me... use !help or !commands to find out what I can do." }

# When a user changes nicks, this will be called. It receives two arguments: the old
# nickname and the new nickname.
sub nick_change {
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my $self = shift ;
	my $oldNickname = shift ;
	my $newNickname = shift ;

	# SEENDB-FORKIT
	my $nickString = $oldNickname;
	my $rawNickString = "test\@test.org";
	my $channelString = "Unknown";  #Don't think we get this with this handler
	my $actionString = "nickchange";
	my $messageString = $newNickname;
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
}

# Called when the topic of the channel changes. It receives a hashref argument. The key
# 'channel' is the channel the topic was set in, and 'who' is the nick of the user who
# changed the channel, 'topic' will be the new topic of the channel.
sub topic {
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my $self = shift ;
	my $message = shift;

	my $who = $message->{who}; ;
	my $channel = $message->{channel}; ;
	my $newTopic = $message->{topic}; ;

	# If this is triggered when connected, $who will be empty so no seen db entry needed.
	if ($who) { 
		# SEENDB-FORKIT
		my $nickString = $who;
		my $rawNickString = "test\@test.org";
		my $channelString = $channel;  #Don't think we get this with this handler
		my $actionString = "topicchange";
		my $messageString = $newTopic;
		my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
		$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
	}
}

# Called when someone joins a channel. It receives a hashref argument similar to the one
# received by said(). The key 'who' is the nick of the user who joined, while 'channel'
# is the channel they joined.
sub chanjoin {
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my ($self, $message) = @_;

	# SEENDB-FORKIT	
	my $nickString = $message->{who};
	my $rawNickString = "test\@test.org";
	my $channelString = $message->{channel};
	my $actionString = "join";
	my $messageString = "join";
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	# return "Greetings.\n"; # stop greeting yourself, it's weird
	return;
}

# Called when someone joins a channel. It receives a hashref argument similar to the one
# received by said(). The key 'who' is the nick of the user who parted, while 'channel'
# is the channel they parted.
sub chanpart {
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my ($self, $message) = @_;

	# SEENDB-FORKIT	
	my $nickString = $message->{who};
	my $rawNickString = "test\@test.org";
	my $channelString = $message->{channel};
	my $actionString = "part";
	my $messageString = "part";
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
	return;
}

# Called when a user that the bot can see quits IRC.
sub userquit {
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my ($self, $message) = @_;

	# SEENDB-FORKIT	
	my $nickString = $message->{who};
	my $rawNickString = "test\@test.org";
	my $channelString = "Unknown";  #Don't think we get this with this handler
	my $actionString = "quit";
	my $messageString = $message->{body};
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
	return;
}

# Called when a user is kicked from the channel.
sub kicked {
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my ($self, $message) = @_;
	my $kicker = $message->{who} ; # Note that WHO is the KICKER and KICKED is the KICKEE.
	my $kickee = $message->{kicked} ;
	my $channel = $message->{channel} ;
	my $reason = $message->{reason} ;

	# SEENDB-FORKIT	
	my $nickString = $kickee;
	my $rawNickString = "test\@test.org";
	my $channelString = $channel;
	my $actionString = "kickee";
	my $messageString = $kicker . " | " . $reason;
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	# SEENDB-FORKIT again
	my $nickString2 = $kicker;
	my $rawNickString2 = "test\@test.org";
	my $channelString2 = $channel;
	my $actionString2 = "kicker";
	my $messageString2 = $kickee . " | " . $reason;
	my @forkitArguments2 = ( $nickString2, $dateTimeString, $rawNickString2, $channelString2, $actionString2, $messageString2 );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments2]);

	$self->say(channel => $channel, body => "haha!");
	return; # note return value isn't said to channel
}


# This is a secondary method that you may wish to override. It gets called when someone
# in channel 'emotes', instead of talking. In its default configuration, it will simply
# pass anything emoted on channel through to the said handler. emoted receives the same
# data hash as said.
sub emoted {
	# catching this mostly so that said ignores it, but we can add it to the seen db
	my $self = shift;
	my $message = shift;
	my $body = $message->{body};
	my $channel = $message->{channel};
	my $server = $self->{server};
	my $who = $message->{who};

	# SEENDB-FORKIT
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my $nickString = $who;
	my $rawNickString = $message->{raw_nick};
	my $channelString = $channel ;
	my $actionString = "emoted";
	my $messageString = $body;
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	return undef; # Otherwise it replies with the name of whomever emoted.
}

# Called whenever someone sends a notice instead of standard talking or emoting. Receives
# same data as said or emoted.
sub noticed {
	# catching this mostly so that said ignores it, but we can add it to the seen db
	my $self = shift;
	my $message = shift;
	my $body = $message->{body};
	my $channel = $message->{channel};
	my $server = $self->{server};
	my $who = $message->{who};

	# SEENDB-FORKIT
    my ($dateString, $timeString, $dateTimeString) = getDateTime();
	my $nickString = $who;
	my $rawNickString = $message->{raw_nick};
	my $channelString = $channel ;
	my $actionString = "notice";
	my $messageString = $body;
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	return undef;
}

# Called by default whenever someone says anything that we can hear, either in a public
# channel or to us in private that we shouldn't ignore.
sub said {
	my $self = shift;
	my $message = shift;
	my $who = $message->{who};
	my $channel = $message->{channel};
	my $server = $self->{server};
	my $body = $message->{body};
	my $reply = undef;
	my $say = undef;
	my $randPct = int(rand(100)) ;
    my ($dateString, $timeString, $dateTimeString) = getDateTime();

	my $nickString = $who;
	my $rawNickString = $message->{raw_nick};
	my $channelString = $channel ;
	my $actionString = "said";
	my $messageString = $body;
	my @forkitArguments = ( $nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
	
	my $speakerIsAdmin = any { /$who/i } @botAdmins; #Check if the person is an admin
	
	# Reply with available commands
	if (($body =~ /^\!help$/i ) || ($body =~ /^\!commands$/i)) {
		$reply = "These are the commands I am capable of... 
 !seen, !dice, !coin, !time, !date, !dt, !quit*, !join*, !part*, !channels, !owner, !admins, !version, !bugs
 Commands marked with an asterisk are only for the owner or an admin of this bot. My Read Me is available on GitHub here: <https://raw.githubusercontent.com/r3v/r3vbot/master/README.md>. Also note that I cannot private message on Geekshed in this version. This will be fixed soonish.";		
	}

	# Respond if the bot is greeted
	elsif ((($body =~ /^hi/i) || ($body =~ /^hello/i) || ($body =~ /^yo/i) 
     || ($body =~ /^hey/i) || ($body =~ /^greetin/i)) && ($body =~ /${botNick}/i )) {
		$reply = "Hi, $who."  if ($randPct >= 0 && $randPct < 30) ;
		$reply = "Hello, $who..."  if ($randPct >= 30 && $randPct < 60) ;
		$reply = "Yo, $who!"  if ($randPct >= 60 && $randPct < 77) ;
		$reply = "Heya, $who!"  if ($randPct >= 77 && $randPct < 94) ;
		$reply = "OMG, $who! Wassup?!"  if ($randPct >= 94 && $randPct < 99) ;
		$reply = "Whatever."  if ($randPct >= 99) ;		
	}

	# Reply with bot's version
	elsif ($body =~ /^\!ver(sion)?$/i) {
		$reply = "I am currently version $botVersion.";
	}

	# Reply with bot's owner
	elsif (($body =~ /^\!owner$/i) || (($body =~ /^(?!\!).*\bwho.*own.*${botNick}\b/i))){
		$reply = "I belong to: $botOwner";
	}

	# Reply with bot's admins
	elsif ($body =~ /^\!admins?$/i) {
		$reply = "The following people can give me highlevel commands: @botAdmins";
	}

	# Reply with information on bugs
	elsif ($body =~ /^\!bugs$/i){
		$reply = "A list of issues and enhancements can be found on github, here: <https://github.com/r3v/r3vbot/issues>. Someday I may do this for you via Net::GitHub."
	}

	# Date and Time commands
	elsif ($body =~ /^\!time$/i ) {
		$reply = "My watch says: $timeString";
	}
	elsif ($body =~ /^\!date$/i) {
		$reply = "My calendar reads: $dateString";
	}
	elsif (($body =~ /^\!datetime$/i) || ($body =~ /^\!dt$/i)) {
		$reply = "It is currently: $dateTimeString";
	}
	
	# Tell the bot to quit IRC
	elsif ($body =~ /^\!quit$/i) {
		if ($speakerIsAdmin ge 1) {
			our $quitMessage = "$who requested quit.";
			print STDERR "INFO: ${quitMessage}\n";
			$dbh->disconnect;
			$self->shutdown( $self->quit_message($quitMessage) ); #BUG: quit_message not working
		} else {
			print STDERR "INFO: $who requested quit, but was denied.\n";
			$reply = "Sorry, ${who}. Only an admin can do that.";		
		}
	} 

	# Tell the bot to change it's nick
	elsif ($body =~ /^\!nick [a-z0-9]/i) {
		if ($speakerIsAdmin ge 1) {
			my $newNickToUse = $body =~ s/^\!nick //ir ;		
			print STDERR "INFO: Attempting to change nick to ${newNickToUse}\n";

			#my $newNickResult = $self->pocoirc->nick($newNickToUse); # STATE only for pocoirc

		} else {
			print STDERR "INFO: $who requested bot to change it's nick, but was denied.\n";
			$reply = "Sorry, ${who}. Only an admin can do that.";		
		}
	} 


	# Tell the bot to change authenticate with NickServ






	# Return a list of channels that the bot is currently on
	elsif ($body =~ /^\!channels$/i) {
		# TODO: Clean this up, it's kind of sloppy.
		my $channelsInfo = $self->pocoirc->channels; # hashref of channels and status
		my $channelsOn = " " ; # If this starts out undef, the strict complains
		foreach (keys %$channelsInfo){
		   $channelsOn = $_ . " " . $channelsOn ;
		}
		$reply = "I'm on the following channels: $channelsOn" ;
	} 

	# Join a channel specified by !join
	elsif ($body =~ /^\!join #[a-z]*/i) {
		if ($speakerIsAdmin ge 1) {
			my $channelToJoin = $body =~ s/^\!join //ir ;		
			print STDERR "INFO: ${who} has requested I join: ${channelToJoin}\n";
			$self->join("$channelToJoin");
			$reply = "${who}: I shall join ${channelToJoin}.";						
		} else {
			print STDERR "INFO: $who requested a !join, but was denied.\n";
			$reply = "Sorry, ${who}. Only an admin can do that.";		
		}
	}

	# Leave/Part a channel specified by !part or !leave
	elsif (($body =~ /^\!part #[a-z]*/i) || ($body =~ /^\!leave #[a-z]*/i)) {
		if ($speakerIsAdmin ge 1) {
			my $channelToPart = $body =~ s/^\!(part|leave) //ir ;
			
			print STDERR "INFO: ${who} has requested I part: ${channelToPart}\n";
			$self->part("$channelToPart");
			$reply = "${who}: I shall part ${channelToPart}.";						
		} else {
			print STDERR "INFO: $who requested a !join, but was denied.\n";
			$reply = "Sorry, ${who}. Only an admin can do that.";		
		}		
	}

	elsif ($body =~ /^\!(join|part|leave [^#])/i) {
		$reply = "$who: Which channel? Channel names are preceded by a #.";
	}

	# Returns current nick, desired nicks, etc, mostly for testing
	elsif ($body =~ /^\!nn$/i) {
		my $currentNick = $self->pocoirc->nick_name;
		$self->say(channel => $channel, body => "My preferred nick is \"$botNick\"");		
		foreach (@botAltNicks) { $self->say(channel => $channel, body => "Alternate nick: \"$_\""); }
		$reply = "My current nick is \"${currentNick}\"";
	}
	
	# Respond if there is no nick to look for
	elsif ($body =~ /^\!seen$/i) {
		$reply = "$who: Who are you looking for?";
	}

	# Look up a user in the seen db
	elsif ($body =~ /^\!seen [A-Z0-9]+/i) {
		my $nickString = $body =~  s/^\!seen //ir;
		$reply = checkSeenDatabase($nickString, $who, $dateTimeString);
	}

	elsif ($body =~ /^\!chatty$/i) {
		$reply = "$who: My chatty level is 0. I'm basically a mute. To change the level, run this command again with 0-2." if ($chattyMode == 0);
		$reply = "$who: My chatty level is 1. That's the default. To change the level, run this command again with 0-2." if ($chattyMode == 1);
		$reply = "$who: My chatty level is 2. I like to talk. To change the level, run this command again with 0-2." if ($chattyMode >= 2);
	}

	elsif ($body =~ /^\!chatty [0-9]/i) {
		my $requestedChattyLevel = $body =~  s/^\!chatty //ir;
		if ($requestedChattyLevel == 0) {
			$chattyMode = 0 ;
			$reply = "$who: I know when to shup up!" ;
		} elsif ($requestedChattyLevel == 1) {
			$chattyMode = 1 ;
			$reply = "$who: Sounds good. I'll behave." ;
		} elsif ($requestedChattyLevel == 2) {
			$chattyMode = 2 ;
			$reply = "$who: Ok, but don't forget... you asked for it." ;
		} else {
			$reply = "$who: I don't think you want me at more than a 2 Try again." ;
		}
	}


	# Explain how !dice command works
	elsif ($body =~ /^\!dice$/i) {
		$reply = "I'm capable of rolling up to 50 of any type of standard die. Specify using the standard format (e.g. !dice 3d6, !dice d20, etc). If you don't specify the type of die, then I will assume a d6. I'm also capable of rolling standard percentile with two separate d10 (!dice %) or any number of d100.
If you want a 50/50 call, try !coin. Maybe someday I'll do modified rolls (e.g. !dice d20+2, !dice 3d6-1) but for now you can do your own basic math.";
	} 	

	# Roll some dice
	elsif ($body =~ /^\!dice [0-9d]*/i) {
		# if $diceToRoll is a number, roll that number of d6
		# if $diceToRoll is % or %% then roll 1d10 for 1st digit and 1d10 for 2nd digit
		# if d<diceType> is detected, make sure dieType is 4, 6, 8, 10, 12, 20, 100
		# if $diceToRoll is d<diceType> then roll 1 of that die
		# if $diceToRoll is in the form of <numberOfDice>d<diceType> roll that

		my $diceType = undef ;
		my $numberOfDice = undef ;
		my $percentileRoll = 0 ;
		my $diceToRoll = $body =~ s/^\!dice //ir;

		# figure out type of roll
		if ($diceToRoll =~ m/^[0-9]+$/) {
			$numberOfDice = $diceToRoll;
			$diceType = "6";
		} elsif ($diceToRoll =~ m/^d[0-9]+$/i) {
			$numberOfDice = "1";
			$diceType = $diceToRoll =~ s/d//ir;
		} elsif ($diceToRoll =~ m/^[0-9]+d[0-9]+$/i) {
			$numberOfDice = $diceToRoll =~ s/d[0-9]+//ir;
			$diceType = $diceToRoll =~ s/[0-9]+d//ir;	
		} elsif ($diceToRoll =~ m/^%+$/i) {
			# Special case, need to roll percentile
			$percentileRoll = "1";
			$numberOfDice = "2";
			$diceType = "10";
		} else {
			$reply = "$who: Sorry, what? Type !dice on it's own to learn more about the command.\n" ; 
			return $reply ;
		}

		unless (($diceType eq "4") || ($diceType eq "6") || ($diceType eq "8")
			|| ($diceType eq "10") || ($diceType eq "12")
			|| ($diceType eq "20") || ($diceType eq "100")) {
			$reply = "$who: Sorry, I'm not aware of any dice that have $diceType sides." ;
			return $reply ;
		 }
 
		 if ($numberOfDice >= 51) {
			$reply = "$who: Sorry, I'm not going to roll more than 50 dice at a time." ;
			return $reply ;
		 }
 
		 if ($percentileRoll eq 0) {
			# Not percentile roll format.
			if ($numberOfDice eq 1) {
				my $diceResult = int(rand($diceType)) ;
				$diceResult = $diceResult + 1 ;			
				$reply = "$who: I rolled ${numberOfDice}d${diceType} for you and got: $diceResult" ;
			} else {
				my $individualDiceRolls = "0";
				my $diceTotal = 0;
				# repeat for $numberOfDice
				for (my $i = 0; $i < $numberOfDice; $i++) {
					my $diceResult = int(rand($diceType)) ;
					$diceResult = $diceResult + 1 ;
					# add it to total, and add it to string keeping track of rolls
					$diceTotal  = $diceTotal + $diceResult ;
					if ($individualDiceRolls eq "0") {
						$individualDiceRolls = $diceResult ;  # BUG			
					} else {
						$individualDiceRolls = $individualDiceRolls . ", " . $diceResult ;  # BUG
					}
				}
				$reply = "$who: I rolled ${numberOfDice}d${diceType} for you and got: $diceTotal ($individualDiceRolls)" ;
			}
	
		 } else {
			# Percentile roll format.
			my $diceResultDark = int(rand($diceType)) ;
			$diceResultDark = $diceResultDark ;
			my $diceResultLight = int(rand($diceType)) ;
			$diceResultLight = $diceResultLight ;

			if (($diceResultDark == 0) && ($diceResultLight == 0)) {
				$reply = "$who: I rolled 2d10 for percentile and got: 100 (Dark die: ${diceResultDark}, light die:${diceResultLight})" ;
			} else {
				$reply = "$who: I rolled 2d10 for percentile and got: ${diceResultDark}${diceResultLight} (Dark die: ${diceResultDark}, light die:${diceResultLight})" ;
			}
		 }
	} 

	# Flip a coin  #TODO: ability to e.g. !callit heads
	elsif (($body =~ /^\!coin$/i) || ($body =~ /^\!coinflip$/i) || ($body =~ /^\!cointoss$/i)) {
		$self->say(channel => $channel, body => "$who: Flipping coin...");
		my $coinFlip = int(rand(2)) ;
		my $coinSide = undef ;
		if ($coinFlip == 0) {
			$coinSide = "Heads";
		} else {
			$coinSide = "Tails";		
		}
		$reply = "$who: ...and the result is: $coinSide";
	} 	

	# Respond if the bot is thanked
	elsif (($body =~ /^(t[h']anks|tha?n?x|thank [y|u]|)/i) && ($body =~ /${botNick}/i )) {
		$reply = "You're welcome, $who."  if ($randPct >= 0 && $randPct < 30) ;
		$reply = "No problem, $who."  if ($randPct >= 30 && $randPct < 60) ;
		$reply = "No prob, $who."  if ($randPct >= 60 && $randPct < 77) ;
		$reply = "np, $who"  if ($randPct >= 77 && $randPct < 94) ;
		$reply = "No sweat, $who"  if ($randPct >= 94 && $randPct < 99) ;
		$reply = "Whatever."  if ($randPct >= 99) ;		
	}

	# testing
	elsif (($body =~ /^(?!\!)/) && ($body =~ /\btest\b/)) {
		$reply = "TEST PASSED, $who. Amazing work.";
	} 

	# testing	
	elsif ($body =~ /^\!fs .*/i) {		
		$body =~ s/^\!fs //i;
		my @forkitArguments = ( $who, $channel, $body );
		$self->forkit(run => \&sayForkit, arguments => [@forkitArguments]);
		$reply = "Trying to run sayForkit.";
	}
	
	
	# Return whatever reply we came up with.  This will occasionally be undef.
	return $reply;
}


# CUSTOM SUB-ROUTINES --------------------------------------------------------------------

# Something triggered a seen database entry...
sub newSeenEntryForkit {
	my $ArrayContents = "@_"; 
	shift ;
	my ($nickString, $dateTimeString, $rawNickString, $channelString, $actionString, $messageString) = @_ ;
	my $UIDString = uc $nickString ; # Change to uppercase because SQL is case-sensitive
		
	my $filecontents = `echo  \"
UIDString :     $UIDString
nickString :    $nickString
isodt :         $dateTimeString
rawNickString : $rawNickString
channelString : $channelString
actionString :  $actionString
messageString : $messageString
ArrayContents : $ArrayContents

"  > /tmp/seen.r3vbot.txt`; # For troubleshooting database entries.

	$sql = "SELECT nick, rawnick, channel, action, message, isodt FROM seenDB WHERE uid=?";
	my @row = $dbh->selectrow_array($sql,undef,$UIDString);
	if (@row) { 
		# Record exists for $nickString so we should UPDATE
		$dbh->do('UPDATE seenDB SET nick=?, rawnick=?, channel=?, action=?, message=?, isodt=? WHERE uid=?',
			undef,
			$nickString,
			$rawNickString,
			$channelString,
			$actionString, 
			$messageString,
			$dateTimeString,
			$UIDString
		)  or die $dbh->errstr;
	} else {
		# Record does not exist for $nickString so we should INSERT 
		$dbh->do('INSERT INTO seenDB (uid, nick, rawnick, channel, action, message, isodt) VALUES (?, ?, ?, ?, ?, ?, ?)', undef, $UIDString, $nickString, $rawNickString, $channelString, $actionString, $messageString, $dateTimeString);
	};
}

# Somebody is nosey... 
sub checkSeenDatabase {
	my $UIDString = shift ; 
	$UIDString = uc $UIDString ; # Change to uppercase because SQL is case-sensitive
	my $who = shift ;
	my $dateTimeStringNow = shift ;
	my $reply = undef ;
	print STDERR "INFO: $who is looking for $UIDString \n";
	
	$sql = "SELECT nick, rawnick, channel, action, message, isodt FROM seenDB WHERE uid=?";
	my @row = $dbh->selectrow_array($sql,undef,$UIDString);

	if (@row) { 
		my ($nickString, $rawNickString, $channelString, $actionString, $messageString, $dateTimeString) = @row;
		# Seen db entry exists for $nickString

my $dateTimeThen = Time::Piece->strptime($dateTimeString, '%Y-%m-%dT%H:%M:%S');
my $dateTimeNow = Time::Piece->strptime($dateTimeStringNow, '%Y-%m-%dT%H:%M:%S');
my $timeDiff = $dateTimeNow - $dateTimeThen ;
my $timeSince = $timeDiff->pretty ;

		# Let's see what they last did, so we know how to format the response
		if ($actionString eq "quit") {
			$reply = "I last saw $nickString $timeSince ago quitting IRC. \($messageString\)";
		} elsif ($actionString eq "join") {
			$reply = "I last saw $nickString $timeSince ago joining $channelString.";
		} elsif ($actionString eq "part") {
			$reply = "I last saw $nickString $timeSince ago leaving $channelString.";
		} elsif ($actionString eq "nickchange") {
			$reply = "I last saw $nickString $timeSince ago changing nick to $messageString.";
		} elsif ($actionString eq "topicchange") {
			$reply = "I last saw $nickString $timeSince ago changing $channelString\'s topic to \"$messageString\".";
		} elsif ($actionString eq "kickee") {
			my $kicker = $messageString ;
			$kicker =~ s/\| .*//;			
			my $reason = $messageString ;
			$reason =~ s/.* \| //;
			$reply = "I last saw $nickString $timeSince ago as they were kicked from $channelString by $who. \($reason\)";
		} elsif ($actionString eq "kicker") {
			my $kickee = $messageString ;
			$kickee =~ s/\| .*//;			
			my $reason = $messageString ;
			$reason =~ s/.* \| //;
			$reply = "I last saw $nickString $timeSince ago as they kicked $kickee from $channelString. \($reason\)";
		} elsif ($actionString eq "said") {
			$reply = "I last saw $nickString $timeSince ago saying \"$messageString\".";
		} elsif ($actionString eq "emoted") {
			$reply = "I last saw $nickString $timeSince ago emoting \"$messageString\".";
		} elsif ($actionString eq "notice") {
			$reply = "I last saw $nickString $timeSince ago sending the notice \"$messageString\".";
		} else {
			$reply = "I last saw $nickString $timeSince ago.";
		};		
	} else {
		# No seen db entry for: $nickString
		$reply = "Sorry, $who, I haven't seen a \"$UIDString\". Try missed connections on craigslist.";
	};
	return $reply ;
}

# the -new commandline option was used, so write a default config file
sub createDefaultConfig {
	my $defaultConfigFile = "Default.cfg";
	open(DEFCONF,">$defaultConfigFile") or die "Failed to create $defaultConfigFile. $!";
	print DEFCONF "# r3vbot.pl configuration file\n";
	print DEFCONF "\n";
	print DEFCONF "[Connection]\n";
	print DEFCONF "ircServer=SERVER.NAME.HERE\n";
	print DEFCONF "defaultChannels=#COMMA,#SEPARATED,#LIST\n";
	print DEFCONF "serverPort=6667\n";
	print DEFCONF "useSSL=0\n";
	print DEFCONF "\n";
	print DEFCONF "[BotInfo]\n";
	print DEFCONF "botOwner=YOUR_NICK_HERE\n";
	print DEFCONF "botAdmins=COMMA,SEPARATED,LIST\n";
	print DEFCONF "botNick=YOUR_BOTS_NAME_HERE\n";
	print DEFCONF "botAltNicks=YOUR_BOTS_NAME_HERE_,YOUR_BOTS_NAME_HERE__\n";
	print DEFCONF "botUsername=NINE_CHARACTERS_OR_LESS\n";
	print DEFCONF "botLongName=YOUR_BOTS_DESCRIPTION_HERE\n";
	print DEFCONF "\n";
	print DEFCONF "[OtherConfig]\n";
	print DEFCONF "chattyMode=1\n";
	print DEFCONF "useRegisteredNick=0\n";
	print DEFCONF "NickServPassword=NICKSERV_PASSWORD_HERE\n";
	print DEFCONF "\n";
	print DEFCONF "[FileLocations]\n";
	print DEFCONF "seenDatabasePath=/Users/Shared/\n";
	print DEFCONF "seenDatabaseName=DEFAULT\n";
	print DEFCONF "logFilePath=/Users/Shared/\n";
	print DEFCONF "logFileName=DEFAULT\n";
	close(DEFCONF);
	print "$defaultConfigFile has been created. See README.MD for instructions on how to edit it.\n"
}

# return the date and time
sub getDateTime {
	my $dateTimeNow = Time::Piece->new;
 	my $dateString = $dateTimeNow->date;
 	my $timeString = $dateTimeNow->hms;
 	my $dateTimeString = $dateTimeNow->datetime;
	return ($dateString, $timeString, $dateTimeString);
}


# Testing
sub sayForkit {
	shift ;
	my ($who, $channel, $textToSay) = @_ ;

	print STDOUT "who: $who";
	print STDOUT "channel: $channel";
	print STDOUT "textToSay: $textToSay";

	print "who: $who";	
	
}

# END OF SUB-ROUTINES --------------------------------------------------------------------

# Create an instance of the bot and start it running.
our $bot = TheWatcher->new(
	server => $ircServer,
	channels => \@defaultChannels,
	nick => $botNick,
	alt_nicks => \@botAltNicks,
	username  => $botUsername,
	name      => $botLongName,
	ssl => $useSSL,  
	port => $serverPort,
);

$bot->run();