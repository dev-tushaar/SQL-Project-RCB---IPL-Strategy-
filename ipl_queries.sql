-- objective questions

-- question 1: list the different dtypes of columns in table “ball_by_ball”.
select column_name, data_type
from information_schema.columns
where table_name = 'ball_by_ball'
and table_schema = 'ipl';

-- question 2: what is the total number of runs scored in 6th season by rcb?
with rcb_matches as
(select * from matches
where season_id = 6
and (team_1 = 2 or team_2 = 2)),
rcb_batting_runs as 
(select 
match_id, 
innings_no, 
sum(runs_scored) as total_runs 
from ball_by_ball
where match_id in (select match_id from rcb_matches)
and team_batting = 2
group by match_id, innings_no),
rcb_extra_runs as
(select 
  match_id, 
  innings_no, 
  sum(extra_runs) as total_extra_runs 
from extra_runs
where match_id in (select match_id from rcb_matches)
group by match_id, innings_no)
select 
  sum(total_runs) + sum(total_extra_runs) as runs_scored_in_season
from rcb_batting_runs rbr 
left join rcb_extra_runs rer 
on rbr.match_id = rer.match_id 
and rbr.innings_no = rer.innings_no;

-- question 3: how many players were more than the age of 25 during season 2014?
with season2014 as
(select * from player
where player_id in 
(select player_id from player_match where match_id in 
(select match_id from matches where season_id in 
(select season_id from season where season_year = '2014')))),
player_age as
(select player_id, timestampdiff(year, dob, '2014-01-01') as age from season2014)
select count(distinct player_id) as player_count from player_age where age > 25;

-- question 4: how many matches did rcb win in 2013? 
select count(*) as rcb_wins from matches
where match_id in 
(select match_id from matches where season_id in 
(select season_id from season where season_year = '2013'))
and match_winner = 2;

-- question 5: list the top 10 players according to their strike rate in the last 4 seasons.
with seasonstable as
(select season_id, 
dense_rank() over(order by season_year desc) as season_rank
from season)
select 
player_name, 
sum(runs_scored) as runs_scored, 
count(ball_id) as balls_played,
count(distinct match_id) as matches_played,
round(100*sum(runs_scored)/count(ball_id),2) as strike_rate
from ball_by_ball bb join player p on p.player_id = bb.striker
where match_id in 
(select match_id from matches where season_id in 
(select season_id from seasonstable where season_rank <= 4))
group by player_name
having count(ball_id) >0
order by strike_rate desc
limit 10;

-- question 6: what are the average runs scored by each batsman considering all the seasons?
with avg_runs_table as 
(select 
striker,
sum(runs_scored) as total_runs,
count(distinct match_id) as matches_played,
round(sum(runs_scored)/count(distinct match_id),2) as avg_runs
from ball_by_ball
group by striker
order by avg_runs desc)
select p.player_name, ar.avg_runs, dense_rank() over(order by avg_runs desc) as 'rank'
from player p join avg_runs_table ar on p.player_id = ar.striker;

-- question 7: what are the average wickets taken by each bowler considering all the seasons?
with bowler_wickets as
(select wt.match_id, b.bowler, wt.player_out from wicket_taken wt left join ball_by_ball b
on b.match_id = wt.match_id
and b.innings_no = wt.innings_no
and b.over_id = wt.over_id
and b.ball_id = wt.ball_id)
select 
dense_rank() over(order by round(count(player_out)/count(distinct match_id),2) desc) as 'rank',
p.player_name, 
count(player_out) as wickets_taken,
count(distinct match_id) as matches_played,
round(count(player_out)/count(distinct match_id),2) as avg_wickets_taken
from bowler_wickets b join player p on b.bowler = p.player_id
group by p.player_name;

-- question 8: list all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average.
with bowler_wickets as
(select wt.match_id, b.bowler, wt.player_out from wicket_taken wt left join ball_by_ball b
on b.match_id = wt.match_id
and b.innings_no = wt.innings_no
and b.over_id = wt.over_id
and b.ball_id = wt.ball_id),
avg_wickets as
(select 
p.player_name, 
round(count(player_out)/count(distinct match_id),2) as avg_wickets_taken
from bowler_wickets b join player p on b.bowler = p.player_id
group by p.player_name),
avg_runs_table as
(select 
p.player_name,
round(sum(runs_scored)/count(distinct match_id),2) as avg_runs
from ball_by_ball b
join player p  on p.player_id = b.striker
group by p.player_name
order by avg_runs desc),
above_avg_wickets as
(select player_name from avg_wickets 
where avg_wickets_taken > 
(select avg(avg_wickets_taken) from avg_wickets)
order by avg_wickets_taken desc
limit 5),
above_avg_scorers as
(select player_name from avg_runs_table 
where avg_runs > 
(select avg(avg_runs) from avg_runs_table)
order by avg_runs desc
limit 5)
select player_name, case when player_name is not null then 'bowler' else "" end as player_type from above_avg_wickets
union
select player_name, case when player_name is not null then 'batsman' else "" end as player_type from above_avg_scorers;

