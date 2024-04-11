-- ---------------------------------------------------------------------------
--                      Представление Клиенты                                |
-- ---------------------------------------------------------------------------

-- Создание представления для формирования списков карт клиентов
CREATE OR REPLACE VIEW part2_customer_cards AS
SELECT distinct
    c.Customer_ID,
    ARRAY_AGG(Customer_Card_ID) AS Customer_Cards
FROM cards c
right join personalinformation p on p.customer_id = c.customer_id
where c.customer_id is not null
GROUP BY c.Customer_ID;

-- Создание представления для расчета среднего чека клиентов
CREATE OR REPLACE VIEW part2_customer_avg_check AS
SELECT distinct
    c.Customer_ID,
    AVG(Transaction_Summ) AS Customer_Average_Check
FROM transactions
join cards c on transactions.customer_card_id = c.customer_card_id
right join personalinformation p on p.customer_id = c.customer_id
where c.customer_id is not null
GROUP BY c.Customer_ID;

-- Создание представления для ранжирования клиентов по среднему чеку
CREATE OR REPLACE VIEW part2_customer_avg_check_rank AS
SELECT
    Customer_ID,
    Customer_Average_Check,
    RANK() OVER (ORDER BY Customer_Average_Check DESC) AS avg_check_rank
FROM part2_customer_avg_check;

-- Создание представления для определения сегмента по среднему чеку
CREATE OR REPLACE VIEW part2_customer_avg_check_segment AS
SELECT distinct
    Customer_ID,
    Customer_Average_Check,
    CASE
        WHEN Customer_Average_Check IS NULL THEN NULL
        WHEN avg_check_rank <= 0.1 * COUNT(*) OVER() THEN 'High'
        WHEN avg_check_rank <= 0.35 * COUNT(*) OVER() THEN 'Medium'
        ELSE 'Low'
    END AS Customer_Average_Check_Segment
FROM part2_customer_avg_check_rank;


-- Создание представления для определения интенсивности транзакций клиентов
CREATE OR REPLACE VIEW part2_customer_frequency AS
SELECT distinct
    p.Customer_ID,
    EXTRACT(epoch from (MAX(Transaction_DateTime) - MIN(Transaction_DateTime))) / (COUNT(DISTINCT Transaction_ID)::FLOAT)
        / 86400.0 AS Customer_Frequency
FROM transactions
join cards c on transactions.customer_card_id = c.customer_card_id
right join personalinformation p on p.customer_id = c.customer_id
GROUP BY p.Customer_ID;


-- Создание представления для ранжирования клиентов по частоте визитов
CREATE OR REPLACE VIEW part2_customer_frequency_rank AS
SELECT distinct
    Customer_ID,
    Customer_Frequency,
    RANK() OVER (ORDER BY Customer_Frequency) AS frequency_rank
FROM part2_customer_frequency;

-- Создание представления для определения сегмента по частоте визитов
CREATE OR REPLACE VIEW part2_customer_frequency_segment AS
SELECT distinct
    Customer_ID,
    Customer_Frequency,
    CASE
        WHEN customer_frequency is null THEN null
        WHEN frequency_rank <= 0.1 * COUNT(*) OVER() THEN 'Often'
        WHEN frequency_rank <= 0.35 * COUNT(*) OVER() THEN 'Occasionally'
        ELSE 'Rarely'
    END AS Customer_Frequency_Segment
FROM part2_customer_frequency_rank;

-- Создание представления для определения периода после предыдущей транзакции
CREATE OR REPLACE VIEW part2_customer_inactive_period_fixed AS
SELECT
    p.Customer_ID,
    abs(EXTRACT(EPOCH FROM (SELECT * FROM analysisdate LIMIT 1) - MAX(t.Transaction_DateTime))) / 86400.0  AS Customer_Inactive_Period
FROM transactions t
JOIN cards c ON t.customer_card_id = c.customer_card_id
RIGHT JOIN personalinformation p ON p.customer_id = c.customer_id
GROUP BY p.Customer_ID;

-- Создание представления для расчета коэффициента оттока клиентов
CREATE OR REPLACE VIEW part2_customer_churn_rate AS
SELECT distinct
    cip.Customer_ID,
    case
        when Customer_Frequency > 0 then
            cip.Customer_Inactive_Period::float / Customer_Frequency::float
        else
            Customer_Inactive_Period
    end as Customer_Churn_Rate
FROM part2_customer_inactive_period_fixed cip
right JOIN part2_customer_frequency USING (Customer_ID);

