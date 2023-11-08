-- create a full copy of the entries in-scope for modification
-- This example works for TBC gear modified by azerothcore-tbc-scaled, as well as (nearly) all level 80 WOTLK gear
-- count = 7426
create table variable_loot_base as
select * from 
acore_world.item_template
where class in (2,4) -- weapons and armor
and
(
(
((quality = 3 and ItemLevel = 115) or quality = 4) 
and bonding = 1 -- BoP
and RequiredLevel = 70
and name not like '%gladiator%'
and name not like '%high warlord%'
and name not like '%grand marshal%'
)
or itemlevel >199)
and name not like '%gladiator%'
;

-- Creates a table of 1-50, or however many iterations you'd like
create table iterations as
WITH RECURSIVE seq AS (SELECT 0 AS value UNION ALL SELECT value + 1 FROM seq LIMIT 50)
   SELECT * FROM seq;

-- Creates a table containing 50 versions of variable_loot_base
-- includes a number to act as the entry that doesn't already exist in item_template
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

-- Once I've developed a list of appropriate effects, intention is to give each proc slot 
-- Something like the below, untested, just for notes
update variable_loot
set 
spellid_1 = case when (spellid_1 = 0) then (SELECT spellid FROM table_name ORDER BY RAND() LIMIT 1) else spellid_1 end),
spelltrigger_1 = case when (spellid_1 = 0) then 2 else spelltrigger_1 end),
spellppmrate_2 = case when (spellid_1 = 0) then (RAND()*(3-1)) else spellppmrate_2 end),

where -- appropriate randomization

-- Add these new items to item_template
insert into item_template
select * from variable_loot;

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
