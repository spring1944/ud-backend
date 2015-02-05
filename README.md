#Undead Rising Backend

This is a really simple CRUD API for the S44Zombies plugin to chat with. It
persists player information like units and money.


Eventually it will also implement the web interface for managing your
units/spending the money you win in games.


###TODO

* implement the first web shop draft (and then remove shop mode from the game)
* provide an endpoint for the SPADS plugin to query about a player's army
    status (ie, should the game be prevented from starting because a player has
    a bunch of money, but no units)
