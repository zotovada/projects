/* Проект «Анализ данных сервиса Яндекс Афиша»
 * Цель проекта: провести исследовательский анализ данных Яндекс Афиши и построить дашборд в DataLens, чтобы выявить изменения 
 * в пользовательских предпочтениях, популярности событий и выручке, а также подготовить сервис к зимним акциям.
 * Автор: Зотова Дарья
 * Дата: 30.09.2025
*/

-- Часть 1. Знакомство с данными

-- 1. Структура данных

--Список таблиц в схеме:
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'afisha';

/* Схема afisha базы данных data-analyst-afisha содержит пять таблиц:
* purchases — информация о заказах билетов.
* events — данные о мероприятиях, доступных на платформе.
* venues — сведения о площадках проведения мероприятий.
* regions— список регионов, в которых проводятся мероприятия.
* city — список городов, относящихся к регионам.
*/

--Список колонок таблиц:
SELECT 
	table_name,
	column_name, 
	data_type
FROM information_schema.columns
WHERE table_schema = 'afisha'
  AND table_name IN (
	SELECT table_name
	FROM information_schema.tables
	WHERE table_schema = 'afisha'
	)
ORDER BY table_name;

/* Описание таблицы purchases:
* order_id — уникальный идентификатор заказа.
* user_id — уникальный идентификатор пользователя.
* created_dt_msk — дата создания заказа (московское время).
* created_ts_msk — дата и время создания заказа (московское время).
* event_id — идентификатор мероприятия из таблицы events.
* cinema_circuit — сеть кинотеатров. Если не применимо, то здесь будет значение 'нет'.
* age_limit — возрастное ограничение мероприятия.
* currency_code — валюта оплаты, например rub для российских рублей.
* device_type_canonical — тип устройства (например mobile для мобильных устройств, desktop для стационарных).
* revenue — выручка от заказа.
* service_name — название билетного оператора.
* tickets_count — количество купленных билетов.
* total — общая сумма заказа.
*/

/* Описание таблицы events:
* event_id — уникальный идентификатор мероприятия.
* event_name_code — название мероприятия в закодированном виде.
* event_type_description — описание мероприятия.
* event_type_main — основной тип мероприятия: театральная постановка, концерт и так далее.
* organizers — организаторы мероприятия.
* city_id — идентификатор города проведения мероприятия из таблицы cities.
* venue_id — идентификатор площадки проведения мероприятия из таблицы venues.
*/

/* Описание таблицы venues:
* venue_id — уникальный идентификатор площадки.
* venue_name — название площадки.
* address — адрес площадки.
*/

/* Описание таблицы city:
* city_id — уникальный идентификатор города.
* city_name — название города.
* region_id — идентификатор региона, к которому относится город, из таблицы regions.
*/

/* Описание таблицы regions:
* region_id — уникальный идентификатор региона.
* region_name — название региона.
*/

-- Данные во всех столбцах всех таблиц представлены корректными типами.

--Ключи:
SELECT 
	constraint_type, 
	constraint_name, 
	table_name
FROM information_schema.table_constraints
WHERE table_schema = 'afisha';

/* В схеме afisha таблицы загружены без ключей. На деле они связаны между собой (например, заказы ссылаются на мероприятия, 
* а мероприятия — на города), но эти связи не прописаны в базе и по запросу не отображаются. Сопоставим связи вручную.
*/

/* Первичные ключи:
 * order_id для таблицы purchases;
 * event_id для таблицы events;
 * venue_id для таблицы venues;
 * city_id для таблицы city;
 * region_id для таблицы regions. 
 */

/* Внешние ключи:
 * event_id связывает таблицы purchases и events типом связи «один ко многим» (к одному событию относятся много заказов);
 * venue_id связывает таблицы events и venues типом связи «один ко многим» (на одной площадке проходит много событий);
 * city_id связывает таблицы events и city типом связи «один ко многим» (в одном городе проводится много событий);
 * region_id связывает таблицы city и regions типом связи «один ко многим» (в одном регионе находится много городов).
 */



