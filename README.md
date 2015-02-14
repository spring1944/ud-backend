#Undead Rising Backend

This is a really simple CRUD API for the S44Zombies plugin to chat with. It
persists player information like units and money.


Eventually it will also implement the web interface for managing your
units/spending the money you win in games.


###TODO

* add unitdef schema support for platoon units (i.e., buy one unit but get
    a bunch of different ones added to your army)
* add side picking for players who don't yet have a faction.
* add side reset option.
* gray out shop options/hide buy button for units you can't afford
* add support for repair/rearm.
* make the frontend not a gross pile of jquery and tables.
