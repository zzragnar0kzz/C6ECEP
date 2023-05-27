-- modify the cap on experience gained from killing barbarians; default : Value = 1
UPDATE GlobalParameters SET Value = 2 WHERE Name = 'EXPERIENCE_BARB_SOFT_CAP';

-- modify the maximum level attainable by killing barbarians (units begin at Level 1); default : Value = 2
UPDATE GlobalParameters SET Value = 3 WHERE Name = 'EXPERIENCE_MAX_BARB_LEVEL';

-- modify the maximum amount of experience that can be earned from unit-vs-unit combat; default: Value = 10 (pre-GS); = 8 (GS and later)
UPDATE GlobalParameters SET Value = 20 WHERE Name = 'EXPERIENCE_MAXIMUM_ONE_COMBAT';
