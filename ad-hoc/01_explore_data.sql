/* Проект «Анализ рынка недвижимости Санкт-Петербурга»
 * Цель проекта: Провести анализ рынка жилой недвижимости Санкт-Петербурга и Ленинградской 
 * области на основе данных Яндекс Недвижимости, чтобы помочь агентству недвижимости 
 * определить наиболее перспективные сегменты для успешного выхода на новый региональный рынок.
 * 
 * Автор: Зотова Дарья
 * Дата: 03.04.2025
*/

--Часть 1. Знакомство с данными

--1. Структура данных

--Список таблиц в схеме
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'real_estate';

/* Схема real_estate содержит четыре таблицы: 
 * advertisement, 
 * flats, 
 * city, 
 * type. 
 * Предполагаем, что к ключевым таблицам можно отнести advertisement с данными об объявлениях 
 * и flats с инфомацией о квартирах. Остальные таблицы содержат справочную информацию.
*/

--Список колонок таблиц:
SELECT 
	table_name,
	column_name, 
	data_type
FROM information_schema.columns
WHERE table_schema = 'real_estate'
  AND table_name IN (
	SELECT table_name
	FROM information_schema.tables
	WHERE table_schema = 'real_estate'
	)
ORDER BY table_name;

--Выводим первые строки таблицы advertisement
SELECT *
FROM real_estate.advertisement
LIMIT 5;

/* Описание таблицы advertisement:
 * id — идентификатор объявления.
 * first_day_exposition — дата подачи объявления.
 * days_exposition — длительность нахождения объявления на сайте (в днях).
 * last_price — стоимость квартиры в объявлении, в руб.
*/

--Выводим первые строки таблицы flats
SELECT *
FROM real_estate.flats
LIMIT 5;

/* Описание таблицы flats:
 * id — идентификатор квартиры.
 * city_id — идентификатор города.
 * type_id — идентификатор типа населённого пункта.
 * total_area — общая площадь квартиры, в кв. метрах.
 * rooms — число комнат.
 * ceiling_height — высота потолка, в метрах.
 * floors_total — этажность дома, в котором находится квартира.
 * living_area — жилая площадь, в кв. метрах.
 * floor — этаж квартиры.
 * is_apartment — является ли квартира апартаментами (1 — является, 0 — не является).
 * open_plan — имеется ли в квартире открытая планировка (1 — имеется, 0 — отсутствует).
 * kitchen_area — площадь кухни, в кв. метрах.
 * balcony — количество балконов в квартире.
 * airports_nearest — расстояние до ближайшего аэропорта, в метрах.
 * parks_around3000 — число парков в радиусе трёх километров.
 * ponds_around3000 — число водоёмов в радиусе трёх километров.
*/

--Выводим первые строки таблицы city
SELECT *
FROM real_estate.city
LIMIT 5;

/* Описание таблицы city:
 * city_id — идентификатор населённого пункта.
 * city — название населённого пункта.
 */

--Выводим первые строки таблицы type
SELECT *
FROM real_estate.type
LIMIT 5;

/* Описание таблицы type:
 * type_id — идентификатор типа населённого пункта.
 * type — название типа населённого пункта.
*/

/* Данные во всех столбцах всех таблиц представлены корректными типами. Некоторые 
 * целочисленные данные представлены типом real, вероятно, из-за наличия пропуков в столбцах.
 */

--Ключи:
SELECT 
	constraint_type, 
	constraint_name, 
	table_name
FROM information_schema.table_constraints
WHERE table_schema = 'real_estate';

/* В схеме real_estate таблицы загружены без ключей. На деле они связаны между собой, но эти 
 * связи не прописаны в базе и по запросу не отображаются. Сопоставим связи вручную.
*/

/* Первичные ключи:
 * id для таблицы advertisement,
 * id для таблицы flats,
 * city_id для таблицы city,
 * type_id для таблицы type.
 */

--Проверим, связаны ли столбцы id в таблицах advertisement и flats

--Количество уникальных идентификаторов объявлений в таблице advertisement
SELECT COUNT(DISTINCT id)
FROM real_estate.advertisement;
--23650

--Количество уникальных идентификаторов объявлений в таблице flats
SELECT COUNT(DISTINCT id)
FROM real_estate.flats;
--23650