-- question 9: create a table rcb_record table that shows the wins and losses of rcb in an individual venue.
with rcb_records as
(select
  v.venue_name,
  count(*) as total_matches,
  sum(case when match_winner = 2 then 1 else 0 end) as rcb_wins,
  sum(case when match_winner <> 2 then 1 else 0 end) as rcb_loses,
  sum(case when match_winner is null then 1 else 0 end) as no_result
from matches m join venue v on v.venue_id = m.venue_id
where team_1 = 2 or team_2 = 2
group by v.venue_name)
select * from rcb_records;

-- question 10: what is the impact of bowling style on wickets taken?
select
bs.bowling_skill,
count(wt.player_out) as total_wickets  
from wicket_taken wt 
join ball_by_ball bb
on wt.match_id = bb.match_id
and wt.innings_no = bb.innings_no
and wt.over_id = bb.over_id
and wt.ball_id = bb.over_id
join player p on p.player_id = bb.bowler
join bowling_style bs on bs.bowling_id = p.bowling_skill
group by bowling_skill
order by total_wickets desc;

-- question 11: write the sql query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken
with yearwisetable as
(select s.season_year, bb.team_batting, bb.team_bowling, bb.runs_scored, wt.player_out
from ball_by_ball bb
left join wicket_taken wt on bb.match_id = wt.match_id and wt.innings_no = bb.innings_no
and bb.over_id = wt.over_id and bb.ball_id = wt.ball_id
join matches m on m.match_id = bb.match_id
join season s on s.season_id = m.season_id),
batting_table as
(select season_year, t.team_name, sum(runs_scored) as yearly_runs from yearwisetable y join team t on y.team_batting = t.team_id
group by season_year, t.team_name),
bowling_table as 
(select season_year, t.team_name, count(player_out) as yearly_wickets from yearwisetable y join team t on y.team_bowling = t.team_id
group by season_year, t.team_name),
year_record_table as
(select bt.season_year, bt.team_name, bt.yearly_runs as this_year_runs, 
coalesce (lag(yearly_runs) over(partition by team_name order by season_year), 'not_available') as previous_year_runs,
bw.yearly_wickets as this_year_wickets,
coalesce (lag(yearly_wickets) over(partition by team_name order by season_year), 'not_available') as previous_year_wickets
from batting_table bt
left join bowling_table bw on bt.season_year = bw.season_year and bt.team_name = bw.team_name
order by team_name, season_year, yearly_runs desc, yearly_wickets desc)
select season_year, team_name, this_year_runs, previous_year_runs, this_year_wickets, previous_year_wickets,
case when this_year_runs > previous_year_runs and this_year_wickets > previous_year_wickets then 'overall improved'
when this_year_runs > previous_year_runs and this_year_wickets < previous_year_wickets then 'batting improved'
when this_year_runs < previous_year_runs and this_year_wickets > previous_year_wickets then 'bowling improved'
when this_year_runs = previous_year_runs and this_year_wickets = previous_year_wickets then 'same'
else 'decline'
end as performance
from year_record_table
where team_name = 'royal challengers bangalore';

-- question 12: can you derive more kpis for the team strategy?
with top_order_stats as
(select bb.match_id, t.team_name,
sum(runs_scored) as top_order_runs,
tr.total_runs
 from ball_by_ball bb join team t on t.team_id = bb.team_batting
join (select match_id, sum(runs_scored) as total_runs from ball_by_ball where team_batting = 2 group by match_id) tr on bb.match_id = tr.match_id
where bb.striker_batting_position <= 3
and t.team_name = 'royal challengers bangalore'
group by match_id),
powerplay_stats as (
    select 
        m.match_id, 
        t.team_name, 
        sum(bb.runs_scored) as powerplay_runs,
        count(case when wt.player_out is not null then 1 end) as wickets_lost
    from matches m
    inner join ball_by_ball bb on m.match_id = bb.match_id
    inner join team t on t.team_id = bb.team_batting
    left join wicket_taken wt 
        on bb.match_id = wt.match_id 
        and bb.innings_no = wt.innings_no
        and bb.over_id = wt.over_id 
        and bb.ball_id = wt.ball_id
    where 
        bb.over_id between 1 and 6 
        and t.team_name = 'royal challengers bangalore'
    group by m.match_id, t.team_name
),
death_overs_stats as (
    select 
        m.match_id, 
        t.team_name, 
        sum(bb.runs_scored) as death_overs_runs,
        count(bb.ball_id) as balls_faced
    from matches m
    inner join ball_by_ball bb on m.match_id = bb.match_id
    inner join team t on t.team_id = bb.team_batting
    where 
        bb.over_id between 17 and 20 
        and t.team_name = 'royal challengers bangalore'
    group by m.match_id, t.team_name
),
boundary_stats as (
    select 
        m.match_id, 
        t.team_name,
        sum(case when bb.runs_scored in (4, 6) then 1 else 0 end) as boundaries,
        count(bb.ball_id) as total_balls
    from matches m
    inner join ball_by_ball bb on m.match_id = bb.match_id
    inner join team t on t.team_id = bb.team_batting
    where t.team_name = 'royal challengers bangalore'
    group by m.match_id, t.team_name
)
select 
    p.team_name, 
    round(avg(p.powerplay_runs), 2) as avg_powerplay_runs,
    round(avg(p.wickets_lost), 2) as avg_wickets_lost_powerplay,
    round(avg(d.death_overs_runs / d.balls_faced * 100), 2) as avg_death_overs_strike_rate,
    round(avg(b.boundaries), 2) as avg_boundaries_per_match,
    round(avg(nullif(b.total_balls, 0) / nullif(b.boundaries, 0)), 2) as balls_per_boundary,
    round(avg(s.top_order_runs / s.total_runs * 100),2) as avg_top_order_contribution