-- Создание представления для определения сегмента по вероятности оттока
CREATE OR REPLACE VIEW part2_customer_churn_segment AS
SELECT distinct
    Customer_ID,
    Customer_Churn_Rate,
    CASE
        WHEN Customer_Churn_Rate IS NULL THEN NULL
        WHEN Customer_Churn_Rate BETWEEN 0 AND 2 THEN 'Low'
        WHEN Customer_Churn_Rate BETWEEN 2 AND 5 THEN 'Medium'
        ELSE 'High'
    END AS Customer_Churn_Segment
FROM part2_customer_churn_rate;


CREATE OR REPLACE VIEW part2_customer_segment AS
SELECT distinct
    p.Customer_ID,
                (select s.segments from segments s where s.average_check = Customer_Average_Check_Segment
                    and s.frequency_of_purchases = Customer_Frequency_Segment
                    and s.churn_probability = Customer_Churn_Segment limit 1) as Customer_Segment
FROM personalinformation p
right JOIN part2_customer_avg_check_segment a using(Customer_ID)
right JOIN part2_customer_frequency_segment f USING (Customer_ID)
right JOIN part2_customer_churn_segment cr USING (Customer_ID)
right JOIN part2_customer_cards c USING (Customer_ID)
order by Customer_Segment;


-- Создаем представление с долей транзакций в каждом магазине
CREATE OR REPLACE VIEW transactions_share AS
SELECT
    p.Customer_ID,
    t.Transaction_Store_ID,
    t.transaction_datetime,
    CASE
        WHEN SUM(COUNT(t.Transaction_ID)) OVER (PARTITION BY p.Customer_ID) IS NOT NULL THEN
            COUNT(t.Transaction_ID) * 1.0 / NULLIF(SUM(COUNT(t.Transaction_ID)) OVER (PARTITION BY p.Customer_ID), 0)
        ELSE COUNT(t.Transaction_ID) * 1.0
    END AS Transaction_Share
FROM
    transactions t
JOIN cards c ON t.customer_card_id = c.customer_card_id
RIGHT JOIN personalinformation p ON p.customer_id = c.customer_id
GROUP BY
    p.Customer_ID,
    t.Transaction_Store_ID,
    t.transaction_datetime;

 -- Создаем представление с тремя последними транзакциями каждого клиента
CREATE OR REPLACE VIEW last_three_transactions AS
SELECT
    p.Customer_ID,
    t.Transaction_Store_ID,
    ROW_NUMBER() OVER (PARTITION BY p.Customer_ID ORDER BY t.Transaction_DateTime DESC) as rn
FROM transactions t
join cards c on t.customer_card_id = c.customer_card_id
right join personalinformation p on p.customer_id = c.customer_id;


 -- Создаем представление с основным магазином клиента
CREATE OR REPLACE VIEW part2_primary_store AS
SELECT Customer_ID, MAX(Customer_Primary_Store) AS Customer_Primary_Store
FROM (
    SELECT
        ts.Customer_ID,
        CASE
            WHEN ltt.Transaction_Store_ID IS NOT NULL THEN ltt.Transaction_Store_ID
            ELSE FIRST_VALUE(ts.Transaction_Store_ID) OVER (PARTITION BY ts.Customer_ID ORDER BY ts.Transaction_Share DESC, ts.Transaction_DateTime DESC)
        END as Customer_Primary_Store
    FROM
        transactions_share ts
    LEFT JOIN
        (SELECT Customer_ID, Transaction_Store_ID FROM last_three_transactions WHERE rn <= 3 GROUP BY Customer_ID, Transaction_Store_ID HAVING COUNT(*) = 3) ltt
        ON ts.Customer_ID = ltt.Customer_ID
) subquery
GROUP BY Customer_ID;


-- Создание представления, объединяющего все данные о клиентах
CREATE OR REPLACE VIEW part2_customers AS
SELECT DISTINCT
    pi.Customer_ID,
    ac.Customer_Average_Check,
    acc.Customer_Average_Check_Segment,
    cf.Customer_Frequency,
    cff.Customer_Frequency_Segment,
    cip.customer_inactive_period,
    cr.Customer_Churn_Rate,
    crr.Customer_Churn_Segment,
    cs.Customer_Segment,
    cps.Customer_Primary_Store