--2. Содержимое таблиц

--2.1. Таблица purchases:
SELECT COUNT(*)
FROM afisha.purchases p; 
--Таблица содержит информацию о 292 034 заказах.

SELECT COUNT(DISTINCT user_id)
FROM afisha.purchases p;
--Заказы совершили 22 000 пользователей.

SELECT *
FROM afisha.purchases p 
LIMIT 5;
--Данные соответствуют описанию.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_nulls,
    COUNT(*) FILTER (WHERE user_id IS NULL) AS user_id_nulls,
    COUNT(*) FILTER (WHERE created_dt_msk IS NULL) AS created_dt_nulls,
    COUNT(*) FILTER (WHERE created_ts_msk IS NULL) AS created_ts_nulls,
    COUNT(*) FILTER (WHERE event_id IS NULL) AS event_id_nulls,
    COUNT(*) FILTER (WHERE cinema_circuit IS NULL) AS cinema_circuit_nulls,
    COUNT(*) FILTER (WHERE age_limit IS NULL) AS age_limit_nulls,
    COUNT(*) FILTER (WHERE currency_code IS NULL) AS currency_code_nulls,
    COUNT(*) FILTER (WHERE device_type_canonical IS NULL) AS device_type_nulls,
    COUNT(*) FILTER (WHERE revenue IS NULL) AS revenue_nulls,
    COUNT(*) FILTER (WHERE service_name IS NULL) AS service_name_nulls,
    COUNT(*) FILTER (WHERE tickets_count IS NULL) AS tickets_count_nulls,
    COUNT(*) FILTER (WHERE total IS NULL) AS total_nulls
FROM afisha.purchases p;
--На первый взгляд пропусков в столбцах таблицы не обнаружено.

--Проверяем уникальность идентификаторов заказов
SELECT 
	order_id,
	COUNT(*)
FROM afisha.purchases p
GROUP BY order_id
HAVING COUNT(*) > 1;
--Идентификаторы заказов уникальны.

--Проверяем корректность категориальных данных
SELECT DISTINCT cinema_circuit
FROM afisha.purchases p;
--В таблице содержатся данные о 4 кинотеатрах, а также категории «Другое» и «нет».

SELECT DISTINCT currency_code 
FROM afisha.purchases p;
--В таблице содержатся данные об оплате в рублях и казахских тенге.

SELECT DISTINCT device_type_canonical 
FROM afisha.purchases p;
--В таблице содержатся данные о 4 типах девайсов и категория «other».

SELECT DISTINCT service_name 
FROM afisha.purchases p
ORDER BY service_name;
--В таблице содержатся данные о 36 билетных операторах. «Тебе билет!» и «Тебебилет» могут быть одним и тем же оператором. 

--Проверяем неявные дубликаты по сочетанию столбцов
WITH duplicates AS (
	SELECT 
	    user_id,
	    event_id,
	    created_ts_msk,
	    tickets_count,
	    revenue,
	    total,
	    COUNT(*)
	FROM afisha.purchases p
	GROUP BY 
		user_id, 
		event_id, 
		created_ts_msk, 
		tickets_count, 
		revenue,
		total
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;

/* Обнаружен 41 потенциальный неявный дубликат (меньше 1% от всех записей) по сочетанию столбцов:
 * идентификатор пользователя;
 * идентификатор мероприятия;
 * дата и время создания заказа;
 * количество билетов;
 * выручка от заказа;
 * общая сумма заказа.
 * Дубли могут быть вызваны технической ошибкой и повторной регистрацией одного заказа системой.
 */



--2.2. Таблица events:
SELECT COUNT(*)
FROM afisha.events e 
--Таблица информацию о 22 484 мероприятиях.

SELECT COUNT(DISTINCT event_name_code)
FROM afisha.events e
--Таблица содержит 15 287 названий мероприятий. Одно и то же событие могло проводиться в разных городах на разных площадках.

SELECT *
FROM afisha.events e 
LIMIT 5
--Данные соответствуют описанию.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE event_id IS NULL) AS event_id_nulls,
    COUNT(*) FILTER (WHERE event_name_code IS NULL) AS event_name_code_nulls,
    COUNT(*) FILTER (WHERE event_type_description IS NULL) AS event_type_description_nulls,
    COUNT(*) FILTER (WHERE event_type_main IS NULL) AS event_type_main_nulls,
    COUNT(*) FILTER (WHERE organizers IS NULL) AS organizers_nulls,
    COUNT(*) FILTER (WHERE city_id IS NULL) AS city_id_nulls,
    COUNT(*) FILTER (WHERE venue_id IS NULL) AS venue_id_nulls
