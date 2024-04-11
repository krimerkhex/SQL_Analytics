drop function if exists Part4PersonalOffer(Method int, StartEndPeriodDate varchar, AverageCheck float, Churn_Rate float, Discount_Transaction float, Share_Margin float) cascade;
drop function if exists Part4PersonalOffer(Method int, TransactionCount int, AverageCheck float, Churn_Rate float, Discount_Transaction float, Share_Margin float) cascade;
drop function if exists TimeMethod(StartEndPeriodDate varchar, AverageCheck float) cascade;
drop function if exists LastTransactionMethod(TransactionCount int, AverageCheck float) cascade;
drop function if exists DefinitionRemuneration(ChurnRate float, DiscountShare float, MarginShare float) cascade;

create or replace function DefinitionRemuneration
(
    ChurnRate float,
    DiscountShare float,
    MarginShare float
)
returns table
(
    Customer_ID int,
    Group_ID int,
    OfferDiscountDepth float
)
as $$
declare
    row record;
    p_client_id int := 0;
    p_flag bool := false;
begin
    for row in (select * from full_groups_view) loop
        if (p_flag = true and p_client_id = row.customer_id) then continue;
        end if;
        if (row.group_churn_rate <= ChurnRate and
            row.group_discount_share <= DiscountShare and
            row.avegage_margin * MarginShare / 100 >= ceil((row.group_minimum_discount * 100) / 5.0) * 0.05 * row.avegage_margin) then
            Customer_ID = row.customer_id;
            Group_ID = row.group_id;
            OfferDiscountDepth = ceil((row.group_minimum_discount * 100) / 5.0) * 5;
            p_client_id = row.customer_id;
            p_flag = true;
            return next;
        else
            p_flag := false;
        end if;
        end loop;
    end;
$$ language plpgsql;

create or replace function TimeMethod
(
    StartEndPeriodDate varchar,
    AverageCheck float
)
returns table
(
   Customer_ID int,
   Required_Check_Measure float
)
as $$
declare
    StartDate date := split_part(StartEndPeriodDate, ' ', 1)::date;
    EndDate date := split_part(StartEndPeriodDate, ' ', 2)::date;
begin
    if StartDate is null or StartDate < (select min(transaction_datetime) from transactions) then
        StartDate := (select min(transaction_datetime) from transactions);
    end if;
     if EndDate is null or EndDate > (select max(transaction_datetime) from transactions) then
        EndDate := (select max(transaction_datetime) from transactions);
    end if;
    return query
    select phv.customer_id, avg(phv.group_summ) * AverageCheck from purchase_history_view phv
    group by phv.customer_id
    order by phv.customer_id;
end;
$$ language plpgsql;

create or replace function LastTransactionMethod
(
    TransactionCount int,
    AverageCheck float
)
returns table
(
   Customer_ID int,
   Required_Check_Measure float
)
as $$
begin
return query
    with temp as (
        select phv.customer_id, phv.group_summ
        from purchase_history_view phv
        order by transaction_datetime desc
        limit TransactionCount
    )
    select temp.customer_id, avg(temp.group_summ) * AverageCheck from temp
    group by temp.customer_id
    order by temp.customer_id;
end;
$$ language plpgsql;

create or replace function Part4PersonalOffer
(
    Method int,
    StartEndPeriodDate varchar,
    AverageCheck float,
    Churn_Rate float,
    Discount_Transaction float,
    Share_Margin float
)
returns table
(
    Customer_ID int,
    Required_Check_Measure float,
    Group_Name text,
    Offer_Discount_Depth float
)
as $$
begin
    if Method = 1 then
        return query
        select tm.Customer_ID, tm.Required_Check_Measure, gs.Group_Name, dr.OfferDiscountDepth
        from TimeMethod(StartEndPeriodDate, AverageCheck) tm
        inner join definitionremuneration(Churn_Rate, Discount_Transaction, Share_Margin) dr on dr.customer_id = tm.customer_id
        inner join groupsku gs on dr.group_id = gs.group_id
        group by tm.Customer_ID, tm.Required_Check_Measure, gs.Group_Name, dr.OfferDiscountDepth
        order by 1;
    else
        raise exception 'Введен неправильный метод';
    end if;
end;
$$ language plpgsql;

create or replace function Part4PersonalOffer
(
    Method int,
    TransactionCount int,
    AverageCheck float,
    Churn_Rate float,
    Discount_Transaction float,
    Share_Margin float
)
returns table
(
    Customer_ID int,
    Required_Check_Measure float,
    Group_Name text,
    Offer_Discount_Depth float
)
as $$
begin
    if Method = 2 then
        return query
        select ltm.Customer_ID, ltm.Required_Check_Measure, gs.Group_Name, dr.OfferDiscountDepth
        from LastTransactionMethod(TransactionCount, AverageCheck) ltm
        inner join definitionremuneration(Churn_Rate, Discount_Transaction, Share_Margin) dr on dr.customer_id = ltm.customer_id
        inner join groupsku gs on dr.group_id = gs.group_id
        group by ltm.Customer_ID, ltm.Required_Check_Measure, gs.Group_Name, dr.OfferDiscountDepth
        order by 1;
    else
        raise exception 'Введен неправильный метод';
    end if;
end;
$$ language plpgsql;

select * from part4personaloffer(2, 100, 1.15::float, 1::float, 50::float, 20::float);
