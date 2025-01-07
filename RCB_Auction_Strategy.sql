-- OBJECTIVE QUESTIONS
-- 2. What is the total number of run scored in 1st season by RCB (bonus : also include the extra runs using the extra runs table)
WITH RCB_Season1_Matches AS (
SELECT * FROM matches WHERE Season_Id = 1 
AND (Team_1 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
OR Team_2 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore"))
),
RCB_Season1_Matches_And_Innings AS (
SELECT Match_Id, Toss_Winner, Toss_Decide,
	CASE
		WHEN Toss_Winner = 2 AND Toss_Decide = 2 THEN 1
        WHEN Toss_Winner = 2 AND Toss_Decide = 1 THEN 2
		WHEN Toss_Winner != 2 AND Toss_Decide = 2 THEN 2
		WHEN Toss_Winner != 2 AND Toss_Decide = 1 THEN 1   
    END AS RCB_Batting_Innings_No
FROM RCB_season1_matches
),
RCB_Runs_Scored AS (
SELECT rcbmi.Match_Id, rcbmi.RCB_Batting_Innings_No, SUM(bs.Runs_Scored) AS RCB_runs
FROM RCB_Season1_Matches_And_Innings rcbmi
JOIN batsman_scored bs ON rcbmi.Match_Id = bs.Match_Id AND rcbmi.RCB_Batting_Innings_No = bs.Innings_No
GROUP BY 1,2
),
RCB_Runs_Scored_and_Extras AS (
SELECT rcbrs.Match_Id, rcbrs.RCB_Batting_Innings_No, rcbrs.RCB_runs, SUM(er.Extra_Runs) AS extras
FROM RCB_Runs_Scored rcbrs
JOIN extra_runs er ON rcbrs.Match_Id = er.Match_Id AND rcbrs.RCB_Batting_Innings_No = er.Innings_No 
GROUP BY 1,2,3
)
SELECT SUM(RCB_runs), SUM(extras) FROM RCB_Runs_Scored_and_Extras;








-- 3. How many players were more than age of 25 during season 2 ?
WITH Player_Ages AS (
SELECT *, YEAR(CURRENT_DATE()) - YEAR(DOB) AS Current_Age FROM player
),
Season2_Players AS (
SELECT DISTINCT Player_Id
FROM player_match
WHERE Match_Id IN (SELECT Match_Id FROM matches WHERE Season_Id = 2)
)
SELECT COUNT(pa.Player_Name) AS players_above_25_years_of_age_in_season2
FROM Season2_Players s2p
JOIN Player_Ages pa ON s2p.Player_Id = pa.Player_Id
WHERE Current_Age > 25;








-- 4. How many matches did RCB win in season 1 ? 
WITH RCB_Season1_Matches AS(
SELECT * FROM matches WHERE Season_Id = 1 
AND (Team_1 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
OR Team_2 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore"))
)
SELECT COUNT(Match_Winner) AS RCB_Season1_Wins FROM RCB_Season1_Matches WHERE Match_Winner = (
SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore"
);








-- 5. List top 10 players according to their strike rate in last 4 seasons
WITH Last_4Seasons_Ball_by_Ball AS (
SELECT * FROM Ball_by_ball
WHERE Match_Id IN (SELECT Match_Id FROM matches WHERE Season_Id IN (6,7,8,9))
ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Runs_Scored_by_Player AS(
SELECT l4sb.Striker AS Player_Id, SUM(bs.Runs_Scored) AS Total_Runs_Scored
FROM Last_4Seasons_Ball_by_Ball l4sb
JOIN batsman_scored bs ON bs.Match_Id = l4sb.Match_Id AND bs.Innings_No = l4sb.Innings_No AND bs.Over_Id = l4sb.Over_Id AND bs.Ball_Id = l4sb.Ball_Id
GROUP BY l4sb.Striker
HAVING SUM(bs.Runs_Scored) > 0
ORDER BY Total_Runs_Scored DESC
),
Balls_Faced_by_Player AS (
SELECT Striker AS Player_Id, COUNT(Ball_Id) AS Total_Balls_Faced
FROM Last_4Seasons_Ball_by_Ball
GROUP BY Striker
),
Strike_rates AS (
SELECT rsbp.Player_Id, ROUND((rsbp.Total_Runs_Scored/bfbp.Total_Balls_Faced)*100,2) AS Strike_Rate
FROM Runs_Scored_by_Player rsbp
JOIN Balls_Faced_by_Player bfbp ON rsbp.Player_Id = bfbp.Player_Id
)
SELECT p.Player_Name, sr.Strike_Rate
FROM Strike_rates sr
JOIN player p ON sr.Player_Id = p.Player_Id
ORDER BY Strike_Rate DESC LIMIT 10;






-- 6. What is the average runs scored by each batsman considering all the seasons?
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Runs_scored_per_season AS (
    SELECT 
        bbbws.Striker AS Player_Id,
        bbbws.Season_Id,
        SUM(bs.Runs_Scored) AS Runs_Scored_in_Season
    FROM batsman_scored bs
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    GROUP BY bbbws.Striker, bbbws.Season_Id
),
Average_runs_scored_by_each_player_in_seasons AS (
    SELECT 
        Player_Id,
        ROUND(AVG(Runs_Scored_in_Season), 2) AS Avg_runs_in_seasons
    FROM Runs_scored_per_season
    GROUP BY Player_Id
    HAVING COUNT(DISTINCT Season_Id) > 1
),
Average_Runs AS (
    SELECT 
        p.Player_Name, 
        ars.Avg_runs_in_seasons AS Avg_Runs_Scored
    FROM Average_runs_scored_by_each_player_in_seasons ars
    JOIN player p ON p.Player_Id = ars.Player_Id
    ORDER BY Avg_Runs_Scored DESC
)
SELECT * FROM Average_Runs;








-- 7. What are the average wickets taken by each bowler considering all the seasons?
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Wickets_taken_per_season AS (
    SELECT 
        bbbws.Bowler AS Player_Id, 
        bbbws.Season_Id,
        COUNT(*) AS Wickets_in_Season
    FROM wicket_taken wt
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
    WHERE wt.Kind_Out NOT IN (3, 5, 9) 
    GROUP BY bbbws.Bowler, bbbws.Season_Id
),
Avg_wickets_taken_by_each_player_in_seasons AS (
    SELECT 
        Player_Id, 
        COUNT(DISTINCT Season_Id) AS No_of_Seasons_Played,
        SUM(Wickets_in_Season) AS Total_Wickets,
        ROUND(AVG(Wickets_in_Season), 2) AS Avg_wickets_in_seasons
    FROM Wickets_taken_per_season
    GROUP BY Player_Id
    HAVING COUNT(DISTINCT Season_Id) > 1
),
Average_Wickets AS (
    SELECT 
        p.Player_Name, 
        awt.Avg_wickets_in_seasons
    FROM Avg_wickets_taken_by_each_player_in_seasons awt
    JOIN player p ON p.Player_Id = awt.Player_Id
    ORDER BY awt.Avg_wickets_in_seasons DESC
)
SELECT * FROM Average_Wickets;







-- 8. List all the players who have average runs scored greater than overall average and who have taken wickets greater than overall average
WITH Ball_by_Ball_with_Seasons AS(
SELECT bb.*, m.Season_Id
FROM matches m
JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Average_runs_scored_by_each_player_in_seasons AS (
SELECT 
	bbbws.Striker AS Player_Id, 
    	SUM(bs.Runs_Scored) AS Total_Runs,
	COUNT(DISTINCT bbbws.Season_Id) AS No_of_Seasons_Played, 
ROUND(SUM(bs.Runs_Scored)/COUNT(DISTINCT bbbws.Season_Id),2) AS Avg_runs_in_seasons
FROM batsman_scored bs
LEFT JOIN Ball_by_Ball_with_Seasons bbbws ON bbbws.Match_Id = bs.Match_Id AND bbbws.Innings_No = bs.Innings_No AND bbbws.Over_Id = bs.Over_Id AND bbbws.Ball_Id = bs.Ball_Id
GROUP BY bbbws.Striker
),
Playerwise_Avg_Runs AS (
SELECT p.Player_Name, ars.Avg_runs_in_seasons 
FROM Average_runs_scored_by_each_player_in_seasons ars
JOIN player p ON p.Player_Id = ars.Player_Id
ORDER BY 2 DESC
),
Overall_avg_runs_scored AS (
SELECT ROUND(AVG(Avg_runs_in_seasons),2) AS Overall_Avg_Runs FROM Playerwise_Avg_Runs
),
Avg_wickets_taken_by_each_player_in_seasons AS (
SELECT 
	bbbws.Bowler AS Player_Id, 
    	COUNT(*) AS wickets_taken_by_bowler,
    	COUNT(DISTINCT bbbws.Season_Id) AS No_of_Seasons_Played,
    	ROUND(COUNT(*)/COUNT(DISTINCT bbbws.Season_Id),2) AS Avg_wickets_in_seasons
FROM wicket_taken wt
LEFT JOIN Ball_by_Ball_with_Seasons bbbws ON bbbws.Match_Id = wt.Match_Id AND bbbws.Innings_No = wt.Innings_No AND bbbws.Over_Id = wt.Over_Id AND bbbws.Ball_Id = wt.Ball_Id
WHERE wt.Kind_Out NOT IN (3,5,9)
GROUP BY bbbws.Bowler
),
Playerwise_Avg_Wickets AS (
SELECT p.Player_Name, awt.Avg_wickets_in_seasons
FROM Avg_wickets_taken_by_each_player_in_seasons awt
JOIN player p ON p.Player_Id = awt.Player_Id
ORDER BY 2 DESC
),
Overall_avg_wickets_taken AS (
SELECT ROUND(AVG(Avg_wickets_in_seasons),2) AS Overall_Avg_Wickets FROM Playerwise_Avg_Wickets
),
Players_Above_Avg AS (
    SELECT p.Player_Name,
           	     ars.Avg_runs_in_seasons,
           	     awt.Avg_wickets_in_seasons
    FROM player p
    LEFT JOIN Average_runs_scored_by_each_player_in_seasons ars ON p.Player_Id = ars.Player_Id
    LEFT JOIN Avg_wickets_taken_by_each_player_in_seasons awt ON p.Player_Id = awt.Player_Id
    WHERE ars.Avg_runs_in_seasons > (SELECT Overall_Avg_Runs FROM Overall_avg_runs_scored)
      	AND awt.Avg_wickets_in_seasons > (SELECT Overall_Avg_Wickets FROM Overall_avg_wickets_taken)
)
SELECT * FROM Players_Above_Avg
ORDER BY Avg_runs_in_seasons DESC, Avg_wickets_in_seasons DESC;










-- 9. Create a table rcb_record table that shows wins and losses of RCB in an individual venue.
CREATE TABLE rcb_record AS
WITH RCB_Matches AS (
    SELECT * 
    FROM matches 
    WHERE Team_1 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
       OR Team_2 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
),
Venuewise_wins_and_losses AS (
    SELECT 
        Venue_Id, 
        COUNT(CASE WHEN Match_winner = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore") THEN 1 END) AS Wins,
        COUNT(CASE WHEN Match_winner != (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore") THEN 1 END) AS Losses
    FROM RCB_Matches
    WHERE Outcome_Type IN (1,3)
    GROUP BY Venue_Id
)
SELECT 
    v.Venue_Name, 
    vwl.Wins, 
    vwl.Losses
FROM Venuewise_wins_and_losses vwl
JOIN venue v ON vwl.Venue_Id = v.Venue_Id;

SELECT * FROM rcb_record;










-- 10. What is the impact of bowling style on wickets taken.
WITH 
Total_wickets_taken_by_each_player_in_seasons AS (
SELECT 
	bbbws.Bowler AS Player_Id, 
    COUNT(*) AS wickets_taken_by_bowler
FROM wicket_taken wt
LEFT JOIN Ball_by_Ball bbbws ON bbbws.Match_Id = wt.Match_Id AND bbbws.Innings_No = wt.Innings_No AND bbbws.Over_Id = wt.Over_Id AND bbbws.Ball_Id = wt.Ball_Id
WHERE wt.Kind_Out NOT IN (3,5,9)
GROUP BY bbbws.Bowler
)
SELECT bs.Bowling_skill, SUM(twts.wickets_taken_by_bowler) AS Wickets_taken
FROM Total_wickets_taken_by_each_player_in_seasons twts
JOIN player p ON p.Player_Id = twts.Player_Id
JOIN bowling_style bs ON p.Bowling_skill = bs.Bowling_Id
GROUP BY p.Bowling_skill;









-- 11. Write the sql query to provide a status of whether the performance of the team better than the previous year performance on the basis of number of runs scored by the team in the season and number of wickets taken 
WITH RCB_Matches AS(
SELECT * FROM matches 
WHERE Team_1 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
	OR Team_2 = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
),
RCB_Matches_And_Innings AS(
SELECT Match_Id, Toss_Winner, Toss_Decide,
	CASE
		WHEN Toss_Winner = 2 AND Toss_Decide = 2 THEN 1
       		WHEN Toss_Winner = 2 AND Toss_Decide = 1 THEN 2
		WHEN Toss_Winner != 2 AND Toss_Decide = 2 THEN 2
		WHEN Toss_Winner != 2 AND Toss_Decide = 1 THEN 1   
   	 END AS RCB_Batting_Innings_No,
  	CASE
		WHEN Toss_Winner = 2 AND Toss_Decide = 2 THEN 2
        		WHEN Toss_Winner = 2 AND Toss_Decide = 1 THEN 1
		WHEN Toss_Winner != 2 AND Toss_Decide = 2 THEN 1
		WHEN Toss_Winner != 2 AND Toss_Decide = 1 THEN 2
	END AS RCB_Bowling_Innings_No
FROM RCB_matches
),
RCB_Wickets_Taken AS(
SELECT rcbmi.Match_Id, rcbmi.RCB_Bowling_Innings_No, COUNT(*) AS RCB_wickets_taken
FROM RCB_Matches_And_Innings rcbmi
JOIN wicket_taken wt on rcbmi.Match_Id = wt.Match_Id AND rcbmi.RCB_Bowling_Innings_No = wt.Innings_No
GROUP BY 1,2
),
RCB_Runs_Scored AS(
SELECT rcbmi.Match_Id, rcbmi.RCB_Batting_Innings_No, SUM(bs.Runs_Scored) AS RCB_runs_scored
FROM RCB_Matches_And_Innings rcbmi
JOIN batsman_scored bs ON rcbmi.Match_Id = bs.Match_Id AND rcbmi.RCB_Batting_Innings_No = bs.Innings_No
GROUP BY 1,2
),
RCB_Runs_Scored_and_Extras AS(
SELECT rcbrs.Match_Id, rcbrs.RCB_Batting_Innings_No, rcbrs.RCB_runs_scored, SUM(er.Extra_Runs) AS extras
FROM RCB_Runs_Scored rcbrs
JOIN extra_runs er ON rcbrs.Match_Id = er.Match_Id AND rcbrs.RCB_Batting_Innings_No = er.Innings_No 
GROUP BY 1,2,3
),
RCB_Total_Runs_Scored AS (
SELECT Match_Id, RCB_Batting_Innings_No, (RCB_runs_scored + extras) AS RCB_runs_total FROM RCB_Runs_Scored_and_Extras
)
SELECT 
	s.Season_Year, 
	SUM(rcbtrs.RCB_runs_total) AS RCB_runs_total,
   	SUM(rcbwt.RCB_wickets_taken) AS RCB_wickets_taken,
COALESCE(LAG(SUM(rcbtrs.RCB_runs_total)) OVER (ORDER BY s.Season_Year ASC),"-") AS  Previous_year_runs_total,
    	COALESCE(LAG(SUM(rcbwt.RCB_wickets_taken)) OVER (ORDER BY s.Season_Year ASC),"-") AS Previous_year_wickets_taken,
    	CASE
	WHEN SUM(rcbtrs.RCB_runs_total) > LAG(SUM(rcbtrs.RCB_runs_total)) OVER (ORDER BY s.Season_Year ASC)
			AND SUM(rcbwt.RCB_wickets_taken) > LAG(SUM(rcbwt.RCB_wickets_taken)) OVER (ORDER BY s.Season_Year ASC)
	THEN "Improved"
	WHEN SUM(rcbtrs.RCB_runs_total) > LAG(SUM(rcbtrs.RCB_runs_total)) OVER (ORDER BY s.Season_Year ASC)
			AND SUM(rcbwt.RCB_wickets_taken) < LAG(SUM(rcbwt.RCB_wickets_taken)) OVER (ORDER BY s.Season_Year ASC)
	THEN "Better in Scoring runs"
    WHEN SUM(rcbtrs.RCB_runs_total) < LAG(SUM(rcbtrs.RCB_runs_total)) OVER (ORDER BY s.Season_Year ASC)
			AND SUM(rcbwt.RCB_wickets_taken) > LAG(SUM(rcbwt.RCB_wickets_taken)) OVER (ORDER BY s.Season_Year ASC)
	THEN "Better in Grabing wickets"
    WHEN SUM(rcbtrs.RCB_runs_total) < LAG(SUM(rcbtrs.RCB_runs_total)) OVER (ORDER BY s.Season_Year ASC)
			AND SUM(rcbwt.RCB_wickets_taken) < LAG(SUM(rcbwt.RCB_wickets_taken)) OVER (ORDER BY s.Season_Year ASC)
	THEN "Bad"
	ELSE "-"
    	END AS Status
FROM RCB_Total_Runs_Scored rcbtrs
JOIN RCB_Wickets_Taken rcbwt ON rcbtrs.Match_Id = rcbwt.Match_Id
JOIN matches m ON m.Match_Id = rcbwt.Match_Id
JOIN season s ON m.Season_Id = s.Season_Id
GROUP BY 1;







-- 12. Derive more KPIs for the team strategy?
-- Captain's Win Rate
WITH Captain_matches AS (
	SELECT Match_Id, Player_Id
    FROM player_match
    WHERE Role_Id = 1 AND Team_Id = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
),
Captainwise_matches AS (
SELECT p.Player_Name, cm.Match_Id, COUNT(cm.Match_Id) OVER (PARTITION BY p.Player_Name) AS played_as_captain
FROM Captain_matches cm
JOIN player p ON cm.Player_Id = p.Player_Id
)
SELECT 
	cm.Player_Name,
    cm.played_as_captain,
    COUNT(*) AS won_as_captain
FROM Captainwise_matches cm
JOIN matches m ON m.Match_Id = cm.Match_Id
WHERE m.Match_Winner = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore") AND m.Outcome_Type = 1
GROUP BY cm.Player_Name, cm.played_as_captain;

-- Boundary Counts
WITH Ball_by_ball_with_seasons AS (
	SELECT bbb.*, m.Season_Id, m.Match_Date
    FROM ball_by_ball bbb
    JOIN matches m ON bbb.Match_Id = m.Match_Id
)
SELECT 
	YEAR(bbbws.Match_Date) AS `Year`,
    SUM(CASE WHEN bs.runs_scored = 4 THEN 1 ELSE 0 END) AS Fours,
    SUM(CASE WHEN bs.runs_scored = 6 THEN 1 ELSE 0 END) AS Sixes
FROM Ball_by_ball_with_seasons bbbws
JOIN batsman_scored bs ON bbbws.Match_Id = bs.Match_Id AND bbbws.Innings_No = bs.Innings_No AND bbbws.Over_Id = bs.Over_Id AND bbbws.Ball_Id = bs.Ball_Id
WHERE bbbws.Team_Batting = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
GROUP BY `Year`;

-- Seasonwise Wickets
WITH Ball_by_ball_with_seasons AS (
	SELECT bbb.*, m.Season_Id, m.Match_Date
    FROM ball_by_ball bbb
    JOIN matches m ON bbb.Match_Id = m.Match_Id
)
SELECT YEAR(bbbws.Match_Date) AS `Year`, COUNT(*) AS Wickets_Taken
FROM Ball_by_ball_with_seasons bbbws
JOIN wicket_taken wt ON bbbws.Match_Id = wt.Match_Id AND bbbws.Innings_No = wt.Innings_No AND bbbws.Over_Id = wt.Over_Id AND bbbws.Ball_Id = wt.Ball_Id
WHERE bbbws.Team_Bowling = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore") AND wt.Kind_Out NOT IN (3,5,9)
GROUP BY YEAR(bbbws.Match_Date);

-- Seasonwise Runs
WITH Ball_by_ball_with_seasons AS (
	SELECT bbb.*, m.Season_Id, m.Match_Date
    FROM ball_by_ball bbb
    JOIN matches m ON bbb.Match_Id = m.Match_Id
)
SELECT 
    YEAR(bbbws.Match_Date) AS `Year`, 
    SUM(COALESCE(bs.runs_scored, 0)) + SUM(COALESCE(er.Extra_Runs, 0)) AS Total_Runs
FROM Ball_by_ball_with_seasons bbbws
LEFT JOIN batsman_scored bs ON bbbws.Match_Id = bs.Match_Id AND bbbws.Innings_No = bs.Innings_No AND bbbws.Over_Id = bs.Over_Id AND bbbws.Ball_Id = bs.Ball_Id
LEFT JOIN extra_runs er ON bbbws.Match_Id = er.Match_Id AND bbbws.Innings_No = er.Innings_No AND bbbws.Over_Id = er.Over_Id AND bbbws.Ball_Id = er.Ball_Id
WHERE bbbws.Team_Batting = (SELECT Team_Id FROM team WHERE Team_Name = "Royal Challengers Bangalore")
GROUP BY YEAR(bbbws.Match_Date)
ORDER BY `Year`;










-- 13. Using SQL, write a query to find out average wickets taken by each bowler in each venue. Also rank the gender according to the average value.
WITH Venuewise_wickets AS (
SELECT 
	bbb.Bowler AS Player_Id,
    v.Venue_Name,
    COUNT(*) AS wickets_taken_by_bowler,
    COUNT(DISTINCT wt.Match_Id) AS matches_played
FROM wicket_taken wt
LEFT JOIN Ball_by_Ball bbb ON bbb.Match_Id = wt.Match_Id AND bbb.Innings_No = wt.Innings_No AND bbb.Over_Id = wt.Over_Id AND bbb.Ball_Id = wt.Ball_Id
JOIN matches m ON bbb.Match_Id = m.Match_Id
JOIN venue v ON v.Venue_Id = m.Venue_Id
WHERE wt.Kind_Out NOT IN (3,5,9)
GROUP BY bbb.Bowler, v.Venue_Name
ORDER BY bbb.Bowler
)
SELECT 
	p.Player_Name AS Bowler, 
    Venue_Name, 
    ROUND(vw.wickets_taken_by_bowler/vw.matches_played ,2) AS Avg_wickets,
    DENSE_RANK() OVER (PARTITION BY Venue_Name ORDER BY ROUND(vw.wickets_taken_by_bowler/vw.matches_played ,2) DESC) AS `Rank`
FROM Venuewise_wickets vw
JOIN player p ON p.Player_Id = vw.Player_Id
ORDER BY Venue_Name ASC;










-- 14. Which of the given players have consistently performed well in past seasons? (will you use any visualisation to solve the problem)
-- For Seasonwise Batting_averages of each player
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Batting_Averages AS (
    SELECT 
        bbbws.Striker AS Player_Id,
        bbbws.Season_Id,
        SUM(bs.Runs_Scored) AS Season_Runs_Scored,
        COUNT(wt.Player_Out) AS Season_Outs,
        ROUND(SUM(bs.Runs_Scored)/
        COUNT(wt.Player_Out),2) AS Batting_Average
    FROM batsman_scored bs
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    LEFT JOIN wicket_taken wt 
        ON bbbws.Striker = wt.Player_Out 
        AND bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
    GROUP BY bbbws.Striker, bbbws.Season_Id
    ORDER BY bbbws.Striker, bbbws.Season_Id
)
SELECT p.Player_Name, ba.Season_Id, ba.Batting_Average
FROM Batting_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id
WHERE ba.Batting_Average IS NOT NULL 
	AND p.Player_Id IN 
		(SELECT Player_Id FROM Batting_Averages 
        GROUP BY Player_Id 
        HAVING COUNT(Season_Id) > 3 AND SUM(Season_Runs_Scored) > 700 AND SUM(Season_Runs_Scored)/SUM(Season_Outs) > 30
        )
ORDER BY p.Player_Name, ba.Season_Id ASC;





-- For Seasonwise Bowling_averages of each player
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Bowling_Averages AS (
    SELECT 
        bbbws.Bowler AS Player_Id, 
        bbbws.Season_Id,
        SUM(bs.runs_scored) AS Season_runs_given,
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END) AS Season_wickets,
        ROUND(SUM(bs.runs_scored)/
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END),2) AS Bowling_Average
    FROM Ball_by_Ball_with_Seasons bbbws 
    LEFT JOIN wicket_taken wt
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
	LEFT JOIN batsman_scored bs
		 ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    WHERE bbbws.Bowler IS NOT NULL
    GROUP BY bbbws.Bowler, bbbws.Season_Id
    ORDER BY Bowling_Average ASC
)
SELECT p.Player_Name, ba.Season_Id, ba.Bowling_Average
FROM Bowling_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id 
WHERE ba.Bowling_Average IS NOT NULL 
	AND p.Player_Id IN
    (SELECT Player_Id FROM Bowling_Averages 
    GROUP BY Player_Id 
    HAVING COUNT(Season_Id) > 3 AND SUM(Season_wickets) > 30 AND SUM(Season_runs_given)/SUM(Season_wickets) < 25
    )
ORDER BY p.Player_Name, ba.Season_Id;















-- SUBJECTIVE QUESTIONS
-- 1. How does toss decision have affected the result of the match ? (which visualisations could be used to better present your answer) And is the impact limited to only specific venues?
WITH toss_winner_as_match_winner AS (
SELECT
	Venue_Id,
    	COUNT(CASE WHEN Toss_Decide = 1 THEN 1 END) AS Fielding_first,
	COUNT(CASE WHEN Toss_Decide = 2 THEN 1 END) AS Batting_first
FROM matches
WHERE Toss_Winner = Match_Winner
GROUP BY Venue_Id
)
SELECT 
	v.Venue_Name,
   	 Fielding_first+Batting_first AS No_of_matches,
	ROUND((Fielding_first/(Fielding_first+Batting_first))*100,2) AS Field_first_win_perc, 
	ROUND((Batting_first/(Fielding_first+Batting_first))*100,2) AS Bat_first_win_perc
FROM toss_winner_as_match_winner twmw
JOIN venue v ON v.Venue_Id = twmw.Venue_Id;










-- 2. Suggest some of the players who would be best fit for the team?
-- For Exceptionally Consistent Batsmen
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Batting_Averages AS (
    SELECT 
        bbbws.Striker AS Player_Id,
        bbbws.Season_Id,
        SUM(bs.Runs_Scored) AS Season_Runs_Scored,
        COUNT(wt.Player_Out) AS Season_Outs,
        ROUND(SUM(bs.Runs_Scored)/
        COUNT(wt.Player_Out),2) AS Batting_Average
    FROM batsman_scored bs
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    LEFT JOIN wicket_taken wt 
        ON bbbws.Striker = wt.Player_Out 
        AND bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
    GROUP BY bbbws.Striker, bbbws.Season_Id
    ORDER BY bbbws.Striker, bbbws.Season_Id
),
Exceptionally_consistent_batsmen AS (
SELECT p.Player_Name, ba.Season_Id, ba.Batting_Average
FROM Batting_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id
WHERE ba.Batting_Average IS NOT NULL 
	AND p.Player_Id IN 
		(SELECT Player_Id FROM Batting_Averages 
        GROUP BY Player_Id 
        HAVING COUNT(Season_Id) > 4 AND SUM(Season_Runs_Scored) >= 900 AND SUM(Season_Runs_Scored)/SUM(Season_Outs) > 38
        )
ORDER BY p.Player_Name, ba.Season_Id ASC
)
SELECT DISTINCT Player_Name FROM Exceptionally_consistent_batsmen;




-- For Exceptionally Consistent Bowlers
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Bowling_Averages AS (
    SELECT 
        bbbws.Bowler AS Player_Id, 
        bbbws.Season_Id,
        SUM(bs.runs_scored) AS Season_runs_given,
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END) AS Season_wickets,
        ROUND(SUM(bs.runs_scored)/
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END),2) AS Bowling_Average
    FROM Ball_by_Ball_with_Seasons bbbws 
    LEFT JOIN wicket_taken wt
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
	LEFT JOIN batsman_scored bs
		 ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    WHERE bbbws.Bowler IS NOT NULL
    GROUP BY bbbws.Bowler, bbbws.Season_Id
    ORDER BY Bowling_Average ASC
),
Exceptionally_consistent_bowlers AS (
SELECT p.Player_Name, ba.Season_Id, ba.Bowling_Average
FROM Bowling_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id 
WHERE ba.Bowling_Average IS NOT NULL 
	AND p.Player_Id IN
    (SELECT Player_Id FROM Bowling_Averages 
    GROUP BY Player_Id 
    HAVING COUNT(Season_Id) > 3 AND SUM(Season_wickets) >= 35 AND SUM(Season_runs_given)/SUM(Season_wickets) <= 22
    )
ORDER BY p.Player_Name, ba.Season_Id
)
SELECT DISTINCT Player_Name FROM Exceptionally_consistent_bowlers;




-- For Young Talents from India
SELECT Player_Name AS Youngsters 
FROM player 
WHERE 2017 - YEAR(DOB) BETWEEN 18 AND 23 
	AND Country_Name = (SELECT Country_Id FROM country WHERE Country_Name = 'India');





-- For Highly effective All-Rounders
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Batting_Averages AS (
    SELECT 
        bbbws.Striker AS Player_Id,
        bbbws.Season_Id,
        SUM(bs.Runs_Scored) AS Season_Runs_Scored,
        COUNT(wt.Player_Out) AS Season_Outs,
        ROUND(SUM(bs.Runs_Scored)/
        COUNT(wt.Player_Out),2) AS Batting_Average
    FROM batsman_scored bs
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    LEFT JOIN wicket_taken wt 
        ON bbbws.Striker = wt.Player_Out 
        AND bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
    GROUP BY bbbws.Striker, bbbws.Season_Id
    ORDER BY bbbws.Striker, bbbws.Season_Id
),
Seasonwise_batting_averages AS (
SELECT p.Player_Name, c.Country_Name, ba.Season_Id, ba.Season_Runs_Scored, ba.Batting_Average 
FROM Batting_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id
JOIN country c ON p.Country_Name = c.Country_Id
WHERE ba.Batting_Average IS NOT NULL 
	AND p.Player_Id IN 
		(SELECT Player_Id FROM Batting_Averages 
        GROUP BY Player_Id 
        HAVING COUNT(Season_Id) > 4 AND SUM(Season_Runs_Scored) > 500 AND SUM(Season_Runs_Scored)/SUM(Season_Outs) > 23
        )
ORDER BY p.Player_Name, ba.Season_Id ASC
),
Bowling_Averages AS (
    SELECT 
        bbbws.Bowler AS Player_Id, 
        bbbws.Season_Id,
        SUM(bs.runs_scored) AS Season_runs_given,
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END) AS Season_wickets,
        ROUND(SUM(bs.runs_scored)/
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END),2) AS Bowling_Average
    FROM Ball_by_Ball_with_Seasons bbbws 
    LEFT JOIN wicket_taken wt
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
	LEFT JOIN batsman_scored bs
		 ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    WHERE bbbws.Bowler IS NOT NULL
    GROUP BY bbbws.Bowler, bbbws.Season_Id
    ORDER BY Bowling_Average ASC
),
Seasonwise_bowling_averages AS(
SELECT p.Player_Name, c.Country_Name, ba.Season_Id, ba.Season_wickets, ba.Bowling_Average
FROM Bowling_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id
JOIN country c ON p.Country_Name = c.Country_Id
WHERE ba.Bowling_Average IS NOT NULL 
	AND p.Player_Id IN
    (SELECT Player_Id FROM Bowling_Averages 
    GROUP BY Player_Id 
    HAVING COUNT(Season_Id) > 4 AND SUM(Season_wickets) > 20 AND SUM(Season_runs_given)/SUM(Season_wickets) < 30
    )
ORDER BY p.Player_Name, ba.Season_Id
)
SELECT sboa.Player_Name, sboa.Country_Name, sbaa.Season_Id, sbaa.Season_Runs_Scored, sbaa.Batting_Average, sboa.Season_wickets, sboa.Bowling_Average 
FROM Seasonwise_bowling_averages sboa
JOIN Seasonwise_batting_averages sbaa ON sboa.Player_Name = sbaa.Player_Name AND sboa.Season_Id = sbaa.Season_Id;










-- 3. What are some of parameters that should be focused while selecting the players?
-- Average Runs Scored by Batsmen
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Runs_scored_per_season AS (
    SELECT 
        bbbws.Striker AS Player_Id,
        bbbws.Season_Id,
        SUM(bs.Runs_Scored) AS Runs_Scored_in_Season
    FROM batsman_scored bs
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    GROUP BY bbbws.Striker, bbbws.Season_Id
),
Average_runs_scored_by_each_player_in_seasons AS (
    SELECT 
        Player_Id,
        ROUND(AVG(Runs_Scored_in_Season), 2) AS Avg_runs_in_seasons
    FROM Runs_scored_per_season
    GROUP BY Player_Id
    HAVING COUNT(DISTINCT Season_Id) > 1
),
Average_Runs AS (
    SELECT 
        p.Player_Name, 
        ars.Avg_runs_in_seasons AS Avg_Runs_Scored
    FROM Average_runs_scored_by_each_player_in_seasons ars
    JOIN player p ON p.Player_Id = ars.Player_Id
    ORDER BY Avg_Runs_Scored DESC
)
SELECT * FROM Average_Runs;




-- 6s/4s Count 
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
sixes_count AS (
SELECT bbbws.Striker, COUNT(*) AS sixes
FROM batsman_scored bs
LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
	ON bbbws.Match_Id = bs.Match_Id 
    AND bbbws.Innings_No = bs.Innings_No 
    AND bbbws.Over_Id = bs.Over_Id 
    AND bbbws.Ball_Id = bs.Ball_Id
WHERE bs.Runs_Scored = 6
GROUP BY bbbws.Striker
)
SELECT p.Player_Name, sixes
FROM sixes_count sc
JOIN Player p ON sc.Striker = p.Player_Id
ORDER BY sixes DESC;




-- Strike Rates of Batsmen
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
)
SELECT p.Player_Name, ROUND((SUM(bs.Runs_Scored)/COUNT(bs.Ball_Id))*100,2) AS Strike_Rate
FROM Ball_by_Ball_with_Seasons bbbws
LEFT JOIN batsman_scored bs 
	ON bs.Match_Id = bbbws.Match_Id 
    AND bs.Innings_No = bbbws.Innings_No 
    AND bs.Over_Id = bbbws.Over_Id 
    AND bs.Ball_Id = bbbws.Ball_Id