FROM afisha.events e;
--На первый взгляд пропусков в столбцах таблицы не обнаружено.

--Проверяем уникальность идентификаторов мероприятий
SELECT 
	event_id,
	COUNT(*)
FROM afisha.events e
GROUP BY event_id
HAVING COUNT(*) > 1;
--Идентификаторы мероприятий уникальны.

--Проверяем корректность категориальных данных
SELECT DISTINCT event_type_main
FROM afisha.events e;
--В таблице содержатся данные о 7 типах мероприятий и категории «другое».

--Проверяем неявные дубликаты по сочетанию столбцов
WITH duplicates AS (
	SELECT 
	    event_name_code,
	    event_type_main,
	    organizers,
	    city_id,
	    venue_id,
	    COUNT(*)
	FROM afisha.events
	GROUP BY 
		event_name_code, 
		event_type_main, 
		organizers, 
		city_id, 
		venue_id
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;

/* Обнаружены 692 потенциальных неявных дубликатов (около 3% от всех записей) по сочетанию столбцов:
 * название мероприятия в закодированном виде;
 * основной тип мероприятия;
 * организатор мероприятия;
 * идентификатор города;
 * идентификатор площадки.
 * Это могут быть как неявные дубли, так серия мероприятий или повторные показы. Например, концерт или спектакль идёт 
 * несколько дней подряд в одном городе и на одной площадке. Тогда указанные столбцы будут совпадать, но будут разные
 * даты проведения, о которых у нас нет информации.
 */



--2.3. Таблица venues:
SELECT COUNT(*)
FROM afisha.venues v  
--Таблица содержит информацию о 3 228 площадках.

SELECT *
FROM afisha.venues v
LIMIT 5
--Данные соответствуют описанию.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE venue_id IS NULL) AS venue_id_nulls,
    COUNT(*) FILTER (WHERE venue_name IS NULL) AS venue_name_nulls,
    COUNT(*) FILTER (WHERE address IS NULL) AS address_nulls
FROM afisha.venues v;
--На первый взгляд пропусков в столбцах таблицы не обнаружено.

--Проверяем уникальность идентификаторов площадок
SELECT 
	venue_id,
	COUNT(*)
FROM afisha.venues v
GROUP BY venue_id
HAVING COUNT(*) > 1;
--Идентификаторы площадок уникальны.

--Проверяем неявные дубликаты по сочетанию столбцов
WITH duplicates AS (
	SELECT 
	    venue_name,
	    address,
	    COUNT(*)
	FROM afisha.venues v
	GROUP BY 
		venue_name,
	    address
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Неявных дубликатов по сочетанию столбцов с названием и адресом площадки не обнаружено.



--2.4. Таблица city:
SELECT COUNT(*)
FROM afisha.city c   
--Таблица содержит информацию о 353 городах.

SELECT *
FROM afisha.city c
LIMIT 5
--Данные соответствуют описанию.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE city_id IS NULL) AS city_id_nulls,
    COUNT(*) FILTER (WHERE city_name IS NULL) AS city_name_nulls,
    COUNT(*) FILTER (WHERE region_id IS NULL) AS region_id_nulls
FROM afisha.city c;
--На первый взгляд пропусков в столбцах таблицы не обнаружено.

--Проверяем уникальность идентификаторов городов
SELECT 
	city_id,
	COUNT(*)
FROM afisha.city c
GROUP BY city_id
HAVING COUNT(*) > 1;
--Идентификаторы городов уникальны.

