sozav - "The Scepter of Zavandor" board game
============================================

This is an implementation of [The Scepter of
Zavandor](http://www.boardgamegeek.com/boardgame/13884/the-scepter-of-zavandor)
board game.  The original inspiration of the project was to play with
genetic programming for the AIs.  I've worked on it in spurts over the
years, but still haven't gotten to the genetic programming.

The game has a very crude AI.  I intentionally haven't been trying to
improve the AI -- see references to genetic programming above.  That said
I'd welcome improved hand-crafted AIs if somebody wants to work on one.  A
ruby strategy would be a perfect candidate since it's practically scripted
already.  My intention is to set up a simple HTTP-based API for playing
the game so AIs can be decoupled from the base code (and to facilitate a
web-based interface), but I haven't gotten that done yet.

Currently the UI for the game is entirely text-based.  I've got a server running under a telnet daemon
at [telnet://jones.argon.org:8000](telnet://jones.argon.org:8000) you can use to try it out.

Roderick Schertler <roderick@argon.org>