JOIN Player p ON p.Player_Id = bbbws.Striker
GROUP BY bbbws.Striker
HAVING SUM(bs.Runs_Scored) > 0
ORDER BY Strike_Rate DESC;










-- Average Wickets Taken by Bowlers
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Wickets_taken_per_season AS (
    SELECT 
        bbbws.Bowler AS Player_Id, 
        bbbws.Season_Id,
        COUNT(*) AS Wickets_in_Season
    FROM wicket_taken wt
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
    WHERE wt.Kind_Out NOT IN (3, 5, 9) 
    GROUP BY bbbws.Bowler, bbbws.Season_Id
),
Avg_wickets_taken_by_each_player_in_seasons AS (
    SELECT 
        Player_Id, 
        COUNT(DISTINCT Season_Id) AS No_of_Seasons_Played,
        SUM(Wickets_in_Season) AS Total_Wickets,
        ROUND(AVG(Wickets_in_Season), 2) AS Avg_wickets_in_seasons
    FROM Wickets_taken_per_season
    GROUP BY Player_Id
    HAVING COUNT(DISTINCT Season_Id) > 1
),
Average_Wickets AS (
    SELECT 
        p.Player_Name, 
        awt.Avg_wickets_in_seasons
    FROM Avg_wickets_taken_by_each_player_in_seasons awt
    JOIN player p ON p.Player_Id = awt.Player_Id
    ORDER BY awt.Avg_wickets_in_seasons DESC
)
SELECT * FROM Average_Wickets;