--Число пересечений между id в таблицах advertisement и flats
SELECT COUNT(*)
FROM (
	SELECT DISTINCT id
	FROM real_estate.advertisement
	INTERSECT
	SELECT DISTINCT id
	FROM real_estate.flats 
) AS intersected;
--23650

/* Внешние ключи:
 * id связывает таблицы advertisement и flats,
 * city_id связывает таблицы city и flats,
 * type_id связывает таблицы typeи flats.
 */



--2. Содержимое таблиц

--2.1. Таблица advertisement

SELECT COUNT(*)
FROM real_estate.advertisement;
--Таблица содержит информацию о 23 650 объявлениях.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE id IS NULL) AS id_nulls,
    COUNT(*) FILTER (WHERE first_day_exposition IS NULL) AS first_day_exposition_nulls,
    COUNT(*) FILTER (WHERE days_exposition IS NULL) AS days_exposition_nulls,
    COUNT(*) FILTER (WHERE last_price IS NULL) AS last_price_nulls
FROM real_estate.advertisement;

SELECT 
	COUNT(*) FILTER (WHERE days_exposition IS NULL) * 100.0 / COUNT(*) AS days_exposition_nulls_percent
FROM real_estate.advertisement;
--3 180 пропусков в столбце days_exposition (13,45%). Вероятно, это незакрытые объявления.

