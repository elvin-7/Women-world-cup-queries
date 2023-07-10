--creating a table for worldcup games
CREATE TABLE w_worldcup
	(match_date date
	,home_team nvarchar(100)
	,away_team nvarchar(100)
	,home_score int
	,away_score int
	,country nvarchar(100)
	,neutral varchar(10)
)

-- Inserting worldcup games into the table above
INSERT INTO w_worldcup
SELECT 
	date
	,home_team
	,away_team
	,home_score
	,away_score
	,country
	,neutral 
FROM 
	[women's matches]
WHERE 
	tournament='FIFA World Cup'

--selecting all women's world cup tournaments 
SELECT 
	DISTINCT YEAR(match_date) as tournament_year
	,country as host_nation
FROM 
	w_worldcup

--1) Number of times each country has hosted the tournament
SELECT 
	host_nation	
	,COUNT(host_nation) as No_of_tournaments_hosted 
FROM
	(
	 SELECT 
		DISTINCT YEAR(match_date) as wc_year
		,country as host_nation
	 FROM 
	 w_worldcup
				)WC_hosts
GROUP BY 
	host_nation
ORDER BY 
	No_of_tournaments_hosted desc

--2) which team has won the most matches
SELECT 
	DISTINCT results as Team
	,COUNT(results) as Number_of_wins
FROM
	(
	 SELECT 
		match_date
		,home_team
		,away_team
		,home_score
		,away_score
		,country
		,neutral 
		,CASE WHEN home_score>away_score THEN home_team
		WHEN away_score>home_score THEN away_team 
		ELSE 'Draw' 
		END AS results
	 FROM 
		w_worldcup
					) AS results
WHERE 
	results <> 'Draw'
GROUP BY
	results
ORDER BY
	Number_of_wins DESC

--3)winning percentage
WITH gamesplayed AS
(
	SELECT 
		DISTINCT home_team
		,COUNT(home_team)played
	FROM 
		w_worldcup
	GROUP BY home_team
	UNION 
	SELECT 
		DISTINCT away_team
		,COUNT(away_team)played
	FROM 
		w_worldcup
	GROUP BY 
		away_team
					)--combines home and away teams in one column and counts the number of times matches have been played
,wins AS
		(
		 SELECT 
			DISTINCT results as team
			,COUNT(results) as Number_of_wins
		 FROM(
			  SELECT 
					match_date
					,home_team
					,away_team
					,home_score
					,away_score
					,country
					,neutral  
					,case when home_score>away_score then home_team
					when away_score>home_score then away_team else 'Draw' end as results
			  FROM 
					w_worldcup) results
		 WHERE 
				results <> 'Draw'
		 GROUP BY 
				results
				)
,games_played_and_wins AS
				 (
					SELECT 
						DISTINCT home_team as Team
						,SUM(played) as games_played
						,ISNULL(Number_of_wins,0) as wins --Returns 0 where the cell is null 
					FROM gamesplayed
					LEFT JOIN
					wins ON 
							gamesplayed.home_team = wins.team
					GROUP BY 
							home_team
							,Number_of_wins
					)

SELECT 
	  Team
	  ,games_played
	  ,wins
	  ,FORMAT(
				(CONVERT	
						(decimal(7,2),wins)/games_played)*100
						,'F')as win_percentage --Formats numbers to two decimal places
FROM 
	games_played_and_wins
ORDER BY 
		win_percentage DESC
		,games_played DESC
		,wins DESC
		,Team

--4) Number of tournament appearances for each team
SELECT 
	DISTINCT home_team AS team
	,COUNT(home_team) AS appearances
FROM
	(
	SELECT 
		DISTINCT YEAR(match_date) AS tournament_year
		,home_team
	FROM
		w_worldcup
	UNION
	SELECT 
		DISTINCT YEAR(match_date)	
		,away_team
	FROM w_worldcup
	)AS participating_teams
	GROUP BY 
		home_team
	ORDER BY 
		appearances DESC

--5) Highest scoring matches
SELECT TOP(10)
		match_date
		,home_team
		,away_team
		,home_score
		,away_score
		,country  
		,home_score+away_score as total_score
FROM 
		w_worldcup
GROUP BY 
		match_date
		,home_team
		,away_team
		,home_score
		,away_score
		,country
ORDER BY 
		total_score DESC

--6) Number of goals scored for each country
SELECT 
	DISTINCT home_team AS team
	,SUM(goals) AS goals_scored
FROM
	(
	 SELECT 
		DISTINCT home_team
		,SUM(home_score) AS goals
	 FROM 
		w_worldcup
	 GROUP BY 
		home_team
	 UNION ALL
	 SELECT 
		DISTINCT away_team
		,SUM(away_score)
	 FROM w_worldcup
	 GROUP BY away_team
	 ) AS Number_of_goals_scored
GROUP BY 
	home_team
ORDER BY 
	goals_scored DESC

--adding a match id column
ALTER TABLE 
	w_worldcup
ADD 
	match_id int identity(1,1)
	