from powerplay_stats p
join death_overs_stats d on p.team_name = d.team_name
join boundary_stats b on p.team_name = b.team_name
join top_order_stats s on s.match_id = p.match_id
group by p.team_name;
with powerplay_economy as (
    select 
        t.team_name,
        m.match_id, 
        sum(bb.runs_scored) as total_runs_scored,
        count(distinct bb.over_id) as total_overs
    from matches m
    inner join ball_by_ball bb on m.match_id = bb.match_id
    join team t on bb.team_bowling = t.team_id
    where 
        bb.over_id between 1 and 6
        and t.team_name = 'royal challengers bangalore'
    group by m.match_id
),
middle_overs_economy as (
    select 
        m.match_id, 
        sum(bb.runs_scored) as total_runs_scored,
        count(distinct bb.over_id) as total_overs
    from matches m
    inner join ball_by_ball bb on m.match_id = bb.match_id
    join team t on t.team_id = bb.team_bowling
    where 
        bb.over_id between 7 and 15
        and t.team_name = 'royal challengers bangalore'
    group by m.match_id
),
death_overs_economy as (
    select 
        m.match_id, 
        sum(bb.runs_scored) as total_runs_scored,
        count(distinct bb.over_id) as total_overs
    from matches m
    inner join ball_by_ball bb on m.match_id = bb.match_id
    join team t on t.team_id = bb.team_bowling
    where 
        bb.over_id between 16 and 20
        and t.team_name = 'royal challengers bangalore'
    group by m.match_id
)
select 
    pw.team_name,
    round(avg(pw.total_runs_scored / pw.total_overs),2) as avg_powerplay_economy,
    round(avg(md.total_runs_scored / md.total_overs),2) as avg_middle_overs_economy,
    round(avg(dth.total_runs_scored / dth.total_overs),2) as avg_death_overs_economy
from powerplay_economy pw,
     middle_overs_economy md,
     death_overs_economy dth
group by team_name;

-- question 13: using sql, write a query to find out the average wickets taken by each bowler in each venue. also, rank the gender according to the average value.
with wickets_per_venue as 
(select p.player_id, p.player_name, v.venue_name,
count(wt.player_out) as total_wickets, 
count(distinct m.match_id) as total_matches,
(count(wt.player_out) / count(distinct m.match_id)) as avg_wickets
from player p
join ball_by_ball bb on p.player_id = bb.bowler
join matches m on bb.match_id = m.match_id
join wicket_taken wt on bb.match_id = wt.match_id 
                               and bb.over_id = wt.over_id 
                               and bb.ball_id = wt.ball_id
join venue v on m.venue_id = v.venue_id
group by p.player_id, p.player_name, v.venue_name
)
select player_id, player_name, venue_name, total_wickets, total_matches, avg_wickets,
rank() over (order by avg_wickets desc) as wicket_rank
from wickets_per_venue
order by wicket_rank;

-- question 14: which of the given players have consistently performed well in past seasons?
with batsman_season as
(select  m.season_id, 
        p.player_name, 
        sum(case when p.player_id = bb.striker then bb.runs_scored else 0 end) as season_runs,
        count(distinct bb.match_id) as matches_played
from ball_by_ball bb join matches m on bb.match_id = m.match_id
join player p on bb.striker = p.player_id
group by m.season_id, p.player_name, p.player_id),
bowler_season as
(select  m.season_id, 
        p.player_name, 
        sum(case when p.player_id = bb.bowler and wt.player_out is not null then 1 else 0 end) as season_wickets,
        count(distinct bb.match_id) as matches_played
from ball_by_ball bb join matches m on bb.match_id = m.match_id
join player p on bb.striker = p.player_id or bb.bowler = p.player_id
left 
join wicket_taken wt 
on wt.match_id = bb.match_id 
and wt.innings_no = bb.innings_no 
and wt.over_id = bb.over_id 
and wt.ball_id = bb.ball_id 
group by m.season_id, p.player_name, p.player_id),
best_performing_bowlers as 
(select 
  row_number() over(order by sum(season_wickets)/count(distinct season_id) desc) as player_rank,
  player_name, 
  round(sum(season_wickets)/sum(matches_played),2) as avg_wicket_per_match, 
  round(sum(season_wickets)/count(distinct season_id),2) as avg_wicket_per_season
from bowler_season
group by player_name
order by avg_wicket_per_season desc
limit 5),
best_performing_batsman as
(select
  row_number () over(order by sum(season_runs)/count(distinct season_id) desc) as player_rank,
  player_name,
  round(sum(season_runs)/sum(matches_played),2) as avg_runs_per_match,
  round(sum(season_runs)/count(distinct season_id),2) as avg_runs_per_season
from batsman_season
group by player_name
order by avg_runs_per_season desc
limit 5)
select 
bow.player_name as best_bowlers,
bow.avg_wicket_per_match,
bow.avg_wicket_per_season,
 bat.player_name as best_batsmans,
