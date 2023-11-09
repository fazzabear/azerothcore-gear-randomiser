-- create a full copy of the entries in-scope for modification
-- This example works for TBC gear modified by azerothcore-tbc-scaled, as well as (nearly) all level 80 WOTLK gear

-- Some useful queries to refresh the process. 
-- delete from item_template where entry in(select new_entry from variable_loot_ref);
-- drop table variable_loot;
-- drop table variable_loot_weapons;
-- drop table variable_loot_base;
-- drop table variable_loot_ref;
-- drop table variable_loot_proc;
-- drop table variable_loot_proc_calc;


create table variable_loot_base as
select * from 
acore_world.item_template
where 
(class = 4 or
class = 2 and dmg_min1 > 5) -- weapons and armor, excluding weapons and odd outliers with little or no DPS that are used for appearance sets
and
(
	(((quality = 3 and ItemLevel = 115) -- heroic-level rares
	or quality = 4) -- epics
	and bonding = 1 -- BoP
	and RequiredLevel = 70
	) -- Level 70 rares and epics that BOP
or itemlevel >199) -- WOTLK items
			
and name not like '%gladiator%'
and name not like '%high warlord%'
and name not like '%grand marshal%'
and name not like 'Chancellor''s%' -- excluding PVP gear and a bunch of TBC items not available to players
and RequiredReputationFaction = 0 -- exclude rep items, doing a daily vendor check to see if a rep item has rolled well sounds horrendously unfun
;

create table iterations as
WITH RECURSIVE seq AS (SELECT 0 AS value UNION ALL SELECT value + 1 FROM seq LIMIT 50)
   SELECT * FROM seq;

create table variable_loot as
select 
value
,ROW_NUMBER() over (order by value) + (select max(entry) from item_template) +1 new_entry
,b.*
from iterations a join variable_loot_base b on 
(case when a.value is null then 0 else 1 end) = (case when b.entry is null then 0 else 1 end);

-- Create a reference table containing the original item ID and each iteration
create table variable_loot_ref as
select value,new_entry, entry from variable_loot;

-- Alter variable_loot to align with item_template
alter table variable_loot
drop column value;   

alter table variable_loot
drop column entry;

alter table variable_loot
rename column new_entry to entry;


-- Modify the variables of interest

-- I've chosen to multiply each variable by a random number from 0.9-1.3
-- For each possible gem slot that the item doesn't already use, 20% chance of a socket

update variable_loot
set
dmg_min1 = dmg_min1 *(RAND()*(1.3-1)+0.9),
dmg_max1 = dmg_max1 *(RAND()*(1.3-1)+0.9),
armor = armor * (RAND()*(1.3-1)+0.9),
block = block * (RAND()*(1.3-1)+0.9),
stat_value1= stat_value1 *( RAND()*(1.3-1)+0.9),
stat_value2= stat_value2 *( RAND()*(1.3-1)+0.9),
stat_value3= stat_value3 *( RAND()*(1.3-1)+0.9),
stat_value4= stat_value4 *( RAND()*(1.3-1)+0.9),
stat_value5= stat_value5 *( RAND()*(1.3-1)+0.9),
stat_value6= stat_value6 *( RAND()*(1.3-1)+0.9),
stat_value7= stat_value7 *( RAND()*(1.3-1)+0.9),
stat_value8= stat_value8 *( RAND()*(1.3-1)+0.9),
stat_value9= stat_value9 *( RAND()*(1.3-1)+0.9),
stat_value10= stat_value10 *( RAND()*(1.3-1)+0.9),
socketColor_1 = case when (socketColor_1 > 0 or rand() > 0.2) then socketColor_1 else 8 end, -- blue
socketColor_2 = case when (socketColor_2 > 0 or rand() > 0.2) then socketColor_2 else 4 end, -- yellow
socketColor_3 = case when (socketColor_3 > 0 or rand() > 0.2) then socketColor_3 else 2 end  -- red
;

-- Optionally, for each possible spell effect that a weapon item doesn't already use, 10% chance of a random spell effect from a defined table created from proc_spell.csv
-- spelltrigger value 2 = the effect in spellid field will have a PPM chance to activate on hit
-- Flagging this way so as to not interfere with existing effects

-- Create a table assigning the chance of a proc existing based on weapon dps 

create table variable_loot_proc_calc 
 ( entry numeric,
 ench_chance_invert decimal (4,4),
 flag_1 numeric,
 flag_2 numeric,
 flag_3 numeric,
 flag_4 numeric,
 flag_5 numeric
  );

