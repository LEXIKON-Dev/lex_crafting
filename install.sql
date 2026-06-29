CREATE TABLE IF NOT EXISTS `lex_crafting_settings` (
  `id` INT NOT NULL DEFAULT 1,
  `max_queue` INT NOT NULL DEFAULT 5,
  `use_categories` TINYINT(1) NOT NULL DEFAULT 1,
  `hide_minimap` TINYINT(1) NOT NULL DEFAULT 1,
  `locale` VARCHAR(8) NOT NULL DEFAULT 'de',
  `default_open_key` VARCHAR(8) NOT NULL DEFAULT 'E',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_recipes` (
  `id` VARCHAR(64) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `label` VARCHAR(128) NOT NULL,
  `category` VARCHAR(64) NOT NULL DEFAULT 'Allgemein',
  `craft_time` INT NOT NULL DEFAULT 5,
  `success_rate` INT NOT NULL DEFAULT 100,
  `yield_amount` INT NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_recipe_ingredients` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `recipe_id` VARCHAR(64) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `label` VARCHAR(128) NOT NULL,
  `amount` INT NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `recipe_id` (`recipe_id`),
  CONSTRAINT `fk_ing_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `lex_crafting_recipes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_points` (
  `id` VARCHAR(64) NOT NULL,
  `name` VARCHAR(128) NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `interaction_type` ENUM('marker','ped','object') NOT NULL DEFAULT 'marker',
  `open_key` VARCHAR(8) NOT NULL DEFAULT 'E',
  `coord_x` DOUBLE NOT NULL DEFAULT 0,
  `coord_y` DOUBLE NOT NULL DEFAULT 0,
  `coord_z` DOUBLE NOT NULL DEFAULT 0,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `model` VARCHAR(64) DEFAULT NULL,
  `interaction_radius` DOUBLE NOT NULL DEFAULT 1.5,
  `max_craft_radius` DOUBLE NOT NULL DEFAULT 5,
  `blip_enabled` TINYINT(1) NOT NULL DEFAULT 0,
  `blip_sprite` INT NOT NULL DEFAULT 89,
  `blip_color` INT NOT NULL DEFAULT 3,
  `blip_scale` DOUBLE NOT NULL DEFAULT 0.9,
  `blip_label` VARCHAR(64) NOT NULL DEFAULT 'Crafting',
  `blip_show_distance` DOUBLE NOT NULL DEFAULT 50,
  `marker_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `marker_type` INT NOT NULL DEFAULT 1,
  `marker_color_r` INT NOT NULL DEFAULT 43,
  `marker_color_g` INT NOT NULL DEFAULT 161,
  `marker_color_b` INT NOT NULL DEFAULT 240,
  `marker_color_a` INT NOT NULL DEFAULT 180,
  `marker_size` DOUBLE NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_recipe_jobs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `recipe_id` VARCHAR(64) NOT NULL,
  `job` VARCHAR(64) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `recipe_id` (`recipe_id`),
  CONSTRAINT `fk_recipe_job_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `lex_crafting_recipes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_point_jobs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `point_id` VARCHAR(64) NOT NULL,
  `job` VARCHAR(64) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `point_id` (`point_id`),
  CONSTRAINT `fk_job_point` FOREIGN KEY (`point_id`) REFERENCES `lex_crafting_points` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_point_categories` (
  `id` VARCHAR(64) NOT NULL,
  `point_id` VARCHAR(64) NOT NULL,
  `label` VARCHAR(128) NOT NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `point_id` (`point_id`),
  CONSTRAINT `fk_cat_point` FOREIGN KEY (`point_id`) REFERENCES `lex_crafting_points` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_category_recipes` (
  `category_id` VARCHAR(64) NOT NULL,
  `recipe_id` VARCHAR(64) NOT NULL,
  PRIMARY KEY (`category_id`, `recipe_id`),
  CONSTRAINT `fk_cr_cat` FOREIGN KEY (`category_id`) REFERENCES `lex_crafting_point_categories` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cr_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `lex_crafting_recipes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lex_crafting_player_queue` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `point_id` VARCHAR(64) NOT NULL,
  `recipe_id` VARCHAR(64) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `label` VARCHAR(128) NOT NULL,
  `yield_amount` INT NOT NULL DEFAULT 1,
  `status` ENUM('crafting','queued','done','failed','claimed') NOT NULL DEFAULT 'queued',
  `time_left` INT NOT NULL DEFAULT 0,
  `total_time` INT NOT NULL DEFAULT 0,
  `success_rate` INT NOT NULL DEFAULT 100,
  `started_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `lex_crafting_settings` (`id`, `max_queue`, `use_categories`, `hide_minimap`, `locale`, `default_open_key`)
VALUES (1, 5, 1, 1, 'de', 'E')
ON DUPLICATE KEY UPDATE `id` = `id`;

INSERT INTO `lex_crafting_recipes` (`id`, `item`, `label`, `category`, `craft_time`, `success_rate`, `yield_amount`, `enabled`) VALUES
('recipe_lockpick', 'lockpick', 'Dietrich', 'Werkzeuge', 5, 85, 1, 1),
('recipe_repairkit', 'repairkit', 'Reparaturkit', 'Werkzeuge', 8, 100, 1, 1),
('recipe_bandage', 'bandage', 'Verband', 'Medizin', 3, 100, 2, 1),
('recipe_firstaidkit', 'firstaidkit', 'Medikit', 'Medizin', 10, 95, 1, 1),
('recipe_ammo9', 'ammo-9', 'Pistolenmunition', 'Waffen', 6, 90, 12, 1)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

INSERT INTO `lex_crafting_recipe_ingredients` (`recipe_id`, `item`, `label`, `amount`) VALUES
('recipe_lockpick', 'iron', 'Eisen', 2),
('recipe_lockpick', 'plastic', 'Plastik', 1),
('recipe_repairkit', 'iron', 'Eisen', 3),
('recipe_repairkit', 'plastic', 'Plastik', 2),
('recipe_bandage', 'clothe', 'Stoff', 2),
('recipe_firstaidkit', 'bandage', 'Verband', 2),
('recipe_firstaidkit', 'water', 'Wasser', 1),
('recipe_ammo9', 'copper', 'Kupfer', 3),
('recipe_ammo9', 'iron', 'Eisen', 2);

INSERT INTO `lex_crafting_points` (
  `id`, `name`, `enabled`, `interaction_type`, `open_key`,
  `coord_x`, `coord_y`, `coord_z`, `heading`,
  `interaction_radius`, `max_craft_radius`,
  `blip_enabled`, `blip_sprite`, `blip_color`, `blip_scale`, `blip_label`,
  `marker_enabled`, `marker_type`, `marker_color_r`, `marker_color_g`, `marker_color_b`, `marker_color_a`, `marker_size`
) VALUES (
  'point_werkbank', 'Werkbank', 1, 'marker', 'E',
  100.5, -200.3, 54.1, 90,
  1.5, 5,
  0, 89, 3, 0.9, 'Crafting',
  1, 1, 43, 161, 240, 180, 1
) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

INSERT INTO `lex_crafting_point_categories` (`id`, `point_id`, `label`, `sort_order`) VALUES
('cat_tools', 'point_werkbank', 'Werkzeuge', 0),
('cat_med', 'point_werkbank', 'Medizin', 1)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

INSERT INTO `lex_crafting_category_recipes` (`category_id`, `recipe_id`) VALUES
('cat_tools', 'recipe_lockpick'),
('cat_tools', 'recipe_repairkit'),
('cat_med', 'recipe_bandage'),
('cat_med', 'recipe_firstaidkit')
ON DUPLICATE KEY UPDATE `category_id` = VALUES(`category_id`);
