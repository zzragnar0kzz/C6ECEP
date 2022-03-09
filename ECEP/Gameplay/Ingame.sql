-- modify the cap on experience gained from killing barbarians; default : Value = 1
UPDATE GlobalParameters SET Value = 2 WHERE Name = 'EXPERIENCE_BARB_SOFT_CAP';

-- modify the maximum level attainable by killing barbarians (units begin at Level 1); default : Value = 2
UPDATE GlobalParameters SET Value = 5 WHERE Name = 'EXPERIENCE_MAX_BARB_LEVEL';

-- 
UPDATE GlobalParameters SET Value = 40 WHERE Name = 'EXPERIENCE_MAXIMUM_ONE_COMBAT';
