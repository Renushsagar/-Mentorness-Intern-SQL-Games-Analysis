USE game_analysis;

#Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0.
SELECT p.P_ID, ld.Dev_ID, p.PName, ld.Difficulty as Difficulty_level, Level
FROM player_details p
JOIN level_details2 ld ON p.P_ID = ld.P_ID
WHERE ld.Level = 0;

#Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and at least 3 stages are crossed.
SELECT pd.L1_Code, AVG(ld.Kill_Count) as Average_Kill_Count, ld.Lives_Earned, ld.Stages_crossed
FROM player_details pd
JOIN level_details2 ld ON pd.P_ID = ld.P_ID
WHERE ld.Lives_Earned = 2 AND ld.Stages_crossed >= 3
GROUP BY pd.L1_Code, ld.Lives_Earned, ld.Stages_crossed;

#Find the total number of stages crossed at each difficulty level for Level 2 with players using `zm_series` devices. Arrange the result in decreasing order of the total number of stages crossed.

SELECT ld.Difficulty, SUM(ld.Stages_crossed) as Total_Stages_Crossed, Level, ld.Dev_ID
FROM level_details2 ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.Level = 2 AND ld.Dev_ID LIKE 'zm_%'
GROUP BY ld.Difficulty, ld.Dev_ID
ORDER BY Total_Stages_Crossed DESC;

#Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days.
SELECT P_ID, COUNT(DISTINCT DATE_FORMAT(TimeStamp, '%y-%m-%d')) as Total_Unique_Dates
FROM level_details2
GROUP BY P_ID
HAVING COUNT(DISTINCT DATE_FORMAT(TimeStamp, '%y-%m-%d')) > 1;

#Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty.
SELECT P_ID, Level, SUM(Kill_Count) as Total_Kill_Count
FROM level_details2 
WHERE Kill_Count > (
    SELECT AVG(Kill_Count)
    FROM level_details2
    WHERE Difficulty = 'Medium'
)
GROUP BY P_ID, Level;

#Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level 0. Arrange in ascending order of level.
SELECT ld.Level, pd.L2_Code, SUM(ld.Lives_Earned) as Total_Lives_Earned
FROM level_details2 ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.Level > 0
GROUP BY ld.Level, pd.L2_Code
ORDER BY ld.Level ASC;

#Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.
SELECT subquery.Dev_ID, subquery.Difficulty, subquery.Score, subquery.Rn
FROM (
    SELECT ld.Dev_ID, ld.Difficulty, ld.Score,
        ROW_NUMBER() OVER (PARTITION BY ld.Dev_ID ORDER BY ld.Score) as Rn
    FROM level_details2 ld) AS subquery
WHERE Rn <= 3;

#Find the `first_login` datetime for each device ID.
SELECT Dev_ID, MIN(STR_TO_DATE(TimeStamp , '%y-%m-%d %H:%i'))as first_login
FROM level_details2
GROUP BY Dev_ID;

#Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well.
SELECT subquery.Dev_ID, subquery.Difficulty, subquery.Score, subquery.Rn
FROM (
    SELECT ld.Dev_ID, ld.Difficulty, ld.Score,
        RANK() OVER (PARTITION BY ld.Difficulty ORDER BY ld.Score ASC) as Rn
    FROM level_details2 ld) AS subquery
WHERE Rn <= 5;

#Find the device ID that is first logged in (based on `start_datetime`) for each player (`P_ID`). Output should contain player ID, device ID, and first login datetime.
SELECT P_ID, Dev_ID, MIN(STR_TO_DATE(TimeStamp , '%y-%m-%d %H:%i'))as first_login
FROM level_details2
GROUP BY P_ID, Dev_ID;

#For each player and date, determine how many `kill_counts` were played by the player so far.
# a) Using window functions
SELECT P_ID, DATE_FORMAT(TimeStamp, '%y-%m-%d') as Date, Kill_Count,SUM(Kill_Count) 
OVER (PARTITION BY P_ID, DATE_FORMAT(TimeStamp, '%y-%m-%d') ORDER BY TimeStamp) as Total_Played_Kills_So_Far
FROM level_details2
ORDER BY P_ID, TimeStamp;

#b) Without window functions
SELECT P_ID, DATE_FORMAT(TimeStamp, '%y-%m-%d')as Date, Kill_Count, SUM(Kill_Count) as Total_Played_Kills_So_Far
FROM level_details2
GROUP BY P_ID, TimeStamp, Kill_Count
ORDER BY P_ID, TimeStamp;

#Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, excluding the most recent `start_datetime`.
SELECT ld.P_ID, ld.TimeStamp, ld.Stages_Crossed,
    ( SELECT SUM(Stages_Crossed) 
        FROM level_details2 
        WHERE P_ID = ld.P_ID AND TimeStamp < ld.TimeStamp
    ) as Cumulative_Stages_Crossed
FROM level_details2 ld
WHERE NOT EXISTS (
    SELECT 1 FROM level_details2 ld2 
    WHERE ld.P_ID = ld2.P_ID AND ld.TimeStamp < ld2.TimeStamp
)
ORDER BY ld.P_ID, ld.TimeStamp;

#13. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`.
SELECT Dev_ID, P_ID, SUM(Score) as Total_Score
FROM level_details2
GROUP BY Dev_ID, P_ID
ORDER BY Dev_ID, Total_Score DESC
LIMIT 3;

#14. Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`.
SELECT pd.P_ID, pd.PName, AVG(ld2.Score) as Average_Score
FROM player_details pd
JOIN level_details2 ld2 ON pd.P_ID = ld2.P_ID
JOIN ( SELECT P_ID, AVG(Score) as Player_Avg_Score
    FROM level_details2
    GROUP BY P_ID
) avg_scores ON pd.P_ID = avg_scores.P_ID
WHERE ld2.Score > 0.5 * avg_scores.Player_Avg_Score
GROUP BY pd.P_ID, pd.PName

#15. Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.
DELIMITER //
CREATE PROCEDURE FindTopHeadshotsCount(IN n INT)
BEGIN CREATE TEMPORARY TABLE temp_table AS
    SELECT ld.Dev_ID, ld.headshots_count, ld.difficulty,
        ROW_NUMBER() OVER (PARTITION BY ld.Dev_ID ORDER BY ld.headshots_count) as rn
    FROM level_details2 ld
    WHERE ld.headshots_count IS NOT NULL;
    SELECT Dev_ID, headshots_count, difficulty
    FROM temp_table
    WHERE rn <= n;
    DROP TEMPORARY TABLE IF EXISTS temp_table;
END //
DELIMITER ;
CALL FindTopHeadshotsCount(3);