go

--7) Calculating win streaks in the tournament
WITH match_results AS(  --calculates the results for each game including penalty results
	SELECT
		match_id
		,match_date
		,full_time_results.home_team
		,full_time_results.away_team
		,home_score
		,away_score
		,country
		,neutral  
		,CASE WHEN home_score > away_score THEN full_time_results.home_team
		WHEN away_score > home_score THEN full_time_results.away_team
		WHEN home_score = away_score THEN ISNULL(penalty_results.winner,'Draw')--returns draw if the game didn't go to penalties after a draw.
		END AS results
	FROM 
		w_worldcup AS full_time_results
	LEFT JOIN
		shootouts AS penalty_results
	ON 
		full_time_results.match_date = penalty_results.date
		AND
		full_time_results.home_team = penalty_results.home_team
		AND
		full_time_results.away_team = penalty_results.away_team
		)
,teams AS  --shows all teams that have a world cup appearance 
	(
	SELECT 
		home_team AS team
	FROM
		w_worldcup
	UNION
	SELECT 
		away_team
	FROM w_worldcup
	)
,did_win AS(    --shows all world cup games and the teams that played in them and shows if the team won that game
	SELECT
		match_id
		,match_date
		,team
		,CASE WHEN results = team THEN 1
		ELSE 0
		END AS did_team_win
	FROM
		match_results as result
	LEFT JOIN
		teams
	ON
		home_team = team OR away_team = team
		)
SELECT TOP(10)
	team
	,COUNT(*) AS win_streak        --when we filter out non-win results and count the number of rows for each group of team and dummy, we get the number of consecutive wins for each group.
	,MIN(match_date) AS start_date
	,MAX(match_date) AS end_date
FROM
	(
		SELECT            
			match_date
			,team
			,did_team_win
			,SUM(CASE WHEN did_team_win <> 1 THEN 1 ELSE 0 END) OVER(PARTITION BY team   --dummy column stays the same when the result is a win for the same team and increases by one when the result is not a win
			ORDER BY match_date ROWS UNBOUNDED PRECEDING) AS dummy						 --this helps to group consecutive wins for a particular team since it only changes when there isn't a win
		FROM
			did_win
			) win_streaks
WHERE
	did_team_win=1
GROUP BY 
	team
	,dummy
ORDER BY
	win_streak DESC


--8) Top 3 finishes for each competition
WITH finals AS
	(
	SELECT
		match_id
		,match_date
		,home_team
		,away_team
		,home_score
		,away_score
		,country
		,result
	FROM
		(
		SELECT
			match_id
			,match_date
			,full_time.home_team
			,full_time.away_team
			,home_score
			,away_score
			,country
			,CASE WHEN home_score > away_score THEN full_time.home_team
			WHEN away_score > home_score THEN full_time.away_team
			ELSE pens.winner END AS result
			,ROW_NUMBER()OVER(PARTITION BY YEAR(match_date) ORDER BY match_date DESC, match_id DESC) AS rn --Assigns a number to each match played in each tournament starting with the final i.e 1 is the final game, 2 is the third and fourth play-off and 3 and 4 would be the semi-final games
		FROM
			w_worldcup AS full_time
		LEFT JOIN
			shootouts AS pens
		ON full_time.match_date=pens.date and full_time.home_team=pens.home_team
		) AS match_results
	WHERE 
		rn = 1
		)
, third_place AS 
	(
	SELECT
		match_id
		,match_date
		,home_team
		,away_team
		,home_score
		,away_score
		,country
		,result
	FROM
		(
		SELECT
			match_id
			,match_date
			,full_time.home_team
			,full_time.away_team
			,home_score
			,away_score
			,country
			,CASE WHEN home_score > away_score THEN full_time.home_team
			WHEN away_score > home_score THEN full_time.away_team
			ELSE pens.winner END AS result
			,ROW_NUMBER()OVER(PARTITION BY YEAR(match_date) ORDER BY match_date DESC, match_id DESC) AS rn
		FROM
			w_worldcup AS full_time
		LEFT JOIN
			shootouts AS pens
		ON full_time.match_date=pens.date and full_time.home_team=pens.home_team
		) AS match_results
	WHERE 
		rn = 2
		)

SELECT 
	YEAR(finals.match_date) as Tournament_year
	,finals.country as Host_nation
	,finals.result as Gold
	,CASE WHEN finals.result = finals.home_team THEN finals.away_team
	WHEN finals.result = finals.away_team THEN finals.home_team
	END AS Silver
	,third_place.result as Bronze
FROM
	finals
JOIN
	third_place
ON
	YEAR(finals.match_date) = YEAR(third_place.match_date)

--9) Most recurring scorelines
SELECT 
	scoreline
	,count(scoreline) as scoreline_count
FROM
	(
	SELECT
		CONCAT(home_score , '-' , away_score) AS scoreline
	FROM
		w_worldcup
		)as scores
GROUP BY 
	scoreline
ORDER BY
	scorecount DESC