-- 4/5 Wicket Hauls
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
four_wickets AS (
SELECT bbbws.Bowler, bbbws.Match_Id, COUNT(*) 
FROM wicket_taken wt
LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
WHERE wt.Kind_Out NOT IN (3,5,9)
GROUP BY bbbws.Bowler, bbbws.Match_Id
HAVING COUNT(*) = 4
ORDER BY Bowler
)
SELECT p.Player_Name, COUNT(*) AS Four_wicket_hauls
FROM four_wickets fw
JOIN Player p ON fw.Bowler = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Four_wicket_hauls DESC;



-- Economy Rates of Bowlers
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
)
SELECT p.Player_Name, ROUND((SUM(bs.Runs_Scored)*6/COUNT(bs.Ball_Id)),2) AS Economy_Rate
FROM batsman_scored bs
LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
	ON bs.Match_Id = bbbws.Match_Id 
    AND bs.Innings_No = bbbws.Innings_No 
    AND bs.Over_Id = bbbws.Over_Id 
    AND bs.Ball_Id = bbbws.Ball_Id
JOIN Player p ON p.Player_Id = bbbws.Striker
GROUP BY bbbws.Striker
ORDER BY Economy_Rate DESC;










-- 4. Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)
WITH Ball_by_Ball_with_Seasons AS (
    SELECT bb.*, m.Season_Id
    FROM matches m
    JOIN Ball_by_ball bb ON m.Match_Id = bb.Match_Id
    ORDER BY Match_Id, Innings_No, Over_Id, Ball_Id
),
Batting_Averages AS (
    SELECT 
        bbbws.Striker AS Player_Id,
        bbbws.Season_Id,
        SUM(bs.Runs_Scored) AS Season_Runs_Scored,
        COUNT(wt.Player_Out) AS Season_Outs,
        ROUND(SUM(bs.Runs_Scored)/
        COUNT(wt.Player_Out),2) AS Batting_Average
    FROM batsman_scored bs
    LEFT JOIN Ball_by_Ball_with_Seasons bbbws 
        ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    LEFT JOIN wicket_taken wt 
        ON bbbws.Striker = wt.Player_Out 
        AND bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
    GROUP BY bbbws.Striker, bbbws.Season_Id
    ORDER BY bbbws.Striker, bbbws.Season_Id
),
Seasonwise_batting_averages AS (
SELECT p.Player_Name, c.Country_Name, ba.Season_Id, ba.Season_Runs_Scored, ba.Batting_Average 
FROM Batting_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id
JOIN country c ON p.Country_Name = c.Country_Id
WHERE ba.Batting_Average IS NOT NULL 
	AND p.Player_Id IN 
		(SELECT Player_Id FROM Batting_Averages 
        GROUP BY Player_Id 
        HAVING COUNT(Season_Id) > 3 AND SUM(Season_Runs_Scored) > 500 AND SUM(Season_Runs_Scored)/SUM(Season_Outs) > 20
        )
ORDER BY p.Player_Name, ba.Season_Id ASC
),