FROM part2_customer_cards c
JOIN part2_customer_churn_segment crr USING (Customer_ID)
JOIN part2_customer_frequency_segment cff USING (Customer_ID)
JOIN part2_customer_avg_check_segment acc USING (Customer_ID)
JOIN part2_customer_avg_check ac USING (Customer_ID)
JOIN part2_customer_inactive_period_fixed cip USING (Customer_ID)
JOIN part2_customer_frequency cf USING (Customer_ID)
JOIN part2_customer_churn_rate cr USING (Customer_ID)
JOIN part2_customer_segment cs USING (Customer_ID)
JOIN part2_primary_store cps USING (Customer_ID)
RIGHT JOIN personalinformation pi USING (Customer_ID);


-- ---------------------------------------------------------------------------
--                      Представление История покупок                        |
-- ---------------------------------------------------------------------------

-- -- Purchase history View
create or replace view purchase_history_support as
select
    p.customer_id as customer_id ,
    t.transaction_id as transaction_id,
    t.transaction_datetime as transaction_datetime,
    t.transaction_store_id as transaction_store_id,
    m.group_id as group_id,
    ch.sku_amount as sku_amount,
    r.sku_id as sku_id,
    r.sku_retail_price as sku_retail_price,
    r.sku_purchase_price as sku_purchase_price,
    ch.sku_summ_paid as sku_summ_paid,
    ch.sku_summ as sku_summ,
    ch.sku_discount as sku_discount
from
    transactions as t
    right join cards as c on c.customer_card_id = t.customer_card_id
    right join personalinformation as p on p.customer_id = c.customer_id
    left join checks as ch on t.transaction_id = ch.transaction_id
    left join commoditymatrix as m on m.sku_id = ch.sku_id
    left join retailoutlets as r on m.sku_id = r.sku_id and t.transaction_store_id = r.transaction_store_id;

drop view if exists purchase_history_view cascade;
create view purchase_history_view as
select distinct customer_id,
       transaction_id,
       transaction_datetime,
       group_id,
       sum(sku_purchase_price * sku_amount) as group_cost,
       sum(sku_summ) as group_summ,
       sum(sku_summ_paid) as summ_paid
from purchase_history_support
group by customer_id, transaction_id, transaction_datetime, group_id
order by customer_id, transaction_id;


-- ---------------------------------------------------------------------------
--                      Представление Периоды                                |
-- ---------------------------------------------------------------------------
create or replace function calcDiscount(id int, group_2 int)
returns float
as
    $$
declare
begin
    return
    (select min(sku_discount / sku_summ) as discont
        from checks
        left join transactions using(transaction_id)
        left join cards using(customer_card_id)
        left join commoditymatrix using(sku_id)
        where sku_discount / sku_summ != 0 and customer_id = id and group_id = group_2
        group by customer_id,group_id limit 1);
end;
$$ language plpgsql;

drop view if exists periods_view cascade;
create view periods_view as
select
    phs.customer_id as customer_id,
    phs.group_id as group_id ,
    min(t.transaction_datetime) as first_group_purchase_date,
    max(t.transaction_datetime) as last_group_purchase_date,
    case when phs.group_id is not null then count(*) else null end as group_purchase_count,
    (((extract(epoch from (max(t.transaction_datetime) - min(t.transaction_datetime)))::float / 86400.0 + 1)*1.0) / count(*)*1.0) as group_frequency,
    calcDiscount(phs.customer_id, phs.group_id) as group_minimum_discount
from
    purchase_history_support phs
    left join transactions t on phs.transaction_id = t.transaction_id
group by  phs.customer_id,phs.group_id
order by phs.customer_id,phs.group_id;
--
-- -- ---------------------------------------------------------------------------
-- --                      Представление Группы                                 |
-- -- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calcTotalTransactions(id int, group_2 int)
RETURNS float AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM purchase_history_view
        WHERE customer_id = id
        AND transaction_datetime BETWEEN (
            SELECT first_group_purchase_date
            FROM periods_view pv
            WHERE pv.customer_id = id
            AND pv.group_id = group_2
        ) AND (
            SELECT last_group_purchase_date
            FROM periods_view pv
            WHERE pv.customer_id = id
            AND pv.group_id = group_2
        )
    );
END;
$$ LANGUAGE plpgsql;
 -- Drop view part2_Customer_Transactions
DROP VIEW IF EXISTS part2_Customer_Transactions;
CREATE VIEW part2_Customer_Transactions AS
SELECT
    ph.customer_id,
    ph.group_id,
    calcTotalTransactions(ph.customer_id, ph.group_id) AS Total_Transactions
FROM purchase_history_view ph
GROUP BY ph.customer_id, ph.group_id;
 -- Drop view part2_Group_Affinity_Index