bat.avg_runs_per_match,
bat.avg_runs_per_season
from
best_performing_bowlers bow
join
best_performing_batsman bat
on bow.player_rank = bat.player_rank;

-- question 15: are there players whose performance is more suited to specific venues or conditions?
with batsmans_venue_wise as
(select 
  v.venue_name,
  p.player_name as batsman,
  sum(bb.runs_scored) as total_runs,
  count(distinct bb.match_id) as matches_played,
  round(sum(bb.runs_scored)/count(distinct bb.match_id),2) as avg_runs,
  row_number() over(partition by p.player_name order by sum(bb.runs_scored) desc) as top_venue_rank,
  row_number() over(partition by p.player_name order by sum(bb.runs_scored)) as bottom_venue_rank
from ball_by_ball bb
left join matches m on m.match_id = bb.match_id
join venue v on v.venue_id = m.venue_id
join player p on bb.striker = p.player_id
group by venue_name, player_name
having count(distinct bb.match_id) > 5)
select venue_name, batsman, avg_runs from batsmans_venue_wise
where top_venue_rank = 1 or bottom_venue_rank = 1
order by batsman;


-- subjective questions

-- question 1: how does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) and is the impact limited to only specific venues?
select
  v.venue_name,
  td.toss_name as toss_decision,
  count(*) as total_matches,
  sum(case when m.toss_winner = m.match_winner then 1 else 0 end) as match_wins,
  round(100*sum(case when m.toss_winner = m.match_winner then 1 else 0 end)/count(*),2) as win_percentage
from matches m join venue v on v.venue_id = m.venue_id
join team t on t.team_id = m.toss_winner
join toss_decision td on td.toss_id = m.toss_decide
group by v.venue_name, td.toss_name
order by total_matches desc, win_percentage desc;

-- question 2: suggest some of the players who would be best fit for the team.
with best_batsmans as (
  select
    row_number() over(order by sum(runs_scored) desc, 100*sum(runs_scored)/count(ball_id) desc) as player_rank,
    p.player_name as batsman,
    sum(runs_scored) as total_runs,
    round(100*sum(runs_scored)/count(ball_id), 2) as strike_rate,
    count(distinct bb.match_id) as matches_played,
    round(sum(runs_scored) / count(distinct bb.match_id), 2) as avg_runs
  from ball_by_ball bb 
  join player p on bb.striker = p.player_id
  group by p.player_name
  order by total_runs desc, strike_rate desc
),
bowler_overs as (
  select 
    bowler, 
    sum(overs_bowled) as total_overs_bowled
  from (
    select bowler, match_id, count(distinct over_id) as overs_bowled 
    from ball_by_ball 
    group by bowler, match_id
  ) t
  group by bowler
),
best_bowlers as
(select 
  row_number() over(order by count(wt.player_out) desc) as player_rank,
  p.player_name as bowler,
  count(wt.player_out) as total_wickets,
  count(distinct bb.match_id) as matches_played,
  round(count(wt.player_out) / count(distinct bb.match_id), 2) as avg_wickets,
  round(sum(bb.runs_scored) / nullif(bo.total_overs_bowled, 0), 2) as economy
from ball_by_ball bb 
left join wicket_taken wt on bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and bb.over_id = wt.over_id and bb.ball_id = wt.ball_id
join player p on p.player_id = bb.bowler
join bowler_overs bo on bb.bowler = bo.bowler
group by p.player_name, bo.total_overs_bowled
order by total_wickets desc)
select 
  batsman as all_rounders,
  total_runs, strike_rate, avg_runs,
  total_wickets, economy, avg_wickets
from best_batsmans bat join best_bowlers bow on bat.batsman = bow.bowler
where total_runs > (select avg(total_runs) from best_batsmans)
and total_wickets > (select avg(total_wickets) from best_bowlers)
order by total_runs desc, total_wickets desc;

-- question 3: what are some of the parameters that should be focused on while selecting the players?
with best_batsmans as (
  select
    row_number() over(order by sum(runs_scored) desc, 100*sum(runs_scored)/count(ball_id) desc) as player_rank,
    p.player_name as batsman,
    sum(runs_scored) as total_runs,
    round(100*sum(runs_scored)/count(ball_id), 2) as strike_rate,
    count(distinct bb.match_id) as matches_played,
    round(sum(runs_scored) / count(distinct bb.match_id), 2) as avg_runs
  from ball_by_ball bb 
  join player p on bb.striker = p.player_id
  group by p.player_name
  order by total_runs desc, strike_rate desc
),
bowler_overs as (
  select 
    bowler, 
    sum(overs_bowled) as total_overs_bowled
  from (
    select bowler, match_id, count(distinct over_id) as overs_bowled 
    from ball_by_ball 
    group by bowler, match_id
  ) t
  group by bowler
),
best_bowlers as
(select 
  row_number() over(order by count(wt.player_out) desc) as player_rank,
  p.player_name as bowler,
  count(wt.player_out) as total_wickets,
  count(distinct bb.match_id) as matches_played,
  round(count(wt.player_out) / count(distinct bb.match_id), 2) as avg_wickets,
  round(sum(bb.runs_scored) / nullif(bo.total_overs_bowled, 0), 2) as economy
from ball_by_ball bb 
left join wicket_taken wt on bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and bb.over_id = wt.over_id and bb.ball_id = wt.ball_id
join player p on p.player_id = bb.bowler
join bowler_overs bo on bb.bowler = bo.bowler
group by p.player_name, bo.total_overs_bowled
order by total_wickets desc)
select 
  batsman as all_rounders,
  total_runs, strike_rate, avg_runs,
  total_wickets, economy, avg_wickets