--Проверяем неявные дубликаты по сочетанию столбцов
WITH duplicates AS (
	SELECT 
	    city_name,
	    region_id,
	    COUNT(*)
	FROM afisha.city c
	GROUP BY 
		city_name,
	    region_id
	HAVING COUNT(*) > 1
)
SELECT COUNT(*)
FROM duplicates;
--Неявных дубликатов по сочетанию столбцов с названием города и идентификатором региона не обнаружено.



--2.5. Таблица regions:
SELECT COUNT(*)
FROM afisha.regions r    
--Таблица содержит информацию о 81 регионе.

SELECT *
FROM afisha.regions r
LIMIT 5
--Данные соответствуют описанию.

--Проверяем пропуски
SELECT 
    COUNT(*) FILTER (WHERE region_id IS NULL) AS region_id_nulls,
    COUNT(*) FILTER (WHERE region_name IS NULL) AS region_name_nulls
FROM afisha.regions r;
--На первый взгляд пропусков в столбцах таблицы не обнаружено.

--Проверяем уникальность идентификаторов регионов
SELECT 
	region_id,
	COUNT(*)
FROM afisha.regions r
GROUP BY region_id
HAVING COUNT(*) > 1;
--Идентификаторы регионов уникальны.

/* 2.6. Промежуточные выводы:
 * purchases: 292 034 заказа от 22 000 пользователей, пропусков нет, 41 потенциальный неявный дубликат (<1%).
 * events: 22 484 мероприятия, пропусков нет, 692 потенциальных неявных дубликата (~3%).
 * venues: 3 228 площадок, пропусков и дублей нет.
 * city: 353 города, пропусков и дублей нет.
 * regions: 81 регион, пропусков и дублей нет.
 * Главное: данные в целом корректные и готовы к анализу. Небольшие дубли в purchases и events незначительны.
 */



--3. Анализ категориальных данных

--3.1. Распределение по типам мероприятий
SELECT
	event_type_main,
	COUNT(*) AS order_count
FROM afisha.purchases p 
LEFT JOIN afisha.events e USING(event_id)
GROUP BY event_type_main
ORDER BY order_count DESC;
/* Абсолютный лидер — концерты (115 634 заказа). Театр (67 744 заказов) и категория «другое» (66 109) занимают 2 и 3 места.
 * Спорт (22 006) и стендап (13 424) заметно отстают, но тоже востребованы. Выставки (4 873) и ёлки (2 006) остаются 
 * нишевыми категориями с ограниченным интересом. Фильмы (238 заказов) практически не представлены — очевидно, 
 * пользователи платформы покупают билеты в кино через другие сервисы или напрямую в кинотеатрах.
 */

--3.2. Распределение по возрастному ограничению
SELECT
	age_limit,
	COUNT(*) AS order_count
FROM afisha.purchases p 
GROUP BY age_limit
ORDER BY order_count DESC;
/* Больше всего заказов приходится на категории 16+ (78 864 заказов) и 12+ (62 861 заказов). Существенный объём у 0+ (61 731) 
 * и 6+ (52 403) — семейные и детские мероприятия тоже популярны. Меньше всего — у 18+ (36 175 заказов). 
 * */

--3.3. Распределение по типам устройства
SELECT
	device_type_canonical,
	COUNT(*) AS order_count
FROM afisha.purchases p 
GROUP BY device_type_canonical
ORDER BY order_count DESC;
/* Большинство заказов оформлено с мобильных устройств (232 679 заказа), значительно меньше — с ПК (58 170 заказов). 
 * С планшетов оформили 1 180 заказов. Остальные устройства почти не используются. 
 */

--3.4. Распределение по количеству билетов
SELECT
	tickets_count,
	COUNT(*) AS order_count
FROM afisha.purchases p 
GROUP BY tickets_count
ORDER BY order_count DESC;
/* Большинство заказов — на 3 билета (92 700 заказа), 2 билета (84 240) и 4 билета (55 100). Заказы на 1 билет — 41 963. 
 * Крупные заказы (>10 билетов) встречаются крайне редко.
 */