DROP VIEW IF EXISTS part2_Group_Affinity_Index;
CREATE VIEW part2_Group_Affinity_Index AS
SELECT
    pv.customer_id AS customer_id,
    pv.group_id AS group_id,
    pv.Group_Purchase_Count,
    pv.Group_Purchase_Count / CAST(tc.Total_Transactions AS float) AS Group_Affinity_Index
FROM periods_view pv
JOIN (
    SELECT
        customer_id,
        group_id,
        SUM(Total_Transactions) AS Total_Transactions
    FROM part2_Customer_Transactions
    GROUP BY customer_id, group_id
) tc ON pv.customer_id = tc.customer_id AND pv.group_id = tc.group_id;
 -- Create or replace the function Group_Acquisition_Duration
CREATE OR REPLACE FUNCTION Group_Acquisition_Duration(id int, group_2 int)
RETURNS float AS $$
BEGIN
    RETURN (
        SELECT EXTRACT(epoch FROM (SELECT analysis_formation FROM analysisdate LIMIT 1) - MAX(transaction_datetime)) / 86400.0
        FROM purchase_history_view
        WHERE customer_id = id
        AND group_id = group_2
    );
END;
$$ LANGUAGE plpgsql;
 -- Drop view part2_Group_Churn_Rate
DROP VIEW IF EXISTS part2_Group_Churn_Rate;
CREATE VIEW part2_Group_Churn_Rate AS
SELECT
    customer_id,
    group_id,
    Group_Acquisition_Duration(customer_id, group_id) / Group_Frequency AS Group_Churn_Rate
FROM periods_view;
 -- Create or replace view group_consumption_intervals1
CREATE OR REPLACE VIEW group_consumption_intervals1 AS
SELECT
    customer_id,
    group_id,
    transaction_datetime,
    transaction_id,
    EXTRACT(epoch FROM LAG(transaction_datetime) OVER (PARTITION BY customer_id, group_id ORDER BY transaction_datetime DESC)  - transaction_datetime) / 86400.0 AS date_difference
FROM purchase_history_view
ORDER BY customer_id, group_id, transaction_datetime DESC;

 -- Create or replace view GroupIntervalDeviationView
CREATE OR REPLACE VIEW GroupIntervalDeviationView AS
SELECT
    gci.customer_id,
    gci.group_id,
    gci.transaction_id,
    ABS(gci.date_difference - pv.group_frequency) / pv.group_frequency AS interval_deviations
FROM group_consumption_intervals1 gci
JOIN periods_view pv USING (customer_id, group_id)
ORDER BY customer_id, group_id;

 -- Create or replace view CalcStability_Index
CREATE OR REPLACE VIEW CalcStability_Index AS
SELECT
    customer_id,
    group_id,
    COALESCE(AVG(interval_deviations), 1) AS Group_Stability_Index
FROM GroupIntervalDeviationView
GROUP BY customer_id, group_id;


 -- Create or replace view group_view_support_1
CREATE OR REPLACE VIEW group_view_support_1 AS
SELECT
    customer_id,
    group_id,
    Group_Affinity_Index,
    Group_Churn_Rate,
    Group_Stability_Index,
    (
        SELECT COUNT(transaction_id)
        FROM Purchase_History_Support VB
        WHERE part2_Group_Affinity_Index.customer_id = VB.customer_id
        AND part2_Group_Affinity_Index.group_id = VB.group_id
        AND VB.sku_discount != 0
    )::float / part2_Group_Affinity_Index.Group_Purchase_Count AS Group_Discount_Share,
    (
        SELECT MIN(sku_discount / sku_summ)
        FROM Purchase_History_Support AS VB
        WHERE VB.customer_id = part2_Group_Affinity_Index.customer_id
        AND VB.group_id = part2_Group_Affinity_Index.group_id
        AND sku_discount / sku_summ > 0.0
    ) AS Group_Minimum_Discount,
    AVG(sku_summ_paid / sku_summ) FILTER (WHERE purchase_history_support.sku_discount <> 0 AND transaction_datetime IS NOT NULL) AS Group_Average_Discount
FROM part2_Group_Affinity_Index
JOIN part2_Group_Churn_Rate USING (customer_id, group_id)
JOIN CalcStability_Index USING (customer_id, group_id)
JOIN purchase_history_support USING (customer_id, group_id)
GROUP BY customer_id, group_id, Group_Affinity_Index, Group_Churn_Rate, Group_Stability_Index, part2_Group_Affinity_Index.Group_Purchase_Count;
 -- Create or replace view group_view_support