from best_batsmans bat join best_bowlers bow on bat.batsman = bow.bowler
where total_runs > (select avg(total_runs) from best_batsmans)
and total_wickets > (select avg(total_wickets) from best_bowlers)
order by total_runs desc, total_wickets desc;

-- question 4: which players offer versatility in their skills and can contribute effectively with both bat and ball?
with best_batsmans as (
  select
    row_number() over(order by sum(runs_scored) desc, 100*sum(runs_scored)/count(ball_id) desc) as player_rank,
    p.player_name as batsman,
    sum(runs_scored) as total_runs,
    round(100*sum(runs_scored)/count(ball_id), 2) as strike_rate,
    count(distinct bb.match_id) as matches_played,
    round(sum(runs_scored) / count(distinct bb.match_id), 2) as avg_runs
  from ball_by_ball bb 
  join player p on bb.striker = p.player_id
  group by p.player_name
  order by total_runs desc, strike_rate desc
),
bowler_overs as (
  select 
    bowler, 
    sum(overs_bowled) as total_overs_bowled
  from (
    select bowler, match_id, count(distinct over_id) as overs_bowled 
    from ball_by_ball 
    group by bowler, match_id
  ) t
  group by bowler
),
best_bowlers as
(select 
  row_number() over(order by count(wt.player_out) desc) as player_rank,
  p.player_name as bowler,
  count(wt.player_out) as total_wickets,
  count(distinct bb.match_id) as matches_played,
  round(count(wt.player_out) / count(distinct bb.match_id), 2) as avg_wickets,
  round(sum(bb.runs_scored) / nullif(bo.total_overs_bowled, 0), 2) as economy
from ball_by_ball bb 
left join wicket_taken wt on bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and bb.over_id = wt.over_id and bb.ball_id = wt.ball_id
join player p on p.player_id = bb.bowler
join bowler_overs bo on bb.bowler = bo.bowler
group by p.player_name, bo.total_overs_bowled
order by total_wickets desc)
select 
  batsman as all_rounders,
  total_runs, strike_rate, avg_runs,
  total_wickets, economy, avg_wickets
from best_batsmans bat join best_bowlers bow on bat.batsman = bow.bowler
where total_runs > (select avg(total_runs) from best_batsmans)
and total_wickets > (select avg(total_wickets) from best_bowlers)
order by total_runs desc, total_wickets desc;

-- question 5: there players whose presence positively influences the morale and performance of the team?
with match_wins_count as
(select 
  count(m.match_id) as matches_won,
  m.match_winner as team_id,
  pm.player_id
from matches m join player_match pm on pm.match_id = m.match_id and pm.team_id = m.match_winner
group by pm.player_id, m.match_winner),
matches_count as
(select
  player_id,
  team_id,
  count(match_id) as matches_played
from player_match
group by player_id, team_id)

select 
  p.player_name, 
  t.team_name, 
  mc.matches_played, 
  mwc.matches_won,
  round(100*(mwc.matches_won/mc.matches_played),2) as match_won_percentage
from matches_count mc 
join match_wins_count mwc 
on mc.player_id = mwc.player_id 
and mc.team_id = mwc.team_id
join team t on mc.team_id = t.team_id
join player p on mc.player_id = p.player_id
where mc.matches_played > 10
order by match_won_percentage desc;

-- question 6: what would you suggest to rcb before going to the mega auction? 
-- team_overall_avg_runs
select 
  team_name,
  round(sum(runs_scored)/count(distinct match_id),2) as overall_avg_runs,
  round(100*sum(runs_scored)/count(ball_id),2)  as overall_strike_rate
from ball_by_ball bb 
join team t on bb.team_batting = t.team_id
group by team_name
order by overall_avg_runs desc;
-- team_powerplay_avg_runs
select 
  team_name,
  round(sum(runs_scored)/count(distinct match_id),2) as powerplay_avg_runs,
  round(100*sum(runs_scored)/count(ball_id),2)  as powerplay_strike_rate
from ball_by_ball bb 
join team t on bb.team_batting = t.team_id
where over_id between 1 and 6
group by team_name
order by powerplay_avg_runs desc;
-- team_midgame_avg_runs
select 
  team_name,
  round(sum(runs_scored)/count(distinct match_id),2) as midgame_avg_runs,
  round(100*sum(runs_scored)/count(ball_id),2)  as midgame_strike_rate
from ball_by_ball bb 
join team t on bb.team_batting = t.team_id
where over_id between 7 and 15
group by team_name
order by midgame_avg_runs desc;
-- team_endgame_avg_runs
select 
  team_name,
  round(sum(runs_scored)/count(distinct match_id),2) as endgame_avg_runs,
  round(100*sum(runs_scored)/count(ball_id),2)  as endgame_strike_rate 
