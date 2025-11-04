/* Проект «Расчёт и визуализация метрик сервиса доставки еды»
 * Цель проекта: Разработать дашборд с ключевыми метриками клиентской базы сервиса доставки еды 
 * в Саранске (май–июнь 2021) для анализа активности пользователей, конверсии, среднего чека, LTV и Retention Rate 
 * и подготовить аналитическую записку с практическими выводами для принятия управленческих решений.
 * Автор: Зотова Дарья
 * Дата: 06.08.2025
*/

--Расчёт DAU

/* Рассчитаем ежедневное количество активных зарегистрированных клиентов за май и июнь 2021 года в городе Саранске. 
 * Критерием активности клиента будем считать размещение заказа. Это позволит оценить эффективность вовлечения 
 * клиентов в ключевую бизнес-цель — совершение покупки.
*/

SELECT
    log_date,
    COUNT(DISTINCT user_id) FILTER(WHERE event = 'order') AS DAU
FROM rest_analytics.analytics_events
JOIN rest_analytics.cities USING(city_id)
WHERE 
    city_name = 'Саранск' AND
    log_date >= '2021-05-01' AND
    log_date <= '2021-06-30'
GROUP BY log_date
ORDER BY log_date;


--Расчёт Conversion Rate

/* Теперь нужно определить активность аудитории: как часто зарегистрированные пользователи переходят к размещению 
 * заказа, будет ли одинаковым этот показатель по дням или видны сезонные колебания в поведении пользователей. 
 * Рассчитаем конверсию зарегистрированных пользователей, которые посещают приложение, в активных клиентов 
 * (критерий активности — размещение заказа) за каждый день в мае и июне 2021 года для клиентов из Саранска.
*/

SELECT
    log_date,
    ROUND(COUNT(DISTINCT user_id) FILTER(WHERE event = 'order') / NULLIF(COUNT(DISTINCT user_id)::numeric, 0), 2) AS CR
FROM rest_analytics.analytics_events
JOIN rest_analytics.cities USING(city_id)
WHERE 
    city_name = 'Саранск' AND
    log_date >= '2021-05-01' AND
    log_date <= '2021-06-30'
GROUP BY log_date
ORDER BY log_date;


--Расчёт среднего чека

/* Рассчитаем средний чек активных клиентов в Саранске в мае и в июне. Поскольку мы анализируем сервис доставки,
 * средним чеком будет являться среднее значение комиссии сервиса со всех заказов за месяц. 
 */

WITH orders AS ( -- рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
    SELECT *,
            revenue * commission AS commission_revenue
     FROM rest_analytics.analytics_events
     JOIN rest_analytics.cities USING(city_id)
     WHERE 
     	revenue IS NOT NULL AND
        log_date BETWEEN '2021-05-01' AND '2021-06-30' AND
        city_name = 'Саранск'
        )
        
SELECT
    DATE_TRUNC('month', log_date)::date AS "Месяц",
    COUNT(DISTINCT order_id) AS "Количество заказов",
    ROUND(SUM(commission_revenue)::numeric, 2) AS "Сумма комиссии",
    ROUND(SUM(commission_revenue)::numeric / COUNT(DISTINCT order_id)::numeric, 2) AS "Средний чек"
FROM orders
GROUP BY DATE_TRUNC('month', log_date)
ORDER BY 1;


--Расчёт LTV ресторанов

/* Определим три ресторана из Саранска с наибольшим LTV с начала мая до конца июня. Будем считать LTV как 
 * суммарную комиссию, которая была получена от заказов в ресторане за эти два месяца.
*/

WITH orders AS ( -- рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
    SELECT 
    	e.rest_id,
    	e.city_id,
    	revenue * commission AS commission_revenue
     FROM rest_analytics.analytics_events AS e
     JOIN rest_analytics.cities AS c ON e.city_id = c.city_id
     WHERE 
     	revenue IS NOT NULL AND
        log_date BETWEEN '2021-05-01' AND '2021-06-30' AND
        city_name = 'Саранск'
        )
        
SELECT 
    o.rest_id,
    chain AS "Название сети",
    type AS "Тип кухни",
    ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM orders AS o
JOIN rest_analytics.partners AS p ON 
    o.rest_id = p.rest_id AND
    o.city_id = p.city_id
GROUP BY o.rest_id, chain, type
ORDER BY LTV DESC
LIMIT 3;


--Расчёт LTV ресторанов — самые популярные блюда

/* Определим LTV самых пяти самых популярных блюд из двух ресторанов Саранска с наибольшим LTV по результатам 
 * предыдущего запроса — «Гурманское Наслаждение» и «Гастрономический Шторм».
*/ 