--Проверяем явные дубликаты
WITH duplicates AS (
	SELECT 
	    id,
		first_day_exposition,
	    days_exposition,
	    last_price,
	    COUNT(*)
	FROM real_estate.advertisement
	GROUP BY 
		id,
		first_day_exposition,
	    days_exposition,
	    last_price
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Явных дубликатов не обнаружено.

--Проверяем неявные дубликаты по сочетанию столбцов
WITH duplicates AS (
	SELECT 
	    first_day_exposition,
	    days_exposition,
	    last_price,
	    COUNT(*)
	FROM real_estate.advertisement
	GROUP BY 
		first_day_exposition,
	    days_exposition,
	    last_price
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Обнаружено 139 (менее 1%) неявных дубликатов по сочетанию всех столбцов, кроме id.



--2.2. Таблица flats

SELECT COUNT(*)
FROM real_estate.flats;
--Таблица содержит информацию о 23 650 квартирах.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE id IS NULL) AS id_nulls,
    COUNT(*) FILTER (WHERE city_id IS NULL) AS city_id_nulls,
    COUNT(*) FILTER (WHERE type_id IS NULL) AS type_id_nulls,
    COUNT(*) FILTER (WHERE total_area IS NULL) AS total_area_nulls,
    COUNT(*) FILTER (WHERE rooms IS NULL) AS rooms_nulls,
    COUNT(*) FILTER (WHERE ceiling_height IS NULL) AS ceiling_height_nulls,
    COUNT(*) FILTER (WHERE floors_total IS NULL) AS floors_total_nulls,
    COUNT(*) FILTER (WHERE living_area IS NULL) AS living_area_nulls,
    COUNT(*) FILTER (WHERE total_area IS NULL) AS total_area_nulls,
    COUNT(*) FILTER (WHERE floor IS NULL) AS floor_nulls,
    COUNT(*) FILTER (WHERE is_apartment IS NULL) AS is_apartment_nulls,
    COUNT(*) FILTER (WHERE open_plan IS NULL) AS open_plan_nulls,
    COUNT(*) FILTER (WHERE kitchen_area IS NULL) AS kitchen_area_nulls,
    COUNT(*) FILTER (WHERE balcony IS NULL) AS balcony_nulls,
    COUNT(*) FILTER (WHERE airports_nearest IS NULL) AS airports_nearest_nulls,
    COUNT(*) FILTER (WHERE parks_around3000 IS NULL) AS parks_around3000_nulls,
    COUNT(*) FILTER (WHERE ponds_around3000 IS NULL) AS ponds_around3000_nulls
FROM real_estate.flats;

SELECT 
	COUNT(*) FILTER (WHERE ceiling_height IS NULL) * 100.0 / COUNT(*) AS ceiling_height_nulls_percent,
	COUNT(*) FILTER (WHERE floors_total IS NULL) * 100.0 / COUNT(*) AS floors_total_nulls_percent,
	COUNT(*) FILTER (WHERE living_area IS NULL) * 100.0 / COUNT(*) AS living_area_nulls_percent,
	COUNT(*) FILTER (WHERE kitchen_area IS NULL) * 100.0 / COUNT(*) AS kitchen_area_nulls_percent,
	COUNT(*) FILTER (WHERE balcony IS NULL) * 100.0 / COUNT(*) AS balcony_nulls_percent,
	COUNT(*) FILTER (WHERE airports_nearest IS NULL) * 100.0 / COUNT(*) AS airports_nearest_nulls_percent,
	COUNT(*) FILTER (WHERE parks_around3000 IS NULL) * 100.0 / COUNT(*) AS parks_around3000_nulls_percent,
	COUNT(*) FILTER (WHERE ponds_around3000 IS NULL) * 100.0 / COUNT(*) AS ponds_around3000_nulls_percent
FROM real_estate.flats;
/* Пропуски обнаружены в следующих столбцах:
 * balcony: (48,7%)
 * ceiling_height: (38,7%)
 * airports_nearest: (23,4%)
 * parks_around3000: (23,3%)
 * ponds_around3000: (23,3%)
 * kitchen_area: (9,6%)
 * living_area: (8%)
 * floors_total: (0,4%)
 * Скорее всего, пропуски можно объяснить неполнотой данных в исходных источниках.
 */

--Проверяем явные дубликаты
WITH duplicates AS (
	SELECT 
	    id,
	    city_id,
	    type_id,
	    total_area,
	    rooms,
	    ceiling_height,
	    floors_total,
	    living_area,
	    total_area,
	    floor,
	    is_apartment,
	    open_plan,
	    kitchen_area,
	    balcony,
	    airports_nearest,
	    parks_around3000,
	    ponds_around3000,
	    COUNT(*)
	FROM real_estate.flats
	GROUP BY 
		id,
	    city_id,
	    type_id,
	    total_area,
	    rooms,
	    ceiling_height,
	    floors_total,
	    living_area,
	    total_area,
	    floor,
	    is_apartment,
	    open_plan,
	    kitchen_area,
	    balcony,
	    airports_nearest,
	    parks_around3000,
	    ponds_around3000
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Явных дубликатов не обнаружено.

--Проверяем неявные дубликаты по сочетанию столбцов
WITH duplicates AS (
	SELECT 
	    city_id, 
	    floor, 
	    floors_total, 
	    total_area, 
	    living_area, 
	    kitchen_area,
		rooms, 
		ceiling_height, 
		is_apartment, 
		open_plan, 
		balcony,
	    COUNT(*)
	FROM real_estate.flats
	GROUP BY 
		city_id, 
	    floor, 
	    floors_total, 
	    total_area, 
	    living_area, 
	    kitchen_area,
		rooms, 
		ceiling_height, 
		is_apartment, 
		open_plan, 
		balcony
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Обнаружено 63 (менее 1%) схожих по характеристикам квартир.



--2.3. Таблица city

SELECT COUNT(*)
FROM real_estate.city;
--Таблица содержит информацию о 305 городах.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE city_id IS NULL) AS city_id_nulls,
    COUNT(*) FILTER (WHERE city IS NULL) AS city_nulls
FROM real_estate.city;
--На первый взгляд пропусков нет.

--Проверяем явные дубликаты
WITH duplicates AS (
	SELECT 
	    city_id,
	    city,
	    COUNT(*)
	FROM real_estate.city
	GROUP BY 
		city_id,
	    city
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Явных дубликатов не обнаружено.

--Проверяем неявные дубликаты
WITH duplicates AS (
	SELECT 
	    city,
	    COUNT(*)
	FROM real_estate.city
	GROUP BY 
	    city
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Неявных дубликатов не обнаружено.



--2.4. Таблица type

SELECT COUNT(*)
FROM real_estate.type;
/* Таблица содержит информацию о 10 типах населённых пунктов: город, посёлок, посёлок 
 * городского типа, городской посёлок, посёлок при железнодорожной станции, коттеджный посёлок,
 * деревня, село, садовое товарищество и садоводческое некоммерческое товарищество.
 */

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE type_id IS NULL) AS type_id_nulls,
    COUNT(*) FILTER (WHERE type IS NULL) AS type_nulls
FROM real_estate.type;
--Пропусков нет.

--Проверяем явные дубликаты
WITH duplicates AS (
	SELECT 
	    type_id,
	    type,
	    COUNT(*)
	FROM real_estate.type
	GROUP BY 
		type_id,
	    type
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Явных дубликатов не обнаружено.

--Проверяем неявные дубликаты
WITH duplicates AS (
	SELECT 
	    type,
	    COUNT(*)
	FROM real_estate.type
	GROUP BY 
	    type
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Неявных дубликатов не обнаружено.



/* 2.5. Промежуточные выводы:
 * 
 * advertisement: 23 650 объявлений, пропуски в days_exposition (13,45%) у незакрытых 
 * объявлений, явных дубликатов нет, неявные — 139 записей (< 1%).
 * 
 * flats: 23 650 объектов недвижимости, пропуски в полях с характеристиками объектов (от 0,4%
 * до 48,7%) можно объяснить отсутствием информации в первоначальных источниках, явных
 * дубликатов нет, неявные — 63 записи (< 1%).
 * 
 * city: 305 городов, пропусков и дубликатов нет.
 * 
 * type: 10 типов населённых пунктов, пропусков и дубликатов нет. 
 */


--3. Анализ категориальных данных

--3.1. Типы населённых пунктов
SELECT 
	type,
	COUNT(*) AS flat_count,
	ROUND(COUNT(*) * 100.0 /(SELECT COUNT(*) FROM real_estate.flats), 2) AS flat_percent
FROM real_estate.flats AS f
LEFT JOIN real_estate.type AS t ON f.type_id = t.type_id
GROUP BY type
ORDER BY COUNT(*) DESC;
/* Большая часть объявлений (85%) содержит информацию о недвижимости в городах. Самое малое
 * количество объявлений у садоводческого некоммерческого товарищества — всего 1 объект.
 */

--3.2. Объявления в Санкт-Петербурге и Ленинградской области
SELECT city_id
FROM real_estate.city
WHERE city = 'Санкт-Петербург';
--6X8I код Санкт-Петербурга

SELECT ROUND(SUM(CASE WHEN city_id = '6X8I' THEN 1 END) * 100.0 / COUNT(*), 2)
FROM real_estate.flats; 

/* Данные содержат примерно 66% объявлений по Санкт-Петербургу и 34% по Ленинградской области.
 * Такое соотношение позволяет изучить объявления в двух субъектах раздельно и сопоставить 
 * результаты между собой, хоть объявлений в Санкт-Петербурге почти в 2 раза больше. 
 * */



--4. Анализ числовых данных

--4.1. Время активности объявлений
SELECT 
	MIN(days_exposition) AS min_days_exposition,
	MAX(days_exposition) AS max_days_exposition,
	ROUND(AVG(days_exposition::numeric), 2) AS avg_days_exposition,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_exposition) AS median_days_exposition
FROM real_estate.advertisement;
/* Медиана меньше среднего значения, что может говорить о наличии единичных высоких 
 * значений, смещающих среднее. Результаты показывают, что половину объявлений сняли 
 * с публикации в течение 95 дней с момента публикации.
 */

--4.2. Доля снятых с публикации объявлений
SELECT ROUND(COUNT(days_exposition) * 100.0 / COUNT(*), 2)
FROM real_estate.advertisement;
--86,55% объявлений закрыто, что даёт хорошую базу для анализа.

--4.3. Стоимость квадратного метра
SELECT 
	ROUND(MIN(last_price / total_area)::numeric,2) AS min_price_per_sqm,
	ROUND(MAX(last_price / total_area)::numeric,2) AS max_price_per_sqm,
	ROUND(AVG(last_price / total_area)::numeric,2) AS avg_price_per_sqm,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY last_price / total_area)::numeric, 2) AS median_price_per_sqm
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a ON f.id = a.id
/* Cреднее значение (99 432) близко к медианному (95 000) — это может говорить или о том, 
 * что в данных нет выбросов, или они есть в части как низких значений, так и высоких. 
 * Действительно, есть низкие значения — 112 рублей за квадратный метр, а есть и высокие — 
 * 1 907 500 рублей за квадратный метр. Возможно, низкие значения представлены не в рублях, 
 * а в тысячах. Высокие же значения вполне могут быть реальной стоимостью. Цель анализа — 
 * получить общее представление о продажах недвижимости в регионах. Поэтому при изучении 
 * общих характеристик данных мы отфильтруем аномально высокие и низкие значения.
 */

--4.4. Характеристики объектов недвижимости
SELECT 
	'общая площадь' AS parameter,
	ROUND(MIN(total_area)::numeric,2) AS min,
	ROUND(MAX(total_area)::numeric,2) AS max,
	ROUND(AVG(total_area)::numeric,2) AS avg,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY total_area)::numeric,2) AS median,
	ROUND(PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area)::numeric,2) AS per_99