from ball_by_ball bb 
join team t on bb.team_batting = t.team_id
where over_id between 16 and 20
group by team_name
order by endgame_avg_runs desc;
-- overall_team_avg_wickets
select
  t.team_name,
  count(wt.player_out) overall_wickets_taken,
  round(count(wt.player_out)/count(distinct bb.match_id),2) as overall_avg_wickets_taken,
  round(sum(bb.runs_scored)/count(distinct concat(bb.match_id, bb.over_id)) ,2) as overall_economy
from ball_by_ball bb 
join team t 
  on bb.team_bowling = t.team_id
left join wicket_taken wt 
  on bb.match_id = wt.match_id 
  and bb.innings_no = wt.innings_no 
  and bb.over_id = wt.over_id
  and bb.ball_id = wt.ball_id
  group by team_name
  order by overall_avg_wickets_taken desc;
-- team_powerplay_avg_wickets
select
  t.team_name,
  count(wt.player_out) powerplay_wickets_taken,
  round(count(wt.player_out)/count(distinct bb.match_id),2) as poweplay_avg_wickets_taken,
  round(sum(bb.runs_scored)/count(distinct concat(bb.match_id, bb.over_id)) ,2) as powerplay_economy
from ball_by_ball bb 
join team t 
  on bb.team_bowling = t.team_id
left join wicket_taken wt 
  on bb.match_id = wt.match_id 
  and bb.innings_no = wt.innings_no 
  and bb.over_id = wt.over_id
  and bb.ball_id = wt.ball_id
where bb.over_id between 1 and 6
  group by team_name
  order by poweplay_avg_wickets_taken desc;
-- team_midgame_avg_wickets
select
  t.team_name,
  count(wt.player_out) midgame_wickets_taken,
  round(count(wt.player_out)/count(distinct bb.match_id),2) as midgame_avg_wickets_taken,
  round(sum(bb.runs_scored)/count(distinct concat(bb.match_id, bb.over_id)) ,2) as midgame_economy
from ball_by_ball bb 
join team t 
  on bb.team_bowling = t.team_id
left join wicket_taken wt 
  on bb.match_id = wt.match_id 
  and bb.innings_no = wt.innings_no 
  and bb.over_id = wt.over_id
  and bb.ball_id = wt.ball_id
where bb.over_id between 7 and 15
group by team_name
order by midgame_avg_wickets_taken desc;
-- team_endgame_avg_wickets
select
  t.team_name,
  count(wt.player_out) endgame_wickets_taken,
  round(count(wt.player_out)/count(distinct bb.match_id),2) as endgame_avg_wickets_taken,
  round(sum(bb.runs_scored)/count(distinct concat(bb.match_id, bb.over_id)) ,2) as endgame_economy
from ball_by_ball bb 
join team t 
  on bb.team_bowling = t.team_id
left join wicket_taken wt 
  on bb.match_id = wt.match_id 
  and bb.innings_no = wt.innings_no 
  and bb.over_id = wt.over_id
  and bb.ball_id = wt.ball_id
where bb.over_id between 16 and 20
group by team_name
order by endgame_avg_wickets_taken desc;
-- team_allrounders_batting_performance
select 
  t.team_name,
  sum(runs_scored) as overall_total_runs,
  count(distinct match_id) as matches,
 round(sum(runs_scored)/count(distinct match_id),2) as overall_avg_runs
from ball_by_ball bb join team t on bb.team_batting = t.team_id
where striker in (select distinct bowler from ball_by_ball)
group by team_name
order by overall_avg_runs desc;
-- team_allrounders_bowling_performance
select team_name,
count(player_out) as total_wickets,
count(distinct bb.match_id) as matches,
round(count(player_out)/count(distinct bb.match_id),2) as overall_avg_wickets,
round(sum(runs_scored)/count(distinct concat(bb.match_id, bb.over_id)),2) as overall_economy
from ball_by_ball bb join team t on bb.team_bowling = t.team_id
left join wicket_taken wt on bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and bb.over_id = wt.over_id and bb.ball_id = wt.ball_id
where bb.bowler in (select distinct striker from ball_by_ball)
group by team_name
order by overall_avg_wickets desc;

-- question 7: what do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies
with match_winner_list as (
    select match_id, match_winner 
    from matches
),
match_winners_score as (
    select 
        bb.match_id,
        t.team_name,
        sum(bb.runs_scored) as runs_scored
    from ball_by_ball bb
    join match_winner_list mw on bb.match_id = mw.match_id and bb.team_batting = mw.match_winner
    join team t on t.team_id = bb.team_batting
    group by bb.match_id, t.team_name
),
high_scoring_matches as (
    select match_id 
    from match_winners_score
    where runs_scored > (select avg(runs_scored) from match_winners_score)
)
select 
    v.venue_name, 
    sum(case when bb.runs_scored = 4 then 1 else 0 end) as fours, 
    sum(case when bb.runs_scored = 6 then 1 else 0 end) as sixes