--3.5. Топ-10 билетных оператора
SELECT
	service_name,
	COUNT(*) AS order_count
FROM afisha.purchases p 
GROUP BY service_name
ORDER BY order_count DESC
LIMIT 10;
/* Лидируют «Билеты без проблем» (63 932 заказа), далее идут «Лови билет!» (41 338) и «Билеты в руки» (40 500). 
 * Остальные операторы занимают менее 35 тыс. заказов, десятый в топе — «Тебе билет!» (5 242). 
 */

--3.6. Топ-10 площадок
SELECT
	venue_name,
	COUNT(*) AS order_count
FROM afisha.purchases p 
LEFT JOIN afisha.events e USING(event_id)
LEFT JOIN afisha.venues v USING(venue_id)
GROUP BY venue_name
ORDER BY order_count DESC
LIMIT 10;
/* Лидирует студия дизайна «Платформа» (9 950 заказов), далее с заметным отрывом идут креативное пространство «Вдох» (4 479) 
 * и картинная галерея «Светлячок» (4 418). Остальные площадки имеют сопоставимый уровень заказов — около 3,5–4 тыс. каждая. 
 */

--3.7. Топ-10 городов
SELECT
	city_name,
	COUNT(*) AS order_count
FROM afisha.purchases p 
LEFT JOIN afisha.events e USING(event_id)
LEFT JOIN afisha.city c USING(city_id)
GROUP BY city_name
ORDER BY order_count DESC
LIMIT 10;
/* Явный лидер — Глиногорск (90 087 заказов), почти вдвое опережающий ближайший город Озёрск (44 142). Остальные города 
 * значительно уступают, каждый набирает менее 14 тыс. заказов. 
 */

--3.8. Топ-10 регионов
SELECT
	region_name,
	COUNT(*) AS order_count
FROM afisha.purchases p 
LEFT JOIN afisha.events e USING(event_id)
LEFT JOIN afisha.city c USING(city_id)
LEFT JOIN afisha.regions r USING(region_id)
GROUP BY region_name
ORDER BY order_count DESC
LIMIT 10;
/* Лидирует Каменевский регион (91 701 заказ), почти вдвое опережая Североярскую область (44 282). Остальные регионы 
 * значительно уступают, каждый набирает менее 17 тыс. заказов. 
 */

--3.9. Распределение по валюте оплаты
SELECT
	currency_code,
	COUNT(*) AS order_count
FROM afisha.purchases p 
GROUP BY currency_code
ORDER BY order_count DESC;
--Большинство заказов оплачены в рублях (286 961 заказов), доля казахских тенге крайне мала — 5 073 заказа.

/* 3.10. Промежуточные выводы:
 * Концерты лидируют — 115 634 заказа, далее театр (67 744) и другое (66 109). Наименее представлены фильмы (238).
 * Основная масса 16+ (78 864 заказов) и 12+ (62 861), затем семейные — (61 731) и 6+ (52 403), меньше всего 18+ (36 175).
 * По устройствам: mobile — 232 679 заказов, desktop — 58 170, tablet — 1 180, tv/other — 5 заказов.
 * Количество билетов: чаще всего 3 (92 700), 2 (84 240), 4 (55 100). Крупные заказы (>10 билетов) крайне редки.
 * Топ-операторы: «Билеты без проблем» (63 932), «Лови билет!» (41 338), «Билеты в руки» (40 500).
 * Топ-площадки: «Платформа» (9 950), далее «Вдох» (4 479), «Светлячок» (4 418); остальные около 3–4 тыс. заказов.
 * Топ-города: Глиногорск (90 087), Озёрск (44 142); остальные города <14 тыс. заказов.
 * Топ-регионы: Каменевский (91 701), Североярская область (44 282); остальные <17 тыс. заказов.
 * Валюта: RUB — 286 961 заказов, KZT — 5 073.
 * Главное: большинство заказов — концерты и театры, 16+ и 12+. Покупают через мобильные устройства, по 2–4 билета.
 * Наименее представлены фильмы и события 18+. Мало покупают через планшеты и tv, редко берут больше 4 билетов.
 * Большинство купленных билетов в рублях, доля заказов в тенге составляет чуть меньше 2%.
 */



