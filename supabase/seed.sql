BEGIN;

-- ---------------------------------------------------------------------------
-- Clean slate (idempotent re-runs)
-- ---------------------------------------------------------------------------
TRUNCATE
  public."Dependencies",
  public."Builds",
  public."Contributions",
  public."Projects",
  public."Schematics",
  public."Users"
RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------------
-- 3 users
-- ---------------------------------------------------------------------------
INSERT INTO public."Users" (id, username, authenticated_user)
OVERRIDING SYSTEM VALUE VALUES
  (1, 'steve_builder', NULL),
  (2, 'alex_crafter',  NULL),
  (3, 'notch_legacy',  NULL)
ON CONFLICT (id) DO NOTHING;

SELECT setval(
  pg_get_serial_sequence('public."Users"', 'id'),
  COALESCE((SELECT MAX(id) FROM public."Users"), 1),
  true
);

-- ---------------------------------------------------------------------------
-- 15 schematics
-- ---------------------------------------------------------------------------
INSERT INTO public."Schematics" (id, name, file_path)
OVERRIDING SYSTEM VALUE VALUES
  (1,  'medieval_wall',        '/schematics/medieval_wall.litematic'),
  (2,  'castle_gate',          '/schematics/castle_gate.litematic'),
  (3,  'nether_portal_frame',  '/schematics/nether_portal_frame.litematic'),
  (4,  'ender_pearl_farm',     '/schematics/ender_pearl_farm.litematic'),
  (5,  'redstone_alu',         '/schematics/redstone_alu.litematic'),
  (6,  'ocean_guardian_chamber','/schematics/ocean_guardian_chamber.litematic'),
  (7,  'desert_pyramid_top',   '/schematics/desert_pyramid_top.litematic'),
  (8,  'skyblock_hub',         '/schematics/skyblock_hub.litematic'),
  (9,  'villager_hall',        '/schematics/villager_hall.litematic'),
  (10, 'iron_golem_spawner',   '/schematics/iron_golem_spawner.litematic'),
  (11, 'mansion_roof',         '/schematics/mansion_roof.litematic'),
  (12, 'mansion_library',      '/schematics/mansion_library.litematic'),
  (13, 'beacon_pyramid',       '/schematics/beacon_pyramid.litematic'),
  (14, 'storage_system',       '/schematics/storage_system.litematic'),
  (15, 'elytra_course',        '/schematics/elytra_course.litematic')
ON CONFLICT (id) DO NOTHING;

SELECT setval(
  pg_get_serial_sequence('public."Schematics"', 'id'),
  COALESCE((SELECT MAX(id) FROM public."Schematics"), 1),
  true
);

-- ---------------------------------------------------------------------------
-- 10 projects
-- Trigger trg_auto_contributor will auto-create 10 contributions (one per project).
-- ---------------------------------------------------------------------------
INSERT INTO public."Projects" (id, name, description, created_by, public, completed_at)
OVERRIDING SYSTEM VALUE VALUES
  (1,  'Spawn Castle',             'Central spawn castle with walls and gate',           1, true,  NULL),
  (2,  'Nether Hub',               'Nether hub connecting all portals',                  2, true,  NULL),
  (3,  'Ender Pearl Farm',         'Efficient ender pearl farm in the End',              3, true,  NULL),
  (4,  'Redstone Computer',        '8-bit redstone computer build',                      1, false, NULL),
  (5,  'Ocean Monument Base',      'Base built inside an ocean monument',                2, true,  now() - interval '10 days'),
  (6,  'Desert Pyramid Restoration','Restoration of desert pyramid with new chambers',   3, true,  NULL),
  (7,  'Skyblock Island Hub',      'Co-op skyblock hub island',                          1, true,  NULL),
  (8,  'Villager Trading Hall',    'Trading hall with all villager professions',         2, false, NULL),
  (9,  'Iron Golem Farm',          'High-efficiency iron farm',                          3, true,  now() - interval '2 days'),
  (10, 'Woodland Mansion Revamp',  'Revamp of woodland mansion interior',                1, true,  NULL)
ON CONFLICT (id) DO NOTHING;

SELECT setval(
  pg_get_serial_sequence('public."Projects"', 'id'),
  COALESCE((SELECT MAX(id) FROM public."Projects"), 1),
  true
);

-- ---------------------------------------------------------------------------
-- 12 builds  (project, schematic) is PK; coordinates are optional
-- ---------------------------------------------------------------------------
INSERT INTO public."Builds" (project, schematic, coord_x, coord_y, coord_z, dimension) VALUES
  (1,  1,  100.5,  64.0,  200.5, 'overworld'),   -- Spawn Castle  + medieval_wall
  (1,  2,  110.0,  64.0,  200.0, 'overworld'),   -- Spawn Castle  + castle_gate
  (2,  3,    0.0,  64.0,    0.0, 'nether'),      -- Nether Hub    + nether_portal_frame
  (3,  4,  500.0,  70.0, -300.0, 'end'),         -- Ender Farm    + ender_pearl_farm
  (4,  5,  -200.0, 64.0,  150.0, 'overworld'),   -- Redstone Comp + redstone_alu
  (5,  6,  800.0,  45.0,  800.0, 'overworld'),   -- Ocean Base    + ocean_guardian_chamber
  (6,  7, -600.0,  64.0, -600.0, 'overworld'),   -- Desert Pyr    + desert_pyramid_top
  (7,  8,    0.0, 100.0,    0.0, 'overworld'),   -- Skyblock Hub  + skyblock_hub
  (8,  9,  250.0,  64.0,  250.0, 'overworld'),   -- Villager Hall + villager_hall
  (9, 10,  300.0,  64.0, -100.0, 'overworld'),   -- Iron Farm     + iron_golem_spawner
  (10, 11, 1000.0, 80.0, 1000.0, 'overworld'),   -- Mansion       + mansion_roof
  (10, 12, 1005.0, 82.0, 1005.0, 'overworld')    -- Mansion       + mansion_library
ON CONFLICT (project, schematic) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 25 contributions  (project, "user") is PK
-- 10 rows are already auto-created by the trigger (one per project).
-- Insert all 25 with ON CONFLICT DO NOTHING; the 10 auto-rows are skipped
-- and the remaining 15 are inserted, totaling exactly 25 distinct pairs.
-- ---------------------------------------------------------------------------
INSERT INTO public."Contributions" (project, "user") VALUES
  -- full trios
  (1,  1), (1,  2), (1,  3),
  (2,  2), (2,  1), (2,  3),
  (3,  3), (3,  1), (3,  2),
  (4,  1), (4,  2), (4,  3),
  -- pairs
  (5,  2), (5,  1),
  (6,  3), (6,  1),
  (7,  1), (7,  2),
  (8,  2), (8,  3),
  (9,  3), (9,  1),
  -- trio for P10
  (10, 1), (10, 2), (10, 3)
ON CONFLICT (project, "user") DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4 dependencies  (project_id, depends_on_id) PK, check project_id <> depends_on_id
-- DAG: 2→1, 3→1, 4→2, 7→3
-- ---------------------------------------------------------------------------
INSERT INTO public."Dependencies" (project_id, depends_on_id) VALUES
  (2, 1),  -- Nether Hub depends on Spawn Castle
  (3, 1),  -- Ender Pearl Farm depends on Spawn Castle
  (4, 2),  -- Redstone Computer depends on Nether Hub
  (7, 3)   -- Skyblock Island Hub depends on Ender Pearl Farm
ON CONFLICT (project_id, depends_on_id) DO NOTHING;

COMMIT;