from ball_by_ball bb 
join matches m on m.match_id = bb.match_id
join venue v on v.venue_id = m.venue_id
where bb.match_id in (select match_id from high_scoring_matches)
group by v.venue_name
order by fours desc, sixes desc;
-- venue wise count of high scoring matches
with match_winner_list as (select match_id, match_winner from matches),
match_winners_score as
(select
  bb.match_id,
  team_name,
  sum(runs_scored) as runs_scored
from ball_by_ball bb 
join match_winner_list mw on bb.match_id = mw.match_id and bb.team_batting = mw.match_winner
join team t on t.team_id = bb.team_batting
group by match_id, team_batting
order by bb.match_id),
high_scoring_matches as
(select match_id, team_name, runs_scored from match_winners_score
where runs_scored > (select avg(runs_scored) from match_winners_score)
order by team_name)
select
  venue_name,
  count(m.match_id) as match_count
from high_scoring_matches hs join matches m on m.match_id = hs.match_id
join venue v on v.venue_id = m.venue_id
group by venue_name
order by match_count desc;
--  venue wise wickets and avg_wickets for high scoring matches
with match_winner_list as (
    select match_id, match_winner 
    from matches
),
match_winners_score as (
    select 
        bb.match_id,
        t.team_name,
        sum(bb.runs_scored) as runs_scored
    from ball_by_ball bb
    join match_winner_list mw on bb.match_id = mw.match_id and bb.team_batting = mw.match_winner
    join team t on t.team_id = bb.team_batting
    group by bb.match_id, t.team_name
),
high_scoring_matches as (
    select match_id 
    from match_winners_score
    where runs_scored > (select avg(runs_scored) from match_winners_score)
)
select 
    v.venue_name, 
    count(wt.player_out) as wickets,
    round(count(wt.player_out)/count(distinct bb.match_id),2) as avg_wickets
from ball_by_ball bb 
right join wicket_taken wt on bb.match_id = wt.match_id and bb.innings_no = wt.innings_no and bb.over_id = wt.over_id and bb.ball_id = wt.ball_id
join matches m on m.match_id = wt.match_id
join venue v on v.venue_id = m.venue_id
where bb.match_id in (select match_id from high_scoring_matches)
group by v.venue_name
order by avg_wickets desc;
-- high scoign matches and runs scored by winning team
with match_winner_list as (select match_id, match_winner from matches),
match_winners_score as
(select
  bb.match_id,
  team_name,
  sum(runs_scored) as runs_scored
from ball_by_ball bb 
join match_winner_list mw on bb.match_id = mw.match_id and bb.team_batting = mw.match_winner
join team t on t.team_id = bb.team_batting
group by match_id, team_batting
order by bb.match_id)
select match_id, team_name, runs_scored from match_winners_score
where runs_scored > (select avg(runs_scored) from match_winners_score)
order by team_name;
--  high scoring matches and win margins 
with win_matches as
(select
  match_id,
  match_winner,
  case when win_type = 1 then win_margin end as win_runs,
  case when win_type = 2 then win_margin end as win_wickets
from matches)
select
  match_id,
  team_name,
  win_runs as win_margin_runs,
  win_wickets as win_margin_wickets
from win_matches wm join team t on wm.match_winner = t.team_id
where win_runs > (select sum(win_runs)/count(match_id) as avg_win_runs from win_matches)
or win_wickets > (select sum(win_wickets)/count(match_id) as avg_win_wickets from win_matches)
order by team_name, win_runs desc, win_wickets desc;

-- question 7: analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for rcb.
with rcb_matches as (
  select s.season_year, m.match_id, m.toss_decide, m.toss_winner, m.match_winner 
  from matches m
  join venue v on m.venue_id = v.venue_id 
  join city c on v.city_id = c.city_id
  left join team t1 on t1.team_id = m.team_1
  left join team t2 on t2.team_id = m.team_2
  join season s on s.season_id = m.season_id
  where c.city_name = 'bangalore' 
  and ('royal challengers bangalore' in (t1.team_name, t2.team_name))
)
select
  season_year,
  round(100.0 * sum(case when match_winner = 2 then 1 else 0 end) / count(match_id), 2) as homeground_win_percentage,  
  round(100.0 * sum(case when 
    (toss_winner = 2 and toss_decide = 1 and match_winner = 2) or 
    (toss_winner <> 2 and toss_decide = 2 and match_winner = 2) 
  then 1 else 0 end) / 
  nullif(sum(case when toss_winner = 2 and toss_decide = 1 then 1 else 0 end) + 
         sum(case when toss_winner <> 2 and toss_decide = 2 then 1 else 0 end), 0), 2) as bowl_first_win_percentage,
  
  round(100.0 * sum(case when 
    (toss_winner = 2 and toss_decide = 2 and match_winner = 2) or 
    (toss_winner <> 2 and toss_decide = 1 and match_winner = 2) 
  then 1 else 0 end) / 
  nullif(sum(case when toss_winner = 2 and toss_decide = 2 then 1 else 0 end) + 
         sum(case when toss_winner <> 2 and toss_decide = 1 then 1 else 0 end), 0), 2) as bat_first_win_percentage
from rcb_matches
group by season_year;

