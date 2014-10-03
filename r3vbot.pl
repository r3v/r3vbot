#!/usr/bin/perl
# =============================================================================
#  File:        r3vbot.pl
#
#  Contains:    IRC bot written in perl, using Bot::BasicBot
#               Intended to be very simple. Mostly for !seen functionality.
#
#  Version:     v1.0.1b2
#
#  Contact:     r3v.zero@gmail.com
#
#  Change History (most recent first):
#  2014.10.01     v1.0     r3v          Cleanup & !help content.
#  2014.09.30     v0.5     r3v          Seen functionality complete.
#  2014.09.22     v0.1     r3v          Original Version.
# =============================================================================

# BUGS/FEATURES tracked here: https://github.com/r3v/r3vbot/issues

use warnings;
use strict;

package TheWatcher;
use base qw( Bot::BasicBot );
use DBI;

my $ircServer = "irc.geekshed.net";
my $port = "6697";
my $ssl = 1;   # 'usessl' option specified, but POE::Component::SSLify was not found
my @defaultChannels = [ "#r3v" ];

my $botNick = "UatuBeta";
my @botAltNicks = ["UatuBeta_", "UatuBeta__"];
my $botUsername = "r3vbot"; # 9 chars max
my $botLongName = "r3v's bot";

my $botOwner = "r3v";
my $botVersion = "1.0.1b2";

my $dbFile = "/Users/Shared/r3vbot-seen.db";
my $needToCreateTable = undef ;
my $sql = undef ;
my $dbh = undef ;

# Init stuff happens here. Check seen db existence, create if needed.
sub init {
	my $self = shift;
	print STDERR "INFO: Bot (${self}) initializing...\n";
	
	# Check for $dbFile existence, if it's not there, create it and create the table
	unless (-e $dbFile) {
		print STDERR "INFO: Creating seen databse.\n";
		$needToCreateTable = 1 ;  # Database file doesn't exist, table needs to be created
	} else {
		print "INFO: Seen database exists.\n";
		$needToCreateTable = 0 ; # Database file exists, assume table exists #TODO: Figure out how to test for existence of table
	}

	my $dsn      = "dbi:SQLite:dbname=$dbFile";
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
id       INTEGER PRIMARY KEY,
date    VARCHAR(10),
time    VARCHAR(8),
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
}

# Called when a user directs a help request specifically at the bot. I prefer !help so it
# will be handled by the said routine.
sub help { "There is no help for you, but for me... use !help or !commands to find out what I can do." }

# When a user changes nicks, this will be called. It receives two arguments: the old
# nickname and the new nickname.
sub nick_change {
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";
	my $self = shift ;
	my $oldNickname = shift ;
	my $newNickname = shift ;

	# SEENDB-FORKIT
	my $nickString = $oldNickname;
	my $rawNickString = "test\@test.org";
	my $channelString = "Unknown";  #Don't think we get this with this handler
	my $actionString = "nickchange";
	my $messageString = $newNickname;
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
}

# Called when someone joins a channel. It receives a hashref argument similar to the one
# received by said(). The key 'who' is the nick of the user who joined, while 'channel'
# is the channel they joined.
sub chanjoin {
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";
	my ($self, $message) = @_;

	# SEENDB-FORKIT	
	my $nickString = $message->{who};
	my $rawNickString = "test\@test.org";
	my $channelString = $message->{channel};
	my $actionString = "join";
	my $messageString = "join";
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	# return "Greetings.\n"; # stop greeting yourself, it's weird
	return;
}

# Called when someone joins a channel. It receives a hashref argument similar to the one
# received by said(). The key 'who' is the nick of the user who parted, while 'channel'
# is the channel they parted.
sub chanpart {
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";
	my ($self, $message) = @_;

	# SEENDB-FORKIT	
	my $nickString = $message->{who};
	my $rawNickString = "test\@test.org";
	my $channelString = $message->{channel};
	my $actionString = "part";
	my $messageString = "part";
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
	return;
}