FROM real_estate.flats
UNION all
SELECT 
	'количество комнат',
	ROUND(MIN(rooms)::numeric,2) AS min,
	ROUND(MAX(rooms)::numeric,2) AS max,
	ROUND(AVG(rooms)::numeric,2) AS avg,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms)::numeric,2) AS median,
	ROUND(PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms)::numeric,2) AS per_99
FROM real_estate.flats
UNION ALL
SELECT 
	'количество балконов',
	ROUND(MIN(balcony)::numeric,2) AS min,
	ROUND(MAX(balcony)::numeric,2) AS max,
	ROUND(AVG(balcony)::numeric,2) AS avg,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony)::numeric,2) AS median,
	ROUND(PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony)::numeric,2) AS per_99
FROM real_estate.flats
UNION ALL
SELECT 
	'высота потолков',
	ROUND(MIN(ceiling_height)::numeric,2) AS min,
	ROUND(MAX(ceiling_height)::numeric,2) AS max,
	ROUND(AVG(ceiling_height)::numeric,2) AS avg,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ceiling_height)::numeric,2) AS median,
	ROUND(PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height)::numeric,2) AS per_99
FROM real_estate.flats
UNION ALL
SELECT 
	'этаж',
	ROUND(MIN(floor)::numeric,2) AS min,
	ROUND(MAX(floor)::numeric,2) AS max,
	ROUND(AVG(floor)::numeric,2) AS avg,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor)::numeric,2) AS med,
	ROUND(PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY floor)::numeric,2) AS per_99
