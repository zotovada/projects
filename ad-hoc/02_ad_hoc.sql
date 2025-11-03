/* Проект «Анализ рынка недвижимости Санкт-Петербурга»
 * Цель проекта: Провести анализ рынка жилой недвижимости Санкт-Петербурга и Ленинградской 
 * области на основе данных Яндекс Недвижимости, чтобы помочь агентству недвижимости 
 * определить наиболее перспективные сегменты для успешного выхода на новый региональный рынок.
 * 
 * Автор: Зотова Дарья
 * Дата: 03.04.2025
*/

--Часть 2. Решение ad-hoc задач
--Выводы отдельно представлены в аналитической записке.

--Задача 1.Время активности объявлений
WITH 
-- Определим аномальные значения (выбросы) по значению перцентилей:
limits AS (
    SELECT  
    	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY last_price / total_area) AS price_per_sqm_limit_h,
    	PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY last_price / total_area) AS price_per_sqm_limit_l,
    	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats AS f 
    JOIN real_estate.advertisement AS a ON f.id = a.id
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT f.id
    FROM real_estate.flats AS f 
    JOIN real_estate.advertisement AS a ON f.id = a.id  
    WHERE 
    	last_price / total_area < (SELECT price_per_sqm_limit_h FROM limits)
    	AND last_price / total_area > (SELECT price_per_sqm_limit_l FROM limits)
        AND total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
--Готовим данные для исследования: категоризируем по региону и сегменту активности
main_table AS (
	SELECT
		f.id AS id,
		CASE
			WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
			ELSE 'Лен. область'
		END AS region, 
		CASE 
			WHEN days_exposition <= 30 THEN 'до месяца'
			WHEN days_exposition > 30 AND days_exposition <= 90 THEN 'до трёх месяцев'
			WHEN days_exposition > 90 AND days_exposition <= 180 THEN 'до полугода'
			WHEN days_exposition > 180 THEN 'более полугода'
		END AS time_on_market,
		ROUND(last_price / total_area) AS price_per_sqm,
		total_area,
		ceiling_height,
		rooms,
		balcony,
		floor,
		is_apartment
	FROM real_estate.flats AS f
	JOIN real_estate.advertisement AS a ON f.id = a.id
	WHERE 
		days_exposition IS NOT NULL --убираем из выборки действующие объявления
		AND type_id = 'F8EM' --оставляем в выборке только объявления о продаже квартир в городах
		AND f.id IN (SELECT * FROM filtered_id) --убираем из выборки аномальные значения
)
SELECT 
	region,
	time_on_market,
	COUNT(id) AS flats_total,
	ROUND(COUNT(id) / SUM(COUNT(id)) OVER (PARTITION BY region)::numeric, 2) AS flats_share,
	ROUND(AVG(price_per_sqm)) AS avg_price_per_sqm,
	ROUND(AVG(total_area)) AS avg_total_area,
	ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
	ROUND(SUM(CASE WHEN floor = 1 THEN 1 END) / COUNT(id)::numeric, 2) AS first_floor_flats_share,
	ROUND(SUM(is_apartment) / COUNT(id)::numeric, 5) AS apartments_share
FROM main_table
GROUP BY 
	region,
	time_on_market
ORDER BY 
	region DESC,
	CASE 
		WHEN time_on_market = 'до месяца' THEN 1
		WHEN time_on_market = 'до трёх месяцев' THEN 2
		WHEN time_on_market = 'до полугода' THEN 3
		WHEN time_on_market = 'более полугода' THEN 4
	END;
	


--Задача 2. Сезонность объявлений
WITH
-- Определим аномальные значения (выбросы) по значению перцентилей:
limits AS (
    SELECT  
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY last_price / total_area) AS price_per_sqm_limit_h,
    	PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY last_price / total_area) AS price_per_sqm_limit_l,
    	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit
    FROM real_estate.flats AS f 
    JOIN real_estate.advertisement AS a ON f.id = a.id     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT f.id
    FROM real_estate.flats AS f 
    JOIN real_estate.advertisement AS a ON f.id = a.id  
    WHERE
    	last_price / total_area < (SELECT price_per_sqm_limit_h FROM limits)
    	AND last_price / total_area > (SELECT price_per_sqm_limit_l FROM limits)
        AND total_area < (SELECT total_area_limit FROM limits)
 ),