# Called when a user that the bot can see quits IRC.
sub userquit {
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";
	my ($self, $message) = @_;

	# SEENDB-FORKIT	
	my $nickString = $message->{who};
	my $rawNickString = "test\@test.org";
	my $channelString = "Unknown";  #Don't think we get this with this handler
	my $actionString = "quit";
	my $messageString = $message->{body};
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	return;
}

# Called when a user is kicked from the channel.
sub kicked {
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";
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
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	# SEENDB-FORKIT again
	my $nickString2 = $kicker;
	my $rawNickString2 = "test\@test.org";
	my $channelString2 = $channel;
	my $actionString2 = "kicker";
	my $messageString2 = $kickee . " | " . $reason;
	my @forkitArguments2 = ( $nickString2, $dateString, $timeString, $rawNickString2, $channelString2, $actionString2, $messageString2 );
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
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";

	my $nickString = $who;
	my $rawNickString = $message->{raw_nick};
	my $channelString = $channel ;
	my $actionString = "emoted";
	my $messageString = $body;
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);

	return undef; # Otherwise it replies with the name of whomever emoted.
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
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";

	my $nickString = $who;
	my $rawNickString = $message->{raw_nick};
	my $channelString = $channel ;
	my $actionString = "said";
	my $messageString = $body;
	my @forkitArguments = ( $nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString );
	$self->forkit(run => \&newSeenEntryForkit, arguments => [@forkitArguments]);
	
	# Reply with available commands
	if (($body =~ /^\!help$/i ) || ($body =~ /^\!commands$/i)) {
		$reply = "These are the commands I am capable of... 
 !seen, !dice, !coin, !time, !date, !dt, !quit*, !join*, !part*, !channels, !owner, !version, !bugs
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
	elsif ($body =~ /^\!version$/i) {
		$reply = "I am currently version $botVersion.";
	}

	# Reply with bot's owner
	elsif (($body =~ /^\!owner$/i) || (($body =~ /^(?!\!).*\bwho.*own.*${botNick}\b/i))){
		$reply = "I belong to: $botOwner";
	}

	# Reply with bot's owner
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
		if ($who eq $botOwner)	{
			our $quitMessage = "$who requested quit.";
			print STDERR "INFO: ${quitMessage}\n";
			$dbh->disconnect;
			$self->shutdown( $self->quit_message($quitMessage) ); #BUG: quit_message not working
		} else {
			print STDERR "INFO: $who requested quit, but was denied.\n";
			$reply = "Sorry, ${who}, but right now only my owner can do that.";		
		}
	} 

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
		if ($who eq $botOwner)	{
			my $channelToJoin = $body ;
			$channelToJoin =~ s/^\!join //i;
			print STDERR "INFO: ${who} has requested I join: ${channelToJoin}\n";
			$self->join("$channelToJoin");
			$reply = "${who}: I shall join ${channelToJoin}.";						
		} else {
			print STDERR "INFO: $who requested a !join, but was denied.\n";
			$reply = "Sorry, ${who}, but right now only my owner can do that.";		
		}		
	}

	# Leave/Part a channel specified by !part or !leave
	elsif (($body =~ /^\!part #[a-z]*/i) || ($body =~ /^\!leave #[a-z]*/i)) {
		if ($who eq $botOwner)	{
			my $channelToPart = $body ;
			$channelToPart =~ s/^\!part //i;
			$channelToPart =~ s/^\!leave //i; # BUG: OOPS that was dumb!
			
			print STDERR "INFO: ${who} has requested I part: ${channelToPart}\n";
			$self->part("$channelToPart");
			$reply = "${who}: I shall part ${channelToPart}.";						
		} else {
			print STDERR "INFO: $who requested a !join, but was denied.\n";
			$reply = "Sorry, ${who}, but right now only my owner can do that.";		
		}		
	}

	# Respond if there is no channel listed to join or leave
	elsif (($body =~ /^\!join$/i) || ($body =~ /^\!part$/i) || ($body =~ /^\!leave$/i)) {
		$reply = "$who: Which channel?";
	}

	# Respond if there is channel name doesn't start with a #
	elsif (($body =~ /^\!join [a-z0-9]*/i) || ($body =~ /^\!part [a-z0-9]*/i) || ($body =~ /^\!leave [a-z0-9]*/i)) {
		$reply = "$who: Channel names are preceded by a #.";
	}

	# Returns current nick
	elsif ($body =~ /^\!nn$/i) {
		my $currentNick = $self->pocoirc->nick_name;
		$reply = "My current nick is \"${currentNick}\"";
	}
	
	# Respond if there is no nick to look for
	elsif ($body =~ /^\!seen$/i) {
		$reply = "$who: Who are you looking for?";
	}

	# Look up a user in the seen db
	elsif ($body =~ /^\!seen [A-Z0-9]+/i) {
		my $nickString = $body ;
		$nickString =~ s/^\!seen //i;
		$reply = checkSeenDatabase($nickString, $who);
	}

	# Explain how !dice command works
	elsif ($body =~ /^\!dice$/i) {
		$reply = "I'm capable of rolling up to 100 of any type of standard die. Specify using the standard format (e.g. !dice 3d6, !dice d20, etc). If you don't specify the type of die, then I will assume a d6. I'm also capable of rolling standard percentile with two separate d10 (!dice %) or any number of d100.
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
		my $diceToRoll = $body ;
		$diceToRoll =~ s/^\!dice //i;

		# figure out type of roll
		if ($diceToRoll =~ m/^[0-9]+$/) {
			$numberOfDice = $diceToRoll;
			$diceType = "6";
		} elsif ($diceToRoll =~ m/^d[0-9]+$/i) {
			$numberOfDice = "1";
			$diceType = $diceToRoll;
			$diceType =~ s/d//i;
		} elsif ($diceToRoll =~ m/^[0-9]+d[0-9]+$/i) {
			$numberOfDice = $diceToRoll;
			$numberOfDice =~ s/d[0-9]+//i;
			$diceType = $diceToRoll;
			$diceType =~ s/[0-9]+d//i;	
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
 
		 if ($numberOfDice >= 101) {
			$reply = "$who: Sorry, I'm not going to roll more than 100 dice at a time." ;
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
		#  "$who: Flipping coin..." pause... do math ... "and it is..." pause "result!" 
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

	# testing
	elsif (($body =~ /^(?!\!)/) && ($body =~ /\btest\b/)) {
		$reply = "TEST PASSED, $who. Amazing work.";
	} 
	
	# Return whatever reply we came up with.  This will occasionally be undef.
	return $reply;
}



# CUSTOM SUB-ROUTINES --------------------------------------------------------------------

# Something triggered a seen database entry...
sub newSeenEntryForkit {
	my $ArrayContents = "@_"; 
	shift ;
	my ($nickString, $dateString, $timeString, $rawNickString, $channelString, $actionString, $messageString) = @_ ;
	my $UIDString = uc $nickString ; # Change to uppercase because SQL is case-sensitive
		
	my $filecontents = `echo  \"
UIDString :     $UIDString
nickString :    $nickString
dateString :    $dateString
timeString :    $timeString
rawNickString : $rawNickString
channelString : $channelString
actionString :  $actionString
messageString : $messageString
ArrayContents : $ArrayContents

"  > /tmp/seen.r3vbot.txt`; # For troubleshooting database entries.

	$sql = "SELECT nick, rawnick, channel, action, message, date, time FROM seenDB WHERE uid=?";
	my @row = $dbh->selectrow_array($sql,undef,$UIDString);
	if (@row) { 
		# Record exists for $nickString so we should UPDATE
		$dbh->do('UPDATE seenDB SET nick=?, rawnick=?, channel=?, action=?, message=?, date=?, time=? WHERE uid=?',
			undef,
			$nickString,
			$rawNickString,
			$channelString,
			$actionString, 
			$messageString,
			$dateString,
			$timeString,
			$UIDString
		)  or die $dbh->errstr;
	} else {
		# Record does not exist for $nickString so we should INSERT 
		$dbh->do('INSERT INTO seenDB (uid, nick, rawnick, channel, action, message, date, time) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', undef, $UIDString, $nickString, $rawNickString, $channelString, $actionString, $messageString, $dateString, $timeString);
	};
}

# Somebody is nosey... 
sub checkSeenDatabase {
	my $UIDString = shift ; 
	$UIDString = uc $UIDString ; # Change to uppercase because SQL is case-sensitive
	my $who = shift ;
	my $reply = undef ;
	print STDERR "INFO: $who is looking for $UIDString \n";
	
	$sql = "SELECT nick, rawnick, channel, action, message, date, time FROM seenDB WHERE uid=?";
	my @row = $dbh->selectrow_array($sql,undef,$UIDString);

	if (@row) { 
		my ($nickString, $rawNickString, $channelString, $actionString, $messageString, $dateString, $timeString) = @row;
		# Seen db entry exists for $nickString
		# Let's see what they last did, so we know how to format the response
		if ($actionString eq "quit") {
			$reply = "I last saw $nickString on $dateString at $timeString quitting IRC. \($messageString\)"; # removed \($rawNickString\)
		} elsif ($actionString eq "join") {
			$reply = "I last saw $nickString on $dateString at $timeString joining $channelString.";	# removed \($rawNickString\)
		} elsif ($actionString eq "part") {
			$reply = "I last saw $nickString on $dateString at $timeString leaving $channelString.";	# removed \($rawNickString\)
		} elsif ($actionString eq "nickchange") {
			$reply = "I last saw $nickString on $dateString at $timeString changing nick to $messageString."; # removed \($rawNickString\)
		} elsif ($actionString eq "kickee") {
			my $kicker = $messageString ;
			$kicker =~ s/\| .*//;			
			my $reason = $messageString ;
			$reason =~ s/.* \| //;
			$reply = "I last saw $nickString on $dateString at $timeString as they were kicked from $channelString by $who. \($reason\)";	# removed \($rawNickString\)
		} elsif ($actionString eq "kicker") {
			my $kickee = $messageString ;
			$kickee =~ s/\| .*//;			
			my $reason = $messageString ;
			$reason =~ s/.* \| //;
			$reply = "I last saw $nickString on $dateString at $timeString as they kicked $kickee from $channelString. \($reason\)"; # removed \($rawNickString\)
		} elsif ($actionString eq "said") {
			$reply = "I last saw $nickString on $dateString at $timeString saying \"$messageString\""; # removed \($rawNickString\)
		} elsif ($actionString eq "emoted") {
			$reply = "I last saw $nickString on $dateString at $timeString pretending \"$messageString\""; # removed \($rawNickString\)
		} else {
			$reply = "I last saw $nickString on $dateString at $timeString."; # removed \($rawNickString\)
		};		
		#print STDERR "INFO: $reply \n" ;
	  
	} else {
		# No seen db entry for: $nickString
		$reply = "Sorry, $who, I haven't seen a \"$UIDString\". Try missed connections on craigslist.";
	};
	return $reply ;
}

# END OF SUB-ROUTINES --------------------------------------------------------------------

# Create an instance of the bot and start it running.
our $bot = TheWatcher->new(
	server => $ircServer,
	channels => @defaultChannels,
	nick => $botNick,
	alt_nicks => @botAltNicks,
	username  => $botUsername,
	name      => $botLongName,
	#ssl => $ssl,    # 'usessl' option specified, but POE::Component::SSLify was not found
	#port => $port,
);

$bot->run();

