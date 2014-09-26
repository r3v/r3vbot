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

# BUGS/FEATURES tracked here: https://github.com/r3v/r3vbot/issues

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
	# BUG? This actually happens AFTER the "Trying to connect to " CHANNEL message.
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
	my $TheRestOfTheString = @_ ; #CLEANUP
	# SEENDB-FORKIT
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
	# SEENDB-FORKIT
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
	# SEENDB-FORKIT
	print STDERR "INFO: $dateTimeString - $message->{who} left $message->{channel}.\n";
	return;
}

# Called when a user that the bot can see quits IRC.
sub userquit {
	use POSIX qw(strftime);
	my $dateTimeString = strftime "%Y.%m.%d-%T", localtime;
	my ($who, $message) = @_;
	# SEENDB-FORKIT	
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
	# SEENDB-FORKIT	
	print STDERR "INFO: $dateTimeString - ${kicker} kicked ${kickee} from ${channel} for \"${reason}\"\n";
	#CLEANUP print STDERR "self: $self \n";
	$self->say(channel => $channel, body => "haha!");
	return; # note return value isn't said to channel
}

# TICK is called after a certain amount of time passed as defined by the return value.
# sub tick {
# 	my $self = shift;
# 	$self->say(
# 		channel => "#r3v",
# 		body => "The time is now ".scalar(localtime),
# 		);
# 	return 60; # wait 1 minute before another tick event.
# }

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
# 	$self->say(
# 		who => $who, 
# 		channel => $channel,
# 		body => "I saw \"$who\" emote \"$body\"",
# 	);
	# SEENDB-FORKIT
	return undef; # Otherwise it replies with the name of whomever emoted.
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
	# SEENDB-FORKIT
	
	# Reply with available commands
	if (($body =~ /^\!help$/i ) || ($body =~ /^\!commands$/i)) {
		$reply = "Yeah, sorry... that's not implemented yet. Yell at $botOwner.";
	}

	# Respond if the bot is greeted
	elsif ((($body =~ /^hi/i) || ($body =~ /^hello/i) || ($body =~ /^yo/i) 
     || ($body =~ /^hey/i) || ($body =~ /^greetin/i)) && ($body =~ /${nick}/i )) {
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

	# Returns current nick
	elsif ($body =~ /^\!nn$/i) {
		my $currentNick = $self->pocoirc->nick_name;
		$reply = "My current nick is \"${currentNick}\"";
	}




	# BOOKMARK - Testing trying to get the bot to whisper back
	# https://github.com/r3v/r3vbot/issues/1
	elsif ($body =~ /^\!whisper$/) {
		our $response = "sup";
		
		print STDERR "INFO: Caught !whisper command.\n"; #CLEANUP

		$self->say(
			who => $who, 
			channel => $channel,
			body => "I'm going to try to private message \"$who\" with \"$response\"",
		);

		# BUG: THIS DOESN't WORK
		$self->say(
			who => $who, 
			channel => 'msg',
			body => $response,
		);
		
		# TRY: http://search.cpan.org/~bingos/POE-Component-IRC-6.88/lib/POE/Component/IRC.pm#privmsg
		$self->privmsg('#r3v', 'foo');

		$self->say(
			who => $who, 
			channel => $channel,
			body => "...Did it work?",
		);

		# Get private messaging working before trying to do it from forkit
		#$self->forkit(run => \&direct_message, who => $who, channel => 'msg', arguments => [$response]);
		#$self->forkit(run => \&direct_message, arguments => [$self, $who, $response]);		
	} 

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




	# More testing
	elsif (($body =~ /^(?!\!)/) && ($body =~ /\btest\b/)) {
		$reply = "TEST PASSED, $who. Amazing work.";
	} 
	
	# Return whatever reply we came up with.  This will occasionally be undef.
	return $reply;
}



# CUSTOM SUB-ROUTINES --------------------------------------------------------------------

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
	#$self->say(who => $who, channel => '#r3v', body => $body);
#  	$self->say(
#  		channel => "#r3v",
#  		body => "whisper what?",
#  	);

	return "foo";
}

# dumps a bunch of information to a file in /tmp for troubleshooting
sub dumptruck {
	# info to gather: nick, who asked, datetime, channels.... 
	# what other info can pocoirc tell us?
	my @myArgs = @_ ;
	my $myArgsAsString = "@myArgs";
	#my $currentNick = $self->pocoirc->nick_name;  #TODO Need to get $self

	# use better perl file-handling here.
	my $filecontents = `echo  \"\nmyArgs: \'${myArgsAsString}\'\n\n"  > /tmp/dump.r3vbot.txt`;
}

# END OF SUB-ROUTINES --------------------------------------------------------------------

# Create an instance of the bot and start it running.
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

