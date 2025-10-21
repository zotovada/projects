/* Проект «Анализ данных сервиса Яндекс Афиша»
 * Цель проекта: провести исследовательский анализ данных Яндекс Афиши и построить дашборд в DataLens, чтобы выявить изменения 
 * в пользовательских предпочтениях, популярности событий и выручке, а также подготовить сервис к зимним акциям.
 * Автор: Зотова Дарья
 * Дата: 30.09.2025
*/

-- Часть 2. Вычисление ключевых метрик продукта

--Общие значения ключевых показателей сервиса в разрезе валют
SELECT
    currency_code,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS total_orders,
    ROUND(AVG(revenue)::numeric, 2) AS avg_revenue_per_order,
    COUNT(DISTINCT user_id) AS total_users
FROM afisha.purchases p
GROUP BY currency_code
ORDER BY total_revenue DESC;
--Заказов в тенге намного меньше, чем в рублях (чуть меньше 2%), но в дальнейшем их всё равно стоит учитывать.

--Распределение выручки в разрезе устройств (rub)
SELECT
    device_type_canonical,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS total_orders,
    ROUND(AVG(revenue)::numeric, 2) AS avg_revenue_per_order,
    ROUND(SUM(revenue)::numeric / (
        SELECT SUM(revenue)
        FROM afisha.purchases
        WHERE currency_code = 'rub'
    )::numeric, 3) AS revenue_share
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY device_type_canonical
ORDER BY revenue_share DESC;
--Основная часть выручки приходится на мобильные устройства (79%) и ПК (20%), доля остальных устройств меньше 1%.

--Распределение выручки в разрезе мероприятий (rub)
SELECT
    event_type_main,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS total_orders,
    ROUND(AVG(revenue)::numeric, 2) AS avg_revenue_per_order,
    COUNT(DISTINCT event_name_code) AS total_event_name,
    ROUND(AVG(tickets_count)::numeric, 2) AS avg_tickets,
    ROUND(SUM(revenue)::numeric / SUM(tickets_count)::numeric, 2) AS avg_ticket_revenue,
    ROUND(SUM(revenue)::numeric / (
        SELECT SUM(revenue)
        FROM afisha.purchases
        WHERE currency_code = 'rub'
    )::numeric, 3) AS revenue_share
FROM afisha.purchases AS p
LEFT JOIN afisha.events AS e USING(event_id)
WHERE currency_code = 'rub'
GROUP BY event_type_main
ORDER BY total_orders DESC;
--Наибольшую долю в структуре выручки занимают концерты (57%), театральные постановки (24%) и категория «другое» (10%).

--Динамика изменения значений по неделям (rub)
SELECT
    DATE_TRUNC('week', created_dt_msk)::date AS week,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    ROUND(SUM(revenue)::numeric / COUNT(*)::numeric, 2)  AS revenue_per_order 
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY DATE_TRUNC('week', created_dt_msk)::date
ORDER BY week;
/* Динамика недельной выручки и активности пользователей показывает постепенный рост летом с небольшими колебаниями, 
 * а с сентября наблюдается резкий подъём заказов и выручки. Летом (июнь–август) средняя выручка на заказ растёт от 450 ₽ 
 * до 646 ₽, количество заказов стабильно около 7–10 тыс., а число уникальных пользователей — 2–2,6 тыс. С начала сентября 
 * резко увеличивается поток заказов: за первую неделю сентября 15 642 заказа при 6 926 391 ₽ выручки, число пользователей — 
 * 3–4 тыс. Пик активности приходится на октябрь: 22–23 тыс. заказов в неделю, выручка до 12 млн ₽, средняя выручка на заказ 
 * около 535–565 ₽. Последняя неделя октября показывает спад: 14 612 заказов, выручка 6,9 млн ₽, средний чек 473 ₽.
 * Основная тенденция: летом спрос умеренный, осенью резко возрастает, что соответствует сезону культурных мероприятий.
 */

--Топ-7 регионов по значению общей выручки (rub)
SELECT
    region_name,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    SUM(tickets_count) AS total_tickets,
    ROUND(SUM(revenue)::numeric / SUM(tickets_count)::numeric, 2) AS one_ticket_cost 
FROM afisha.purchases AS p
LEFT JOIN afisha.events AS e USING(event_id)
LEFT JOIN afisha.city AS c USING(city_id)
LEFT JOIN afisha.regions AS r USING(region_id)
WHERE currency_code = 'rub'
GROUP BY region_name
ORDER BY total_revenue DESC
LIMIT 7;
/* Лидирует Каменевский регион по выручке (61 555 620 ₽) и количеству заказов (91 634). В некоторых регионах со сравнительно
 * умеренным числом заказов, например, Малиновоярский округ (6 634 заказа, средняя стоимость билета 341 ₽) и Озернинский край 
 * (10 502 заказа, средняя стоимость билета 331 ₽), средняя стоимость билета выше чем в более регионах с бОльшим потоком 
 * заказов, что может говорить о более дорогих мероприятиях. При этом регионы с наибольшим числом заказов, например,
 * Североярская область (44 282 заказа) не всегда имеют самый высокий средний чек на билет (203 ₽).
 */

/* Промежуточные выводы:
 * Подавляющее большинство заказов оформлено в рублях, доля тенге менее 2%.
 * Основная выручка поступает с мобильных устройств (79%) и ПК (20%), остальные устройства практически незначимы.
 * Наибольший вклад в выручку вносят концерты (57%) и театры (24%), категория «другое» — 10%. 
 * Лето — умеренный спрос (7–10 тыс. заказов в неделю, средний чек 450–646 ₽), с сентября — резкий рост до 22–23 тыс. 
 * заказов в неделю, средний чек 535–565 ₽. Последняя неделя октября — спад (14,6 тыс. заказов, средний чек 473 ₽).
 * Каменевский регион лидирует по выручке (61,56 млн ₽) и заказам (91 634). 
 * Главное: сервис демонстрирует сезонную активность с пиком осенью, основная выручка генерируется через мобильные устройства
 * и ПК, наибольший вклад в выручку вносят концерты и театральные постановки. Подавляющее большинство заказов в рублях.
 */