CREATE OR REPLACE VIEW group_view_support AS
SELECT
    customer_id,
    group_id,
    AVG(sku_summ_paid / sku_summ) OVER (PARTITION BY customer_id, group_id) AS Group_Average_Discount
FROM Purchase_History_Support
WHERE sku_discount <> 0
ORDER BY customer_id, group_id;
 -- Create or replace the function fnc_create_Groups_View_2
-- DROP FUNCTION IF EXISTS fnc_create_Groups_View_2;
CREATE OR REPLACE FUNCTION fnc_create_Groups_View_2(
    IN int DEFAULT 1,
    IN interval DEFAULT '5000 days'::interval,
    IN int DEFAULT 100
)
RETURNS TABLE (
    customer_id int,
    group_id int,
    Group_Affinity_Index float,
    Group_Churn_Rate float,
    Group_Stability_Index float,
    Group_Margin float,
    Group_Discount_Share float,
    Group_Minimum_Discount float,
    Group_Average_Discount float
)
AS $$
BEGIN
    RETURN QUERY
    (
        SELECT
            pi.customer_id,
            p2GAI.group_id,
            p2GAI.Group_Affinity_Index,
            p2GAI.Group_Churn_Rate,
            p2GAI.Group_Stability_Index,
            COALESCE(
                CASE
                    WHEN ($1 = 1) THEN
                        SUM((phv.summ_paid - phv.group_cost)::float) FILTER (
                            WHERE phv.Transaction_DateTime BETWEEN (SELECT Analysis_Formation FROM analysisdate) - $2
                            AND (SELECT Analysis_Formation FROM analysisdate)
                        )
                    WHEN ($1 = 2) THEN
                        MG.sum
                END, 0
            ) AS Group_Margin,
            p2GAI.Group_Discount_Share,
            p2GAI.Group_Minimum_Discount::float,
            cigiGAD.Group_Average_Discount::float AS Group_Average_Discount
        FROM group_view_support_1 p2GAI
        JOIN purchase_history_view phv USING (customer_id, group_id)
        LEFT JOIN (
            SELECT
                MG.customer_id,
                MG.group_id,
                SUM((MG.summ_paid - MG.group_cost)::float) AS sum
            FROM (
                SELECT
                    phv2.customer_id,
                    phv2.group_id,
                    phv2.Transaction_DateTime,
                    phv2.summ_paid,
                    phv2.group_cost,
                    ROW_NUMBER() OVER (ORDER BY phv2.Transaction_DateTime DESC) AS row_num
                FROM purchase_history_view phv2
                WHERE phv2.transaction_datetime IS NOT NULL
                ORDER BY phv2.customer_id, phv2.group_id, phv2.Transaction_DateTime DESC
            ) MG
            WHERE row_num < $3
            GROUP BY MG.customer_id, MG.group_id
        ) MG USING (customer_id, group_id)
        LEFT JOIN (
            SELECT
                PHS3.customer_id,
                PHS3.group_id,
                SUM(PHS3.sku_summ_paid) / SUM(PHS3.sku_summ) AS Group_Average_Discount
            FROM Purchase_History_Support PHS3
            WHERE PHS3.sku_discount <> 0
            GROUP BY PHS3.customer_id, PHS3.group_id
            ORDER BY PHS3.customer_id, PHS3.group_id
        ) cigiGAD USING (customer_id, group_id)
        RIGHT JOIN personalinformation pi USING (customer_id)
        GROUP BY pi.customer_id, p2GAI.group_id, p2GAI.Group_Affinity_Index, p2GAI.Group_Churn_Rate, p2GAI.Group_Stability_Index, p2gai.group_discount_share, p2gai.group_minimum_discount, cigigad.group_average_discount, mg.sum
    );
END;
$$ LANGUAGE plpgsql;
 -- Execute the modified function
SELECT * FROM fnc_create_Groups_View_2(1, '5000 days'::interval, 100) ORDER BY customer_id, group_id;


-- DROP VIEW IF EXISTS full_groups_view CASCADE;
CREATE VIEW full_groups_view AS
WITH avg AS (
    SELECT customer_id, group_id, avg(SGM.margin)::real AS Avegage_Margin
    FROM (SELECT customer_id, group_id, ("summ_paid" - "group_summ") as margin
        FROM purchase_history_view) as SGM
    GROUP BY 1, 2)
SELECT gv.*, avg.Avegage_Margin,
       row_number() over (partition by gv.customer_id order by group_affinity_index DESC) as rank
FROM group_view_support_1 gv
JOIN avg ON avg.customer_id = gv.customer_id AND avg.group_id = gv.group_id
ORDER BY customer_id, rank;