FROM real_estate.flats;
/* Данные содержат аномально высокие значения практически в каждом столбце, кроме этажа 
 * недвижимости. Это можно проверить, если сравнить максимальное значение с 99 перцентилем. 
 * Столь высокие значения негативно сказываются на средних значениях, поэтому их надо 
 * отфильтровать при основном анализе данных. */



--5. Анализ временных данных
SELECT 
	MIN(first_day_exposition) AS min_date,
	MAX(first_day_exposition) AS max_date
FROM real_estate.advertisement;
/* Имеюшиеся данные включают объявления с 27.11.2014 по 03.05.2019. Данные за 2014 и 2019 года 
 * неполные, поэтому для дальнейшего анализа будем использовать данные за 2015-2018 года.
 */



/* 6. Промежуточные выводы:
 * 
 * Анализ категориальных данных:
 * Большинство объявлений (85%) приходится на города, минимальное количество объявлений — 
 * у садоводческих товариществ (1 объект). Распределение по регионам: примерно 66% объявлений 
 * в Санкт-Петербурге, 34% — в Ленинградской области. Можно анализировать регионы раздельно.
 * 
 * Анализ числовых данных:
 * Время активности объявлений: половину объявлений сняли с публикации в течение 95 дней.
 * Закрытые объявления: 86,55% объявлений сняты с публикации.
 * Стоимость квадратного метра: среднее значение (99 432) близко к медианному (95 000), 
 * но есть минимальные (112 ₽) и максимальные (1,9 млн ₽) выбросы, искажающие анализ.
 * Характеристики объектов: почти все параметры содержат аномально высокие значения. 
 * Для корректного анализа аномальные значения нужно отфильтровать.
 * 
 * Анализ временных данных:
 * Данные охватывают период с 27.11.2014 по 03.05.2019. Полные данные есть только за 2015–2018 
 * годы, на них и будет опираться дальнейший анализ.
 */