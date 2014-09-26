#!/usr/bin/perl
# =============================================================================
#  File:        r3vbot.pl
#
#  Contains:    IRC bot written in perl, using Bot::BasicBot
#               Intended to be very simple. Mostly for !seen functionality.
#
#  Version:     v0.1
#
#  Contact:     cls@mac.com
#
#  Change History (most recent first):
#  2014.09.22     v0.1     cls          Original Version.
# =============================================================================

# TODO LIST:
# - Figure out how to use forkit - it's working, to some degree
# - Create a !seen database SQLite
# 	- should record chan join/part, quit, kick, nick_change, and last said
# - Figure out how to make SSL work using POE::Component::SSLify --- just install?
# - List of people to take high level commands from
# - Logfile to record certain bot interactions
# - Flood control
# - Move config variables into separate file.  Config::Tiny?
# - Can the Bot tell if it has OPS? Can parse channel_data for it's own name...
# - Try to talk to nickserv to use a registered name w/password from file
# BUG: Bot's own $quitMessage almost never gets displayed in IRC
# BUG: chanjoin greeting includes name at front when I don't want it.
# BUG: cannot print to STDERR from within a forkit
# BUG: apparently I don't know how to say

# http://www.drdobbs.com/web-development/writing-irc-bots-in-perl-with-botbasicbo/184416221
# http://search.cpan.org/~hinrik/Bot-BasicBot-0.89/lib/Bot/BasicBot.pm

use warnings;
use strict;

package TheWatcher;
use base qw( Bot::BasicBot );

my $server = "irc.geekshed.net";
my $port = "6697";
my $ssl = 1;   # 'usessl' option specified, but POE::Component::SSLify was not found
my @channels = [ "#Geekdrome", "#r3v" ];

my $nick = "Uatu";
my @altnicks = ["TheWatcher_", "TheWatcher__"];
my $username = "r3vbot"; # 9 chars max
my $name = "r3v's bot";

my $botOwner = "r3v";
my $botVersion = "0.1";

# Init stuff will go here. Check seen db existence, create if needed.
sub init {
	my $self = shift;
	print STDERR "INFO: Bot (${self}) initializing...\n";
}

# Called upon connecting to the server.
sub connected {
	# BUG? This actually happens after the "Trying to connect to " channel message.
	print STDERR "INFO: Connected to ${server}.\n";
}

# Called when a user directs a help request specifically at the bot. I prefer !help so it
# will be handled by the said routine.
sub help { "There is no help for you, but for me... use !help or !commands to find out what I can do." }

# When a user changes nicks, this will be called. It receives two arguments: the old
# nickname and the new nickname.
sub nick_change {
	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my $self = shift ;
	my $oldNickname = shift ;
	my $newNickname = shift ;
	my $TheRestOfTheString = @_ ;
	print STDERR "INFO: $dateTimeString - ${oldNickname} changed nickname to ${newNickname}\n";
	print STDERR "\n\n the rest: $TheRestOfTheString \n\n";
}

# Called when someone joins a channel. It receives a hashref argument similar to the one
# received by said(). The key 'who' is the nick of the user who joined, while 'channel'
# is the channel they joined.
sub chanjoin {
	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my ($self, $message) = @_;
	print STDERR "INFO: $dateTimeString - $message->{who} joined $message->{channel}.\n";
	# return "Greetings.\n"; # stop greeting yourself, it's weird
	return;
}

# Called when someone joins a channel. It receives a hashref argument similar to the one
# received by said(). The key 'who' is the nick of the user who parted, while 'channel'
# is the channel they parted.
sub chanpart {
	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my ($self, $message) = @_;
	print STDERR "INFO: $dateTimeString - $message->{who} left $message->{channel}.\n";
	return;
}

# Called when a user that the bot can see quits IRC.
sub userquit {
	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my ($who, $message) = @_;
	print STDERR "INFO: $dateTimeString - $message->{who} quit. \"$message->{body}\"\n";
	return;
}