-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS ( -- рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
    SELECT 
    	e.rest_id,
    	e.city_id,
    	e.object_id,
    	revenue * commission AS commission_revenue
     FROM rest_analytics.analytics_events AS e
     JOIN rest_analytics.cities AS c ON e.city_id = c.city_id
     WHERE 
     	revenue IS NOT NULL AND
        log_date BETWEEN '2021-05-01' AND '2021-06-30' AND
        city_name = 'Саранск'
     ), 
        
top_ltv_restaurants AS ( -- рассчитываем два ресторана с наибольшим LTV 
    SELECT o.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders AS o
     JOIN rest_analytics.partners AS p ON 
     	o.rest_id = p.rest_id AND 
     	o.city_id = p.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2
     )
     
SELECT
    chain AS "Название сети",
    name AS "Название блюда",
    spicy,
    fish,
    meat,
    ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM orders AS o
JOIN rest_analytics.dishes AS d ON o.object_id = d.object_id
JOIN top_ltv_restaurants AS t ON o.rest_id = t.rest_id
GROUP BY 1, 2, 3, 4, 5
ORDER BY LTV DESC
LIMIT 5;


--Расчёт Retention Rate

/* Рассчитаем показатель Retention Rate в первую неделю для всех новых пользователей в Саранске. В проекте мы 
 * анализируем данные за май и июнь, и для корректного расчёта недельного Retention Rate нужно, чтобы с момента 
 * первого посещения прошла хотя бы неделя. Поэтому для этой задачи ограничим дату первого посещения продукта, 
 * выбрав промежуток с начала мая по 23 июня. Retention Rate будем считать по любой активности пользователей, 
 * а не только по факту размещения заказа.
*/

WITH new_users AS ( -- рассчитываем новых пользователей по дате первого посещения продукта
    SELECT DISTINCT 
    	first_date,
        user_id
     FROM rest_analytics.analytics_events
     JOIN rest_analytics.cities USING(city_id)
     WHERE 
     	first_date BETWEEN '2021-05-01' AND '2021-06-23' AND 
     	city_name = 'Саранск'
     ),
     
active_users AS ( -- рассчитываем активных пользователей по дате события
    SELECT DISTINCT 
    	log_date,
    	user_id
     FROM rest_analytics.analytics_events
     JOIN rest_analytics.cities USING(city_id)
     WHERE 
     	log_date BETWEEN '2021-05-01' AND '2021-06-30' AND 
     	city_name = 'Саранск'
    ),
     
daily_retention AS ( --рассчитываем количество дней с момента регистрации для каждого события
    SELECT 
        n.user_id,
        first_date,
        log_date::date - first_date::date AS day_since_install
    FROM new_users AS n
    JOIN active_users AS a ON n.user_id = a.user_id
    WHERE log_date >= first_date
    )   
    
SELECT
    day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND(COUNT(DISTINCT user_id) * 1.0 / MAX(COUNT(DISTINCT user_id)) OVER(ORDER BY day_since_install), 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY day_since_install
ORDER BY day_since_install;


--Сравнение Retention Rate по месяцам

WITH new_users AS ( -- рассчитываем новых пользователей по дате первого посещения продукта
    SELECT DISTINCT 
    	first_date,
    	user_id
     FROM rest_analytics.analytics_events
     JOIN rest_analytics.cities USING(city_id)
     WHERE 
     	first_date BETWEEN '2021-05-01' AND '2021-06-23' AND 
     	city_name = 'Саранск'
    ),
    
active_users AS ( -- рассчитываем активных пользователей по дате события
    SELECT DISTINCT 
    	log_date,
    	user_id
     FROM rest_analytics.analytics_events
     JOIN rest_analytics.cities USING(city_id)
     WHERE 
     	log_date BETWEEN '2021-05-01' AND '2021-06-30' AND 
     	city_name = 'Саранск'
    ),
    
daily_retention AS ( --рассчитываем количество дней с момента регистрации для каждого события
    SELECT 
        n.user_id,
        first_date,
        log_date::date - first_date::date AS day_since_install
    FROM new_users AS n
    JOIN active_users AS a on n.user_id = a.user_id
    WHERE log_date >= first_date
    ) 
    
SELECT
    CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",
	day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND(COUNT(DISTINCT user_id) * 1.0 / MAX(COUNT(DISTINCT user_id)) OVER(PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date) ORDER BY day_since_install), 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY Месяц, day_since_install
ORDER BY "Месяц", day_since_install;