-- Assigns a chance of enchantment based on weapon dps within that subclass
-- the highest dps weapon of each subclass will have the highest chance of an enhancement
-- Incentivises pursuing higher level content (higher average weapon dps) for a higher chance at enhancement, rather than grinding lower level content
-- 
insert ignore into variable_loot_proc_calc
select
a.entry entry,
1.075-((((((a.dmg_min1+a.dmg_max1)/2)/a.delay)*1000)/(b.max_dps*0.7))*0.15) ench_chance_invert,
0 flag_1,
0 flag_2,
0 flag_3,
0 flag_4,
0 flag_5
from variable_loot a 
join
(select
subclass,
max(((((dmg_min1+dmg_max1)/2)/delay)*1000)) max_dps 
from variable_loot group by subclass) b on a.subclass = b.subclass
where a.class = 2 
;

-- Setting a minimum chance
update variable_loot_proc_calc
set ench_chance_invert = 0.975 where ench_chance_invert > 0.975;

-- Setting chance of enhancement
update variable_loot_proc_calc
set 
flag_1 = case when rand() > ench_chance_invert then 1 else 0 end,
flag_2 = case when rand() > ench_chance_invert then 1 else 0 end,
flag_3 = case when rand() > ench_chance_invert then 1 else 0 end,
flag_4 = case when rand() > ench_chance_invert then 1 else 0 end,
flag_5 = case when rand() > ench_chance_invert then 1 else 0 end
;

-- Create a table of all the spell variables without overwriting existing variables
-- uses a placeholder (99) for PPM
create table variable_loot_proc as
select 
a.entry,
case when (a.spellid_1 = 0 and b.flag_1 = 1) then (SELECT spell_id FROM proc_spell ORDER BY RAND() LIMIT 1) else a.spellid_1 end spellid_1,
case when (a.spellid_2 = 0 and b.flag_2 = 1) then (SELECT spell_id FROM proc_spell ORDER BY RAND() LIMIT 1) else a.spellid_2 end spellid_2,
case when (a.spellid_3 = 0 and b.flag_3 = 1) then (SELECT spell_id FROM proc_spell ORDER BY RAND() LIMIT 1) else a.spellid_3 end spellid_3,
case when (a.spellid_4 = 0 and b.flag_4 = 1) then (SELECT spell_id FROM proc_spell ORDER BY RAND() LIMIT 1) else a.spellid_4 end spellid_4,
case when (a.spellid_5 = 0 and b.flag_5 = 1) then (SELECT spell_id FROM proc_spell ORDER BY RAND() LIMIT 1) else a.spellid_5 end spellid_5,

case when (a.spellid_1 = 0 and b.flag_1 = 1) then 2 else a.spelltrigger_1 end spelltrigger_1,
case when (a.spellid_2 = 0 and b.flag_2 = 1) then 2 else a.spelltrigger_2 end spelltrigger_2,
case when (a.spellid_3 = 0 and b.flag_3 = 1) then 2 else a.spelltrigger_3 end spelltrigger_3,
case when (a.spellid_4 = 0 and b.flag_4 = 1) then 2 else a.spelltrigger_4 end spelltrigger_4,
case when (a.spellid_5 = 0 and b.flag_5 = 1) then 2 else a.spelltrigger_5 end spelltrigger_5,

case when (a.spellid_1 = 0 and b.flag_1 = 1) then 99 else a.spellppmrate_1 end spellppmrate_1,
case when (a.spellid_2 = 0 and b.flag_2 = 1) then 99 else a.spellppmrate_2 end spellppmrate_2,
case when (a.spellid_3 = 0 and b.flag_3 = 1) then 99 else a.spellppmrate_3 end spellppmrate_3,
case when (a.spellid_4 = 0 and b.flag_4 = 1) then 99 else a.spellppmrate_4 end spellppmrate_4,
case when (a.spellid_5 = 0 and b.flag_5 = 1) then 99 else a.spellppmrate_5 end spellppmrate_5,

case when (a.spellid_1 = 0 and b.flag_1 = 1) then 100 else a.spellcooldown_1 end spellcooldown_1,
case when (a.spellid_2 = 0 and b.flag_2 = 1) then 100 else a.spellcooldown_2 end spellcooldown_2,
case when (a.spellid_3 = 0 and b.flag_3 = 1) then 100 else a.spellcooldown_3 end spellcooldown_3,
case when (a.spellid_4 = 0 and b.flag_4 = 1) then 100 else a.spellcooldown_4 end spellcooldown_4,
case when (a.spellid_5 = 0 and b.flag_5 = 1) then 100 else a.spellcooldown_5 end spellcooldown_5