# Called when a user is kicked from the channel.
sub kicked {
	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my ($self, $message) = @_;
	my $kicker = $message->{who} ; # Note that WHO is the KICKER and KICKED is the KICKEE.
	my $kickee = $message->{kicked} ;
	my $channel = $message->{channel} ;
	my $reason = $message->{reason} ;
	print STDERR "INFO: $dateTimeString - ${kicker} kicked ${kickee} from ${channel} for \"${reason}\"\n";
	print STDERR "self: $self \n";
	# BUG: say doesn't work
	$self->say(channel => $channel, body => "haha!");
	return "haha"; # return value isn't said to channel either
}

# Called by default whenever someone says anything that we can hear, either in a public
# channel or to us in private that we shouldn't ignore.
sub said {
	my $self = shift;
	my $message = shift;
	my $body = $message->{body};
	my $channel = $message->{channel};
	my $server = $self->{server};
	my $who = $message->{who};
	my $reply = undef;
	my $say = undef;
	my $randPct = int(rand(100)) ;
	use POSIX qw(strftime);
	my $dateString = strftime "%Y.%m.%d", localtime;
	my $timeString = strftime "%T (%Z)", localtime;
	my $dateTimeString = "${dateString}-${timeString}";
	
	# Reply with available commands
	if (($body =~ /^\!help$/i ) || ($body =~ /^\!commands$/i)) {
		$reply = "Yeah, sorry... that's not implemented yet. Yell at $botOwner.";
	}

	# Respond if the bot is greeted
	elsif ((($body =~ /^hi/i) || ($body =~ /^hello/i) || ($body =~ /^yo/i) 
     || ($body =~ /^hey/i) || ($body =~ /^greetin/i)) && ($body =~ /${nick}/i )) {
		$reply = "Hi, $who."  if ($randPct >= 0 && $randPct < 20) ;
		$reply = "Hello, $who..."  if ($randPct >= 20 && $randPct < 40) ;
		$reply = "Yo, $who!"  if ($randPct >= 40 && $randPct < 60) ;
		$reply = "Heya, $who!"  if ($randPct >= 60 && $randPct < 80) ;
		$reply = "OMG, $who! Wassup?!"  if ($randPct >= 80) ;
	}

	# Reply with bot's version
	elsif ($body =~ /^\!version$/i) {
		$reply = "I am currently version $botVersion.";
	}

	# Reply with bot's owner
	elsif (($body =~ /^\!owner$/i) || (($body =~ /^(?!\!).*\bwho.*own.*uatu\b/i))){
		$reply = "I belong to: $botOwner";
	}

	# Date and Time commands
	elsif ($body =~ /^\!time$/i ) {
		$reply = "My watch says: $timeString";
	}
	elsif ($body =~ /^\!date$/i) {
		$reply = "My calendar reads: $dateString";
	}
	elsif ($body =~ /^\!datetime$/i) {
		$reply = "It is currently: $dateTimeString";
	}
	
	# Tell the bot to quit IRC
	elsif ($body =~ /^\!quit$/i) {
		if ($who eq $botOwner)	{
			our $quitMessage = "$who requested quit.";
			print STDERR "INFO: ${quitMessage}\n";
			$self->shutdown( $self->quit_message($quitMessage) ); #BUG: quit_message not working
		} else {
			print STDERR "INFO: $who requested quit, but was denied.\n";
			$reply = "Sorry, ${who}, but right now only my owner can do that.";		
		}
	} 

	# Join a channel specified by !join
	# TODO: Be smarter about channel names
	elsif ($body =~ /^\!join #[a-z]*/i) {
		if ($who eq $botOwner)	{
			print STDERR "INFO: Caught !join command.\n";
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
	# TODO: Be smarter about channel names
	elsif (($body =~ /^\!part #[a-z]*/i) || ($body =~ /^\!leave #[a-z]*/i)) {
		if ($who eq $botOwner)	{
			print STDERR "INFO: Caught !part command.\n";
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


	# Testing - trying to get the bot to whisper back
	elsif ($body =~ /^\!whisper$/) {
		our $response = "sup";
		
		print STDERR "INFO: Caught !whisper command.\n";
		$self->say(who => $who, channel => '#r3v', body => $body);

		#$self->forkit(run => \&direct_message, who => $who, channel => 'msg', arguments => [$response]);
		#$self->forkit(run => \&direct_message, arguments => [$self, $who, $response]);
		
	} 

	# Tells the bot to issue a /command, must be owner
# 	elsif ($body =~ /^\!command \/[a-z]*/i) {
# 		if ($who eq $botOwner)	{
# 			print STDERR "INFO: Caught !command command.\n";
# 			# TODO: Put in forkit
# 			my $commandToExecute = $body ;
# 			$commandToExecute =~ s/^\!command //i;
# 			print STDERR "INFO: ${who} has requested I run: ${commandToExecute}\n";
# 
# 			$reply = $commandToExecute ; # BUG:doesn't work because it's already in a /msg
# 			
# 		} else {
# 			print STDERR "INFO: $who requested a !command, but was denied.\n";
# 			$reply = "Sorry, ${who}, but right now only my owner can do that.";		
# 		}	
# 	} 

	# For Testing Only
	elsif ($body =~ /^\!dumptruck$/) {
		if ($who eq $botOwner)	{
			print STDERR "INFO: Caught !dumptruck command.\n";
			$self->forkit(run => \&dumptruck, arguments => [$self, $who]);			
		} else {
			print STDERR "INFO: $who requested !dumptruck, but was denied.\n";
			$reply = "Sorry, ${who}, but right now only my owner can do that.";		
		}	
	} 

	# Returns current nick
	elsif ($body =~ /^\!nn$/i) {
		my $currentNick = $self->pocoirc->nick_name;
		$reply = "My current nick is \"${currentNick}\"";
	}



	# Duh
	elsif ($body =~ /^\!foo$/i) {
		$reply = "bar";
	}

	# More testing
	elsif (($body =~ /^(?!\!)/) && ($body =~ /\btest\b/)) {
		$reply = "TEST PASSED, $who. Amazing work.";
	} 
	
	# Return whatever reply we came up with.  This will occasionally be undef.
	return $reply;
}



# CUSTOM SUB-ROUTINES --------------------------------------------------------------------

# Join a channel specified by !join $chan
# Bot::BasicBot implements AUTOLOAD for sending arbitrary states to the underlying 
# POE::Component::IRC component. 

# whisper a message instead of saying it to the channel - intended for forkit use
sub direct_message {
	my $myArgs = "@_";
	shift ;
	my $self = shift ;
	my $who = shift ;
	my $body = shift ;

	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my $filecontents = `echo  \"$dateTimeString\nself: ${self}\nwho: ${who}\nbody: ${body}\nmyArgs: \'${myArgs}\'\n\n"  > /tmp/r3vbot.direct_message.txt`;


	#print STDERR "attempting to run:\n\t$self->forkit(run => \&direct_message, who => $who, channel => 'msg', arguments => [$body]);\n";

	#pass $self through?
	#TheWatcher->say(who => $who, channel => 'msg', body => $body); #BUG: $who will be empty and $body will be TheWatcher
	#$self->say(who => $who, channel => '#r3v', body => $body);
	#my $bot->say(who => $who, channel => 'msg', body => $body);
	return "foo";
}



# dumps a bunch of information to a file in /tmp for troubleshooting
sub dumptruck {
	my @myArgs = @_ ;
	my $myArgsAsString = "@myArgs";
	my $filecontents = `echo  \"\nmyArgs: \'${myArgsAsString}\'\n\n"  > /tmp/dump.r3vbot.txt`;


	# get info from pocoirc
	# my $pocoircVar = pocoirc() ;
	# my $filecontents = `echo  \"\nmyArgs: \'${myArgsAsString}\'\n\npocoirc:  \'$pocoircVar\'\n\n"  > /tmp/dump.r3vbot.txt`;
}


# END OF SUB-ROUTINES --------------------------------------------------------------------


# Create an instance of the bot and start it running.
# TheWatcher->new(
# 	server => $server,
# 	channels => @channels,
# 	nick => $nick,
# 	alt_nicks => @altnicks,
# 	username  => $username,
# 	name      => $name,
# 	#ssl => $ssl,    # 'usessl' option specified, but POE::Component::SSLify was not found
# 	#port => $port,
# )->run();

our $bot = TheWatcher->new(
	server => $server,
	channels => @channels,
	nick => $nick,
	alt_nicks => @altnicks,
	username  => $username,
	name      => $name,
	#ssl => $ssl,    # 'usessl' option specified, but POE::Component::SSLify was not found
	#port => $port,
);

$bot->run();