Bowling_Averages AS (
    SELECT 
        bbbws.Bowler AS Player_Id, 
        bbbws.Season_Id,
        SUM(bs.runs_scored) AS Season_runs_given,
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END) AS Season_wickets,
        ROUND(SUM(bs.runs_scored)/
        SUM(CASE WHEN wt.Kind_Out IS NOT NULL AND wt.Kind_Out NOT IN (3, 5, 9) THEN 1 ELSE 0 END),2) AS Bowling_Average
    FROM Ball_by_Ball_with_Seasons bbbws 
    LEFT JOIN wicket_taken wt
        ON bbbws.Match_Id = wt.Match_Id 
        AND bbbws.Innings_No = wt.Innings_No 
        AND bbbws.Over_Id = wt.Over_Id 
        AND bbbws.Ball_Id = wt.Ball_Id
	LEFT JOIN batsman_scored bs
		 ON bbbws.Match_Id = bs.Match_Id 
        AND bbbws.Innings_No = bs.Innings_No 
        AND bbbws.Over_Id = bs.Over_Id 
        AND bbbws.Ball_Id = bs.Ball_Id
    WHERE bbbws.Bowler IS NOT NULL
    GROUP BY bbbws.Bowler, bbbws.Season_Id
    ORDER BY Bowling_Average ASC
),
Seasonwise_bowling_averages AS(
SELECT p.Player_Name, c.Country_Name, ba.Season_Id, ba.Season_wickets, ba.Bowling_Average
FROM Bowling_Averages ba
JOIN player p ON p.Player_Id = ba.Player_Id
JOIN country c ON p.Country_Name = c.Country_Id
WHERE ba.Bowling_Average IS NOT NULL 
	AND p.Player_Id IN
    (SELECT Player_Id FROM Bowling_Averages 
    GROUP BY Player_Id 
    HAVING COUNT(Season_Id) > 3 AND SUM(Season_wickets) > 20 AND SUM(Season_runs_given)/SUM(Season_wickets) < 30
    )
ORDER BY p.Player_Name, ba.Season_Id
)
SELECT sboa.Player_Name, sboa.Country_Name, sbaa.Season_Id, sbaa.Season_Runs_Scored, sbaa.Batting_Average, sboa.Season_wickets, sboa.Bowling_Average 
FROM Seasonwise_bowling_averages sboa
JOIN Seasonwise_batting_averages sbaa ON sboa.Player_Name = sbaa.Player_Name AND sboa.Season_Id = sbaa.Season_Id;


