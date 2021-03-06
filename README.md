r3vbot 1.1 beta
============
An IRC bot written in perl using Bot::BasicBot.

ABOUT
-----
The main reason this bot exists is because I wanted to see if I could do it. I'm a pretty
basic level perl guy, and haven't worked with other people's modules much. So, learning
the ins and outs of Bot::BasicBot and POE::Component::IRC has been fun. 

The bot is simple, right now, but I do have some ideas for stuff to add to it.

My perl-fu isn't the most advanced, but this is free to take and modify if you find any
bit of it useful.

Get the latest release here: https://github.com/r3v/r3vbot/releases/latest

FEATURES
--------
* Seen database - This is the main goal of the bot. Watch for the comings and goings of 
	users and be able to report back when asked.
* Base level IRC commands - Joining/Parting channels, etc.
* Only the bot owner can give certain commands, e.g. !quit
* Toys such as !dice and !coin

PLANNED
-------
* Interact with Nickserv and use a registered nick
* Flood Control
* Do a few channel OP duties
* Various toys, like !dice 3d6, !magic8ball, !groucho etc.
* DONE!! -> SSL connection
* DONE!! ->Move settings into a separate config file
* DONE!! ->Restrict certain commands to a list of people (not just owner)
* Logfile to record certain bot interactions

Full details on bugs and planned features is available on GitHub:
https://github.com/r3v/r3vbot/issues


USAGE
=====
Details on how to setup and run the bot.

REQUIRED PERL MODULES
---------------------
	Bot::BasicBot
	Config::Simple
	POE::Component::SSLify
	

SETUP/CONFIG
------------
You should definitely setup AND configure the bot. Edit some variables and run it. (More
detailed instructions will probably be put here at some point soon.)  Hey, this really
needs to be updated now, since the bot is using a config file instead of variables in 
the script!

COMMANDS
--------
	!bugs - Replies with were users can read/file bugs or enhancements for the bot.
	!channels - Request a list of channels that the bot is on.
	!coin - Flips a coin for the user.
	!commands - Get list of commands. Same as !help.
	!date OR !time - Gives what you'd expect, in the bot's timezone.
	!dice - Rolls dice (e.g. 3d6, d20). Type command by itself for details.
	!dt - Date AND time. fancy.
	!help - Get list of commands. Same as !commands.
	!join OR !part <channel> - Tells the bot to join or leave a channel. Owner/Admin only.
	!owner - Bot will respond with it's owner's nick.
	!quit - Tell the bot to quit IRC. Owner/Admin only.
	!seen <user> - find out the last time the bot saw the user
	!version - Bot will respond with it's version string.


THANKS
======
Many thanks to the guys in #perl-help and #poe on irc.perl.org.

### REF URLS ###
https://github.com/r3v/r3vbot
http://www.drdobbs.com/web-development/writing-irc-bots-in-perl-with-botbasicbo/184416221
http://search.cpan.org/~hinrik/Bot-BasicBot-0.89/lib/Bot/BasicBot.pm