--4. Анализ числовых данных

--4.1. Анализ столбца revenue (rub)
SELECT
	MIN(revenue) AS min_revenue,
	MAX(revenue) AS max_revenue,
	ROUND(AVG(revenue)::numeric, 2) AS avg_revenue,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric, 2) AS median_revenue,
	ROUND(STDDEV(revenue)::numeric, 2) AS stddev_revenue
FROM afisha.purchases p
WHERE currency_code = 'rub';
/* Медиана — 346 ₽, то есть половина заказов приносит комиссию меньше этой суммы.
 * Среднее — 548 ₽, выше медианы, что указывает на наличие редких крупных заказов, слегка «тянущих» среднее вверх.
 * Разброс умеренный (СКО ~871 ₽): встречаются как отрицательные значения (вероятно, возвраты, min = –90.76 ₽), 
 * так и крупные комиссии (до 81 175 ₽).
 * Основная масса заказов приносит небольшую комиссию, а редкие крупные заказы лишь слегка влияют на среднее.
 */

--4.2. Анализ столбца revenue (kzt)
SELECT
	MIN(revenue) AS min_revenue,
	MAX(revenue) AS max_revenue,
	ROUND(AVG(revenue)::numeric, 2) AS avg_revenue,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue)::numeric, 2) AS median_revenue,
	ROUND(STDDEV(revenue)::numeric, 2) AS stddev_revenue
FROM afisha.purchases p
WHERE currency_code = 'kzt';
/* Медиана — 3 699 ₸, то есть половина заказов приносит комиссию меньше этой суммы. 
 * Среднее — 4 995 ₸, немного выше медианы, что указывает на наличие редких крупных заказов, слегка «тянущих» среднее вверх. 
 * Разброс умеренный (СКО ~4 917 ₸): встречаются нулевые комиссии (min = 0 ₸) и крупные значения (до 26 426 ₸). 
 * Основная масса заказов приносит умеренную комиссию, редкие крупные заказы лишь слегка влияют на среднее.
 */

--4.3. Анализ столбца total (rub)
SELECT
	MIN(total) AS min_total,
	MAX(total) AS max_total,
	ROUND(AVG(total)::numeric, 2) AS avg_total,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total)::numeric, 2) AS median_total,
	ROUND(STDDEV(total)::numeric, 2) AS stddev_total
FROM afisha.purchases p
WHERE currency_code = 'rub';
/* Медиана — 4 661 ₽, половина заказов меньше этой суммы.
 * Среднее — 6 327 ₽, выше медианы из-за редких крупных покупок, «тянущих» среднее вверх.
 * СКО ~8 610 ₽ указывает на значительный разброс.
 * Есть аномалии: отрицательные суммы (–359 ₽, вероятно возвраты) и экстремально большие заказы (до 812 тыс. ₽).
 * Основная масса заказов сосредоточена в диапазоне нескольких тысяч рублей, редкие крупные покупки заметно влияют на среднее.
 */

--4.4. Анализ столбца total (kzt)
SELECT
	MIN(total) AS min_total,
	MAX(total) AS max_total,
	ROUND(AVG(total)::numeric, 2) AS avg_total,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total)::numeric, 2) AS median_total,
	ROUND(STDDEV(total)::numeric, 2) AS stddev_total
FROM afisha.purchases p
WHERE currency_code = 'kzt';
/* Медиана — 61 647 ₸, половина заказов меньше этой суммы.
 * Среднее — 75 238 ₸, выше медианы из-за редких крупных покупок, «тянущих» среднее вверх.
 * СКО ~68 031 ₸ указывает на значительный разброс.
 * Есть аномалии: нулевые суммы (min = 0 ₸) и экстремально крупные заказы (до 344 607 ₸).
 * Основная масса заказов сосредоточена в диапазоне нескольких десятков тысяч ₸, редкие крупные покупки сильно влияют на среднее.
 */

