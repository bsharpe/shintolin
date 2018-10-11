#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib'
Dotenv.load
require 'yaml'
require 'json'
require 'ostruct'

db_config_path = File.join(Dir.pwd,'db','database.yml')
dbconfig = JSON.parse(YAML.load_file(File.join(Dir.pwd,'db','database.yml')).to_json, object_class: OpenStruct).send(ENV['GAME_ENV'])

puts "Environment: #{ENV['GAME_ENV']}".yellow

client = Mysql2::Client.new(host: dbconfig.host, username: dbconfig.username, password: dbconfig.password )

# UNCOMMENT to reset the db
# puts "Dropping DB".red
# client.query("DROP DATABASE IF EXISTS #{dbconfig.database};")

puts "Creating DB #{dbconfig.database}...".yellow
client.query("CREATE DATABASE IF NOT EXISTS #{dbconfig.database};")
client.query("USE #{dbconfig.database};")

puts "Adding Table ACCOUNTS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `accounts` (
  `id` int unsigned NOT NULL auto_increment,
  `email` varchar(100) collate utf8_unicode_ci NOT NULL,
  `website` varchar(100) collate utf8_unicode_ci,
  `joined` date NOT NULL,
  `kills` int unsigned NOT NULL default '0',
  `temp_sett_id` int unsigned NOT NULL default '0',
  `lastrevive` date NOT NULL,
  `description` text collate utf8_unicode_ci NOT NULL,
  `image` varchar(100) collate utf8_unicode_ci NOT NULL default '',
  `deaths` int unsigned NOT NULL default '0',
  `revives` int unsigned NOT NULL default '0',
  `frags` int unsigned NOT NULL default '1',
  `settlement_id` int(32) NOT NULL,
  `vote` int NOT NULL default '0',
  `when_sett_joined` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1;
END
client.query(query)

puts "Adding Table ANIMALS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `animals` (
  `id` int unsigned NOT NULL auto_increment,
  `type_id` tinyint NOT NULL,
  `x` int NOT NULL default '10',
  `y` int NOT NULL default '-10',
  `z` tinyint NOT NULL,
  `hp` smallint(4) NOT NULL default '10',
  `region_id` tinyint NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table GRID...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `grid` (
  `x` smallint(6) NOT NULL,
  `y` smallint(6) NOT NULL,
  `region_id` int NOT NULL default '1',
  `hp` tinyint unsigned NOT NULL default '3',
  `terrain` tinyint unsigned NOT NULL default '3',
  `building_id` int(2) NOT NULL default '0',
  `building_hp` tinyint unsigned NOT NULL default '0',
  KEY `XY` (`x`,`y`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Adding Table INVENTORIES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `inventories` (
  `user_id` int unsigned NOT NULL,
  `item_id` tinyint unsigned NOT NULL,
  `amount` smallint(5) unsigned NOT NULL,
  KEY `user_id` (`user_id`,`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Adding Table IPS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `ips` (
  `hits` int unsigned NOT NULL default '0',
  `user_id` int NOT NULL,
  `ip` varchar(15) collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`ip`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Adding Table MESSAGES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `messages` (
  `id` int unsigned NOT NULL auto_increment,
  `message` text character set utf8 collate utf8_unicode_ci NOT NULL,
  `speaker_id` int NOT NULL default '0',
  `target_id` int NOT NULL default '0',
  `x` smallint(6) NOT NULL,
  `y` smallint(6) NOT NULL,
  `z` tinyint NOT NULL,
  `type` enum('whisper','talk','shout','distant','reply','action','game','persistent','slash_me','chat','visible_all') NOT NULL default 'action',
  `time` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`),
  KEY `x` (`x`,`y`,`z`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table SETTLEMENTS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `settlements` (
  `id` int unsigned NOT NULL auto_increment,
  `name` varchar(32) NOT NULL,
  `x` smallint(6) NOT NULL,
  `y` smallint(6) NOT NULL,
  `founded` date NOT NULL,
  `type` enum('village','town','city','metropolis') NOT NULL default 'village',
  `description` text ,
  `motto` tinytext NOT NULL,
  `image` varchar(100) default '',
  `title` varchar(32) NOT NULL default 'Leader',
  `leader_id` int NOT NULL,
  `website` varchar(100) default '',
  `allow_new_users` tinyint NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table SKILLS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `skills` (
  `user_id` int unsigned NOT NULL,
  `skill_id` tinyint unsigned NOT NULL,
  UNIQUE KEY `user_id` (`user_id`,`skill_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
END
client.query(query)

puts "Adding Table STOCKPILES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `stockpiles` (
  `x` smallint(6) NOT NULL,
  `y` smallint(6) NOT NULL,
  `item_id` tinyint unsigned NOT NULL,
  `amount` smallint(5) unsigned NOT NULL,
  KEY `x_y` (`x`,`y`,`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ;
END
client.query(query)

puts "Adding Table USERS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `users` (
  `id` int unsigned NOT NULL auto_increment,
  `name` varchar(24) character set utf8 collate utf8_unicode_ci NOT NULL,
  `password` varchar(32) NOT NULL,
  `active` tinyint NOT NULL default '1',
  `x` smallint(6) NOT NULL default '0',
  `y` smallint(6) NOT NULL default '0',
  `z` tinyint unsigned NOT NULL default '0',
  `hp` tinyint unsigned NOT NULL default '50',
  `maxhp` tinyint unsigned NOT NULL default '50',
  `ap` float(4,1) NOT NULL default '100.0',
  `hunger` tinyint unsigned NOT NULL default '9',
  `lastaction` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `craft_xp` smallint(5) unsigned NOT NULL default '0',
  `warrior_xp` smallint(5) unsigned NOT NULL default '0',
  `herbal_xp` smallint(5) unsigned NOT NULL default '0',
  `wander_xp` smallint(5) unsigned NOT NULL default '0',
  `donated` tinyint default '0',
  `is_admin` tinyint default '0',
  PRIMARY KEY  (`id`),
  KEY `username` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table WRITINGS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `writings` (
  `id` int unsigned NOT NULL auto_increment,
  `x` int NOT NULL,
  `y` int NOT NULL,
  `z` tinyint unsigned NOT NULL,
  `message` tinytext collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table ENEMIES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `enemies` (
  `user_id` int unsigned NOT NULL,
  `enemy_id` int unsigned NOT NULL,
  `enemy_type` tinyint unsigned NOT NULL,
  `created` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `updated` timestamp NULL,
  PRIMARY KEY `user_id` (`enemy_id`,`enemy_type`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Done.".green