--Статистика опубликованных объявлений 
open_data AS (
	SELECT 
		EXTRACT(MONTH FROM first_day_exposition) AS open_date,
		COUNT(a.id) AS count_open,
		ROUND(AVG(last_price / total_area)) AS avg_price_open,
		ROUND(AVG(total_area)::numeric,2) AS avg_area_open
	FROM real_estate.advertisement AS a
	JOIN real_estate.flats AS f ON a.id = f.id
	WHERE 
		EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 --убираем года, данные за которые не полные
		AND a.id IN (SELECT * FROM filtered_id) --убираем объяления с вбросами
		AND type_id = 'F8EM' --оставляем в выборке только объявления о продаже квартир в городах
	GROUP BY EXTRACT(MONTH FROM first_day_exposition)
),
--Статистика снятых объявлений
close_data AS (
	SELECT 
		EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS close_date,
		COUNT(a.id) AS count_close,
		ROUND(AVG(last_price / total_area)) AS avg_price_close,
		ROUND(AVG(total_area)::numeric, 2) AS avg_area_close
	FROM real_estate.advertisement AS a
	JOIN real_estate.flats AS f ON a.id = f.id
	WHERE 
		days_exposition IS NOT NULL --выбираем только закрытые объявления
		AND EXTRACT (YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') BETWEEN 2015 AND 2018 --убираем года, данные за которые не полные
		AND a.id IN (SELECT * FROM filtered_id) --убираем объяления с вбросами
		AND type_id = 'F8EM' --оставляем в выборке только объявления о продаже квартир в городах
	GROUP BY EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day')
)
SELECT 
	TO_CHAR(TO_DATE(open_date::text, 'MM'), 'Month') AS month,
	count_open,
	count_close,
	avg_price_open,
	avg_price_close,
	avg_area_open,
	avg_area_close,
	DENSE_RANK() OVER(ORDER BY count_open DESC) AS rank_count_open, --ранжируем месяцы по количеству публикаций в разрезе года
	DENSE_RANK() OVER(ORDER BY count_close DESC) AS rank_count_close --ранжируем месяцы по количеству закрытых объявлений в разрезе года
FROM open_data AS ad
LEFT JOIN close_data AS ac ON ad.open_date = ac.close_date
ORDER BY open_date;



--Задача 3. Анализ рынка недвижимости Ленобласти
WITH
-- Определим аномальные значения (выбросы) по значению перцентилей:
limits AS (
    SELECT  
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY last_price / total_area) AS price_per_sqm_limit_h,
    	PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY last_price / total_area) AS price_per_sqm_limit_l,
    	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit
    FROM real_estate.flats AS f 
    JOIN real_estate.advertisement AS a ON f.id = a.id    
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT f.id
    FROM real_estate.flats AS f 
    JOIN real_estate.advertisement AS a ON f.id = a.id  
    WHERE
    	last_price / total_area < (SELECT price_per_sqm_limit_h FROM limits)
    	AND last_price / total_area > (SELECT price_per_sqm_limit_l FROM limits)
        AND total_area < (SELECT total_area_limit FROM limits)
)
SELECT 
	city,
	COUNT(f.id) AS flats_total,
	ROUND(SUM(CASE WHEN days_exposition IS NOT NULL THEN 1 END) / COUNT(f.id)::numeric, 2) AS close_share,
	ROUND(AVG(last_price / total_area)) AS avg_price_per_sqm,
	ROUND(AVG(total_area)::numeric,2) AS avg_area,
	ROUND(AVG(days_exposition)::numeric,2) AS avg_days_exposition
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a ON f.id = a.id
JOIN real_estate.city AS c ON f.city_id = c.city_id 
WHERE 
	f.city_id != '6X8I' --убираем Санкт-Петербург
	AND a.id IN (SELECT * FROM filtered_id) --убираем объяления с вбросами по площади
GROUP BY city
HAVING COUNT(f.id) >= 50 --отсекаем нерепрезентативные данные, но сохраняем активные рынки
ORDER BY flats_total DESC;
	