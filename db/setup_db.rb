#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
$LOAD_PATH << '../lib' $LOAD_PATH << '../lib/models'
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
  `email` varchar(255) collate utf8_unicode_ci NOT NULL,
  `website` varchar(255) collate utf8_unicode_ci,
  `joined` timestamp NOT NULL,
  `kills` int unsigned NOT NULL default '0',
  `temp_sett_id` int unsigned NOT NULL default '0',
  `last_revive` timestamp NULL,
  `description` text collate utf8_unicode_ci NOT NULL,
  `image` varchar(255) collate utf8_unicode_ci NOT NULL default '',
  `deaths` int unsigned NOT NULL default '0',
  `revives` int unsigned NOT NULL default '0',
  `frags` int unsigned NOT NULL default '1',
  `settlement_id` int NOT NULL,
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
  `type_id` int NOT NULL,
  `x` int NOT NULL default '10',
  `y` int NOT NULL default '-10',
  `z` int NOT NULL,
  `hp` int NOT NULL default '10',
  `region_id` int NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table GRID...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `grid` (
  `x` int NOT NULL,
  `y` int NOT NULL,
  `region_id` int NOT NULL default '1',
  `hp` int unsigned NOT NULL default '3',
  `terrain` int unsigned NOT NULL default '3',
  `building_id` int NOT NULL default '0',
  `building_hp` int unsigned NOT NULL default '0',
  KEY `XY` (`x`,`y`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Adding Table INVENTORIES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `inventories` (
  `user_id` int unsigned NOT NULL,
  `item_id` int unsigned NOT NULL,
  `amount` int unsigned NOT NULL,
  KEY `user_id` (`user_id`,`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Adding Table IPS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `ips` (
  `hits` int unsigned NOT NULL default '0',
  `user_id` int NOT NULL,
  `ip` varchar(255) collate utf8_unicode_ci NOT NULL,
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
  `x` int NOT NULL,
  `y` int NOT NULL,
  `z` int NOT NULL,
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
  `name` varchar(255) NOT NULL,
  `x` int NOT NULL,
  `y` int NOT NULL,
  `founded` date NOT NULL,
  `type` enum('village','town','city','metropolis') NOT NULL default 'village',
  `description` text ,
  `motto` varchar(255) NOT NULL,
  `image` varchar(255) default '',
  `title` varchar(255) NOT NULL default 'Leader',
  `leader_id` int NOT NULL,
  `website` varchar(255) default '',
  `allow_new_users` int NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table SKILLS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `skills` (
  `user_id` int unsigned NOT NULL,
  `skill_id` int unsigned NOT NULL,
  UNIQUE KEY `user_id` (`user_id`,`skill_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
END
client.query(query)

puts "Adding Table STOCKPILES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `stockpiles` (
  `x` int NOT NULL,
  `y` int NOT NULL,
  `item_id` int unsigned NOT NULL,
  `amount` int unsigned NOT NULL,
  KEY `x_y` (`x`,`y`,`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci ;
END
client.query(query)

puts "Adding Table USERS...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `users` (
  `id` int unsigned NOT NULL auto_increment,
  `name` varchar(255) character set utf8 collate utf8_unicode_ci NOT NULL,
  `password` varchar(255) NOT NULL,
  `active` int NOT NULL default '1',
  `x` int NOT NULL default '0',
  `y` int NOT NULL default '0',
  `z` int unsigned NOT NULL default '0',
  `hp` int unsigned NOT NULL default '50',
  `maxhp` int unsigned NOT NULL default '50',
  `ap` float(8,1) NOT NULL default '100.0',
  `hunger` int unsigned NOT NULL default '9',
  `lastaction` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `craft_xp` int unsigned NOT NULL default '0',
  `warrior_xp` int unsigned NOT NULL default '0',
  `herbal_xp` int unsigned NOT NULL default '0',
  `wander_xp` int unsigned NOT NULL default '0',
  `donated` int default '0',
  `is_admin` int default '0',
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
  `z` int unsigned NOT NULL,
  `message` varchar(255) collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=1 ;
END
client.query(query)

puts "Adding Table ENEMIES...".yellow
query =<<END
CREATE TABLE IF NOT EXISTS `enemies` (
  `user_id` int unsigned NOT NULL,
  `enemy_id` int unsigned NOT NULL,
  `enemy_type` int unsigned NOT NULL,
  `created` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `updated` timestamp NULL,
  PRIMARY KEY `user_id` (`enemy_id`,`enemy_type`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
END
client.query(query)

puts "Done.".green