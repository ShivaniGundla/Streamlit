CREATE DATABASE IF NOT EXISTS EnergyDB;
USE EnergyDB;


-- Create Country Table
CREATE TABLE country (
    CID VARCHAR(10) PRIMARY KEY,
    Country VARCHAR(100) UNIQUE
);
SELECT * FROM COUNTRY;

-- Create Emission table
CREATE TABLE emission(country VARCHAR(100), 
                      energy_type  VARCHAR(400),
                      year INT,
                      emission INT,
                      per_capita_emission DOUBLE,
                      FOREIGN KEY(country) REFERENCES country(country));
SELECT * FROM emission;


-- Create Population Table
CREATE TABLE population(countries VARCHAR(100),
                        year INT,
                        value DOUBLE,
                        FOREIGN KEY (countries) REFERENCES country(country));
SELECT * FROM population;

-- Create production table
CREATE TABLE production(country VARCHAR(100),
                         energy VARCHAR(50),
                         year INT,
                         production INT,
                         FOREIGN KEY (country) REFERENCES country(country));
SELECT * FROM production;


-- Create Table gdp
CREATE TABLE gdp(country VARCHAR(100),
                 year INT,
                 value DOUBLE,
                 FOREIGN KEY(country) REFERENCES country(country));
SELECT * FROM gdp;

-- Create Consumption Table
CREATE TABLE consumption(country VARCHAR(100),
                         energy VARCHAR(50),
                         year INT,
                         consumption INT,
                         FOREIGN KEY (country) REFERENCES country(country));
SELECT * FROM consumption;

-- DATA ANALYSIS QUESTIONS
-- -----------------------------------------------------------------------------------------------------------------------------
-- General & Comparitive Questions
-- 1)What is the total emission per country for the most recent year available?
SELECT country, SUM(emission) as total_emission
FROM emission
WHERE year = (SELECT MAX(year) FROM emission)
GROUP BY country;


-- 2)What are the top 5 countries by GDP in the most recent year?
SELECT country, value as gdp_value
FROM gdp
WHERE year = (SELECT MAX(year) FROM gdp)
ORDER BY gdp_value DESC
LIMIT 5;

-- 3)Compare energy production and consumption by country and year
SELECT p.country, p.year, SUM(p.production)as total_production,
SUM(c.consumption) as total_consumption,
(SUM(p.production) - SUM(c.consumption)) as remaining_production,
CASE 
    WHEN SUM(p.production) - SUM(c.consumption)  > 0 THEN 'Producer'
    WHEN SUM(p.production) - SUM(c.consumption)  < 0 THEN 'Consumer'
    ELSE 'Neither'
END producers_or_consumers
FROM production AS p
JOIN consumption 	as c
	ON p.country = c.country AND
       p.year = c.year
GROUP BY p.country, p.year
ORDER BY p.country;

-- 4)Which energy types contribute most to emissions across all countries?
SELECT energy_type, SUM(emission) as total_emission
FROM emission
GROUP BY energy_type
ORDER BY total_emission DESC;

-- -----------------------------------------------------------------------------------------------------------------------------
-- Trend Analysis Over Time

-- 5)How have global emissions changed year over year
SELECT  year,sum(emission) as total_emission, 
SUM(emission) - LAG(SUM(emission)) OVER (ORDER BY year) AS yearly_change 
FROM emission
GROUP BY year
ORDER BY year;


-- 6)What is the trend in GDP for each country over the given years?

WITH gdp_trend as
(SELECT country, year,
(value - LAG(value) OVER (PARTITION BY country ORDER BY year)) AS gdp_change
FROM gdp
GROUP BY country, year, value)
SELECT country,AVG(gdp_change),
CASE 
    WHEN AVG(gdp_change) IS NULL THEN 'No Previous Data'
    WHEN AVG(gdp_change) > 0 THEN 'Increasing'
    WHEN AVG(gdp_change) < 0 THEN 'Decreasing'
    ELSE 'Stable'
END AS trend
FROM gdp_trend
GROUP BY country
ORDER BY country;

-- 7)How has population growth affected total emissions in each country?
WITH yearly_changes as
(SELECT e.country, e.year,
(p.value - LAG(p.value) OVER(PARTITION BY country ORDER BY year))as population_change,
(SUM(e.emission) - LAG(SUM(e.emission)) OVER(PARTITION BY country ORDER BY year)) as emission_change
FROM emission as e
JOIN population as p
ON e.country = p.countries AND
   e.year = p.year
GROUP BY e.country, e.year, p.value)
SELECT country,AVG(population_change),AVG(emission_change),
CASE
    WHEN AVG(emission_change) > 0 AND AVG(population_change) > 0 THEN 'Positive Impact'
	WHEN AVG(emission_change) < 0 AND AVG(population_change) > 0 THEN 'Sustainable'
    WHEN AVG(emission_change) > 0 AND AVG(population_change)  < 0 THEN 'Negative Impact'
    ELSE 'Mixed Trend'
END AS impact
FROM yearly_changes
GROUP BY country
ORDER BY country;

-- 8)Has energy consumption increased or decreased over the years for major economies?
-- Major economies are classified by GDP. Based on GDP of Question 2, the top 5 major economy countries are
-- [China, United States, India, Japan, Germany]

WITH sum_consumption as
(SELECT country,year,SUM(consumption) as total_consumption
FROM consumption
WHERE country IN ('China','United States','India','Japan','Germany')
GROUP BY country, year),
final as
(SELECT DISTINCT country,
(LAST_VALUE(total_consumption) OVER (PARTITION BY country ORDER BY year 
                              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)) -
(FIRST_VALUE(total_consumption) OVER (PARTITION BY country ORDER BY year)) as consumption_change
FROM sum_consumption)
SELECT country, consumption_change,
CASE
    WHEN consumption_change > 0 THEN 'Increased'
    WHEN consumption_change < 0 THEN 'Decreased'
    ELSE 'No Change'
