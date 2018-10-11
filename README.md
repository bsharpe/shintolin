# Shintolin (circa 2010)
A multi-player browser-based game.

This is a cleaup project for the exercise.

## Setup

1. clone the repo
2. setup the gems

```
 > gem install bundler
 > bundle

```

3. edit the `db/database.yml` for your environment
4. setup the DB

```
 > ruby db/setup_db.rb
```

5. start the server

```
 > ruby server.rb
```

6. go to `http://localhost:9393`

## requirements
- ruby 2.3.7
- mysql server

### Original README
So, you want to set up your own version of Shintolin?

Shintolin runs as a bunch of CGI scripts, so it should work on any server with Apache, Ruby (1.8) and MySQL installed.

~~You'll find a database template in dbtemplate.sql.~~ You'll need to create a MySQL database called 'shintolin'; the command to import the data should be something like 'mysql -p shintolin < dbtemplate.sql'. If you want to check the import worked, open the MySQL prompt and type 'show tables;' - you should see 12 table names.

Getting Ruby to talk to MySQL is annoying. Really annoying. Follow the instructions on http://tmtm.org/en/mysql/ruby/ and see how you get on. It took me almost a whole day to get it to work (!) but that's because I'm a noob and used a package called XAMPP instead of installing Apache and MySQL seperately. The file 'mysql-connect.rb' handles the database connection for Shintolin, so make sure you change the settings there; in particular, 'root' should be changed for your username and '' with your password.

Shintolin isn't the best example of Ruby code; in particular, it's not very object-oriented, because I didn't properly understand object-orientation when I began working on version II of the game. There's probably a few other things I'd do differently now - still, you should see the orginal PHP version.

Happy hacking!

-----

    Shintolin - persistent browser-based multiplayer game
    Copyright (C) 2010 Isaac Lewis

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
