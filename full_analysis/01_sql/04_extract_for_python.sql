/* Проект «Анализ данных сервиса Яндекс Афиша»
 * Цель проекта: провести исследовательский анализ данных Яндекс Афиши и построить дашборд в DataLens, чтобы выявить изменения 
 * в пользовательских предпочтениях, популярности событий и выручке, а также подготовить сервис к зимним акциям.
 * Автор: Зотова Дарья
 * Дата: 30.09.2025
*/

-- Часть 4. Получение данных для исследовательского анализа в Python

--Получаем данные для датасета final_tickets_orders_df.csv
SELECT *,
       created_dt_msk::date - LAG(created_dt_msk) OVER(PARTITION BY user_id ORDER BY created_dt_msk)::date 
AS days_since_prev
FROM afisha.purchases
WHERE device_type_canonical IN ('mobile', 'desktop');
/* Датасет включает информацию обо всех заказах билетов, совершённых с двух типов устройств — мобильных и 
 * стационарных. В данные также был добавлен столбец days_since_prev с количеством дней с предыдущей покупки 
 * для каждого пользователя. Если покупки не было, то данные содержат пропуск.
 */

--Получаем данные для датасета final_tickets_events_df.csv
SELECT -- Выгружаем данные таблицы events:
 e.event_id,
 e.event_name_code AS event_name,
 e.event_type_description,
 e.event_type_main,
 e.organizers, 
 -- Выгружаем информацию о городе и регионе:
 r.region_name,
 c.city_name,
 c.city_id, 
 -- Выгружаем информацию о площадке:
 v.venue_id,
 v.venue_name,
 v.address AS venue_address
FROM afisha.events AS e
LEFT JOIN afisha.venues AS v USING(venue_id)
LEFT JOIN afisha.city AS c USING(city_id)
LEFT JOIN afisha.regions AS r USING(region_id)
WHERE e.event_id IN
    (SELECT DISTINCT event_id
     FROM afisha.purchases
     WHERE device_type_canonical IN ('mobile', 'desktop'))
  AND e.event_type_main != 'фильм';
--Датасет содержит информацию о событиях, включая регион, город и площадку проведения мероприятия.