END AS Trend
FROM final;
-- ------------------------------------------------------------------------------------------------------------------------------
-- 9)What is the average yearly change in emissions per capita for each country?
WITH yearly_changes AS (
SELECT country,year,per_capita_emission,
per_capita_emission - LAG(per_capita_emission) OVER (PARTITION BY country ORDER BY year) AS yearly_change
FROM emission)

SELECT country,AVG(per_capita_emission), AVG(yearly_change) as avg_yearly_change
FROM yearly_changes
WHERE yearly_change IS NOT NULL
GROUP BY country
ORDER BY avg_yearly_change DESC;
-- --------------------------------------------------------------------------------------------------------------------------------
-- RATIO & PER CAPITA ANALYSIS
-- 10)What is the emission-to-GDP ratio for each country by year?
SELECT e.country, e.year, 
ROUND(sum(e.emission)/NULLIF(MAX(g.value),0), 3) as emission_to_gdp_ratio
FROM emission e
JOIN gdp g
ON e.country = g.country AND e.year = g.year
GROUP BY e.country, e.year
ORDER BY e.country;

-- 11)What is the energy consumption per capita for each country over the last decade?
SELECT c.country,
FORMAT(SUM(c.consumption)/AVG(p.value), 7) as consumption_per_capita
FROM consumption c
JOIN population p
ON c.country = p.countries AND
   c.year = p.year
WHERE c.year > (SELECT MAX(year) - 9 FROM consumption)
GROUP BY c.country
ORDER BY consumption_per_capita DESC;

-- 12)How does energy production per capita vary across countries?
SELECT pr.country,
ROUND(SUM(pr.production)/(AVG(p.value)), 7) as production_per_capita
FROM production as pr
JOIN population as p
ON pr.country = p.countries AND 
   pr.year = p.year
GROUP BY pr.country
ORDER BY production_per_capita DESC;

-- 13)Which countries have the highest energy consumption relative to GDP?
SELECT c.country,
ROUND(SUM(c.consumption)/AVG(g.value), 3) as energy_intensity
FROM consumption c
JOIN gdp g
ON c.country = g.country AND c.year = g.year
GROUP BY c.country
ORDER BY energy_intensity DESC;

-- --------------------------------------------------------------------------------------------------------------------------------
-- 14)What is the correlation between GDP growth and energy production growth?
WITH growth AS (
SELECT g.country,g.year,
	(g.value - LAG(g.value) OVER (PARTITION BY g.country ORDER BY g.year)*1.0) 
        / NULLIF(LAG(g.value) OVER (PARTITION BY g.country ORDER BY g.year),0) AS gdp_growth,
	(p.production - LAG(p.production) OVER (PARTITION BY p.country ORDER BY p.year)*1.0) 
        / NULLIF(LAG(p.production) OVER (PARTITION BY p.country ORDER BY p.year),0) AS energy_growth
FROM gdp g
JOIN production p
ON g.country = p.country AND g.year = p.year),
corr AS (
SELECT country,(AVG(gdp_growth * energy_growth) - AVG(gdp_growth) * AVG(energy_growth)*1.0)/
        NULLIF((STDDEV(gdp_growth) * STDDEV(energy_growth)),0) AS correlation
FROM growth
WHERE gdp_growth IS NOT NULL AND energy_growth IS NOT NULL
GROUP BY country)
SELECT country,correlation,
CASE 
	WHEN correlation > 0.3 THEN 'Positive'
	WHEN correlation < -0.3 THEN 'Negative'
	ELSE 'No correlation'
END AS correlation_type
FROM corr
WHERE correlation IS NOT NULL;
-- -------------------------------------------------------------------------------------------------------------------------------
-- 15)What are the top 10 countries by population and how do their emissions compare?
SELECT p.countries, AVG(p.value) as Avg_Population, SUM(e.emission) as total_emission
FROM population p 
JOIN emission e
ON p.countries = e.country AND p.year = e.year
GROUP BY p.countries
ORDER BY Avg_Population DESC
LIMIT 10;


-- 17)What is the global share (%) of emissions by country?
SELECT country, SUM(emission) as total_emission,
ROUND((SUM(emission) / (SELECT SUM(emission) FROM emission)) * 100.0, 4) AS global_share_percent
FROM emission
GROUP BY country
ORDER BY global_share_percent DESC;


-- 18)What is the global average GDP, emission, and population by year?
SELECT g.year, 
ROUND(AVG(g.value),3) as Avg_GDP, 
ROUND(AVG(e.emission), 3) as Avg_emission,
ROUND(AVG(p.value), 3) as Avg_population
FROM gdp g
JOIN emission e
ON g.country = e.country AND g.year = e.year
JOIN population p
ON g.country = p.countries AND g.year = p.year
GROUP BY g.year
ORDER BY year DESC;





-- 16) Which countries have improved (reduced) their per capita emissions the most over the last decade?
WITH per_capita_emissions as
(SELECT country,year,per_capita_emission,
FIRST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year)  as start_value,
LAST_VALUE(per_capita_emission) OVER (PARTITION BY country ORDER BY year
                                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as end_value
FROM emission)

SELECT country,MAX(start_value) - MAX(end_value) as emission_change
FROM per_capita_emissions
GROUP BY country
ORDER BY emission_change DESC;









			

                        