-- question 8: come up with a visual and analytical analysis of the rcb's past season's performance and potential reasons for them not winning a trophy.
with rcb_matches as
(select t1.team_name as team1, t2.team_name as team2, s.season_year, m.match_id, m.toss_decide, m.toss_winner, m.match_winner 
  from matches m
  left join team t1 on t1.team_id = m.team_1
  left join team t2 on t2.team_id = m.team_2
  join season s on s.season_id = m.season_id
  where ('royal challengers bangalore' in (t1.team_name, t2.team_name)))
  
select 
  season_year, 
  count(match_id) as matches_played,
  sum(case when match_winner = 2 then 1 else 0 end) as match_wins,
  round(100 * sum(case when match_winner = 2 then 1 else 0 end)/count(match_id),2) as win_percentage
from rcb_matches
group by season_year;

with rcb_matches as
(select v.venue_name, t1.team_name as team1, t2.team_name as team2, s.season_year, m.match_id, m.toss_decide, m.toss_winner, m.match_winner 
  from matches m
  left join team t1 on t1.team_id = m.team_1
  left join team t2 on t2.team_id = m.team_2
  join season s on s.season_id = m.season_id
  join venue v on m.venue_id = v.venue_id
  where ('royal challengers bangalore' in (t1.team_name, t2.team_name)))
  
select 
  venue_name,
  count(match_id) as matches_played,
  sum(case when match_winner = 2 then 1 else 0 end) as match_wins,
  round(100*sum(case when match_winner = 2 then 1 else 0 end)/count(match_id),2) as win_percentage
 from rcb_matches
 group by venue_name
 order by win_percentage desc;

with rcb_matches as
(select 
case when city_name = 'bangalore' then 'home'
else 'away' end as venue_type,
v.venue_name, t1.team_name as team1, t2.team_name as team2, s.season_year, m.match_id, m.toss_decide, m.toss_winner, m.match_winner 
  from matches m
  left join team t1 on t1.team_id = m.team_1
  left join team t2 on t2.team_id = m.team_2
  join season s on s.season_id = m.season_id
  join venue v on m.venue_id = v.venue_id
  join city c on c.city_id = v.city_id
  where ('royal challengers bangalore' in (t1.team_name, t2.team_name)))
  
select 
  venue_type,
  count(match_id) as matches_played,
  sum(case when match_winner = 2 then 1 else 0 end) as match_wins,
  round(100*sum(case when match_winner = 2 then 1 else 0 end)/count(match_id),2) as win_percentage
 from rcb_matches
 group by venue_type
 order by win_percentage desc;

with rcb_matches as
(select 
case when toss_winner = 2 and toss_decide = 1 then 'field first'
when toss_winner = 2 and toss_decide = 2 then 'bat first'
when toss_winner <> 2 and toss_decide = 1 then 'bat first'
else 'field first' 
end as game_type,
v.venue_name, t1.team_name as team1, t2.team_name as team2, s.season_year, m.match_id, m.toss_decide, m.toss_winner, m.match_winner 
  from matches m
  left join team t1 on t1.team_id = m.team_1
  left join team t2 on t2.team_id = m.team_2
  join season s on s.season_id = m.season_id
  join venue v on m.venue_id = v.venue_id
  join city c on c.city_id = v.city_id
  where ('royal challengers bangalore' in (t1.team_name, t2.team_name)))
  
select 
  game_type,
  count(match_id) as matches_played,
  sum(case when match_winner = 2 then 1 else 0 end) as match_wins,
  round(100*sum(case when match_winner = 2 then 1 else 0 end)/count(match_id),2) as win_percentage
 from rcb_matches
 group by game_type
 order by win_percentage desc;

with rcb_matches as
(select 
bb.striker, bb.bowler, wt.player_out,  bb.runs_scored, t1.team_name as team1, t2.team_name as team2, s.season_year, m.match_id, m.toss_decide, m.toss_winner, m.match_winner 
  from matches m
  left join team t1 on t1.team_id = m.team_1
  left join team t2 on t2.team_id = m.team_2
  right join ball_by_ball bb on bb.match_id = m.match_id
  left join wicket_taken wt on wt.match_id = bb.match_id and wt.innings_no = bb.innings_no and wt.over_id = bb.over_id and wt.ball_id and bb.over_id
  join season s on s.season_id = m.season_id
  where ('royal challengers bangalore' in (t1.team_name, t2.team_name))),
batsman_table as
(select 
  season_year,
  player_name as batsman,
  sum(runs_scored) as total_runs,
  rank() over(partition by season_year order by sum(runs_scored) desc) as player_rank
from rcb_matches rm 
join player p on p.player_id = rm.striker
group by season_year, batsman
order by season_year, total_runs desc)
select 
  season_year,
  player_name as bowlers,
  count(player_out) as total_wickets,
  rank() over(partition by season_year order by count(player_out) desc) as player_rank
from rcb_matches rm 
join player p on p.player_id = rm.bowler
group by season_year, bowlers
order by season_year, total_wickets desc;

-- question 10: in the "team" table, some entries in the "team_name" column are incorrectly spelled as "delhi_capitals" instead of "delhi_daredevils". write an sql query to replace all occurrences of "delhi_capitals" with "delhi_daredevils".
update team
set team_name = 'delhi daredevils'
where team_name = 'delhi capitals';