--4.5. Анализ столбца tickets_count
SELECT
	MIN(tickets_count) AS min_tickets_count,
	MAX(tickets_count) AS max_tickets_count,
	ROUND(AVG(tickets_count)::numeric, 2) AS avg_tickets_count,
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY tickets_count)::numeric, 2) AS median_tickets_count,
	ROUND(STDDEV(tickets_count)::numeric, 2) AS stddev_tickets_count
FROM afisha.purchases p;
/* Медиана — 3 билета, это наиболее типичный заказ.
 * Среднее — 2,75, почти совпадает с медианой, что указывает на симметричное распределение.
 * СКО ~1,2 говорит о небольшом разбросе.
 * Минимум — 1 билет, максимум — 57, но такие крупные заказы редкость и почти не влияют на общую картину.
 * В основном пользователи покупают 2–4 билета за раз.
 */

/* 4.6. Промежуточные выводы:
 * revenue (выручка от заказа) в rub: медиана 346 ₽, среднее 548 ₽, СКО ~871 ₽. Редкие крупные заказы слегка повышают среднее, 
 * встречаются отрицательные значения (min = –90,76 ₽) и крупные комиссии (до 81 175 ₽).
 * revenue (выручка от заказа) в kzt: медиана 3 699 ₸, среднее 4 995 ₸, СКО ~4 917 ₸. Редкие крупные заказы слегка смещают 
 * среднее, есть нулевые комиссии (min = 0 ₸) и крупные значения (до 26 426 ₸).
 * total (сумма заказа) в rub: медиана 4 661 ₽, среднее 6 327 ₽, СКО ~8 610 ₽. Крупные покупки значительно повышают 
 * среднее, встречаются отрицательные значения (min = -358,85 ₽) и экстремально крупные заказы (811 745,4 ₽).
 * total (сумма заказа) в kzt: медиана 61 647 ₸, среднее 75 238 ₸, СКО ~68 031 ₸. Крупные покупки значительно повышают 
 * среднее, встречаются нулевые суммы и экстремально крупные заказы (до 344 607 ₸).
 * tickets_count (количество билетов): медиана 3, среднее 2,75, СКО ~1,17. Основная масса заказов — 2–4 билета. 
 * Крупные заказы (до 57 билетов) редки и практически не влияют на общую картину.
 * Главное: редкие крупные заказы влияют на средние значения для total и revenue, поэтому медиана более показательна.
 * Разброс по тенге чуть выше, возможно из-за меньшей представленности в данных (286 961 заказов в ₽ против 5 073 заказов в ₸).
 */



--5. Анализ временных данных

--5.1. Период времени, за который представлены данные
SELECT
	MIN(created_dt_msk)::date AS min_dt,
	MAX(created_dt_msk)::date AS max_dt
FROM afisha.purchases p;
--Данные охватывают весь летний период и два месяца осени 2024 года.

--5.2. Распределение заказов по месяцам
SELECT 
	DATE_TRUNC('month', created_dt_msk)::date AS month,
	COUNT(*) AS order_count
FROM afisha.purchases p
GROUP BY DATE_TRUNC('month', created_dt_msk)::date
ORDER BY month;
/* Лето (июнь–август): спрос на летние события умеренный, вероятно, из-за отпусков и путешествий. 
 * Осень (сентябрь–октябрь): резкий рост спроса. Люди возвращаются к обычному ритму жизни, начинается театральный 
 * сезон — в сервисе билеты на театры и концерты приобретаются чаще всего.
 */
 
/* 5.3. Промежуточные выводы:
 * Данные охватывают лето и два осенних месяца 2024 года. 
 * Летом (июнь–август) наблюдается умеренный спрос на мероприятия, вероятно из-за отпусков и путешествий. 
 * Осенью (сентябрь–октябрь) происходит резкий рост заказов: люди возвращаются после каникул, открывается театральный сезон.
 */