from variable_loot a join variable_loot_proc_calc b on a.entry = b.entry
where a.class = 2
;

-- set the actual PPM value to a random value between 1 and 3, divided by the power of the effect as per proc_spell
update variable_loot_proc
set 
spellppmRate_1 = case when spellppmRate_1 = 99 then ((RAND()*(4-1)+1)/(select power from proc_spell where spell_id = spellid_1)) else spellppmRate_1 end,
spellppmRate_2 = case when spellppmRate_2 = 99 then ((RAND()*(4-1)+1)/(select power from proc_spell where spell_id = spellid_2)) else spellppmRate_2 end,
spellppmRate_3 = case when spellppmRate_3 = 99 then ((RAND()*(4-1)+1)/(select power from proc_spell where spell_id = spellid_3)) else spellppmRate_3 end,
spellppmRate_4 = case when spellppmRate_4 = 99 then ((RAND()*(4-1)+1)/(select power from proc_spell where spell_id = spellid_4)) else spellppmRate_4 end,
spellppmRate_5 = case when spellppmRate_5 = 99 then ((RAND()*(4-1)+1)/(select power from proc_spell where spell_id = spellid_5)) else spellppmRate_5 end
;

-- optionally, create an index on the variable_loot_proc table as  no further changes should be made from this point
-- create index ix_lootproc on variable_loot_proc (entry)

-- Create a subset table for weapons to minimise effort of the UPDATE 
create table variable_loot_weapons as
select * from variable_loot where class = 2;

-- Push the proc changes to the weapons subset table
update variable_loot_weapons a
left outer join variable_loot_proc b
on a.entry = b.entry 
set
a.spellid_1 = b.spellid_1,
a.spellid_2 = b.spellid_2,
a.spellid_3 = b.spellid_3,
a.spellid_4 = b.spellid_4,
a.spellid_5 = b.spellid_5,

a.spelltrigger_1 = b.spelltrigger_1,
a.spelltrigger_2 = b.spelltrigger_2,
a.spelltrigger_3 = b.spelltrigger_3,
a.spelltrigger_4 = b.spelltrigger_4,
a.spelltrigger_5 = b.spelltrigger_5,

a.spellppmrate_1 = b.spellppmrate_1,
a.spellppmrate_2 = b.spellppmrate_2,
a.spellppmrate_3 = b.spellppmrate_3,
a.spellppmrate_4 = b.spellppmrate_4,
a.spellppmrate_5 = b.spellppmrate_5,

a.spellcooldown_1 = b.spellcooldown_1,
a.spellcooldown_2 = b.spellcooldown_2,
a.spellcooldown_3 = b.spellcooldown_3,
a.spellcooldown_4 = b.spellcooldown_4,
a.spellcooldown_5 = b.spellcooldown_5
where b.entry is not null and a.class = 2
;

-- Insert all iterations of modified equipment to the item_template table 
insert into item_template
select * from variable_loot where class !=2;

insert into item_template
select * from variable_loot_weapons;


--Create backups of loot template tables
create table creature_loot_backup as
select * from creature_loot_template;
create table reference_loot_backup as
select * from reference_loot_template;

--Schedule a SQL job to run a script prior to daily restart that
--drops and refreshes creature_loot_template and reference_loot_template
SET GLOBAL event_scheduler = ON;
delimiter |
CREATE EVENT IF NOT EXISTS item_randomiser
ON SCHEDULE EVERY 1 DAY 
STARTS (str_to_date('09-11-2023 034500','%d-%m-%Y %h%i%s')) -- specify the date and time for first execution - this will run at 03:45:00 on 09-11-2023
DO
BEGIN
truncate table acore_world.creature_loot_template;

truncate table acore_world.reference_loot_template;

insert into acore_world.creature_loot_template select * from acore_world.creature_loot_backup;
insert into acore_world.reference_loot_template select * from acore_world.reference_loot_backup;

update acore_world.creature_loot_template a
left outer join acore_world.variable_loot_ref b
on a.item = b.entry 
set a.item = (select b.new_entry ORDER BY RAND() LIMIT 1)
where a.item in (select entry from acore_world.variable_loot_ref)
;

update reference_loot_template a
left outer join variable_loot_ref b
on a.item = b.entry 
set a.item = (select b.new_entry ORDER BY RAND() LIMIT 1)
where a.item in (select entry from variable_loot_ref)
;
END |
