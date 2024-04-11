DROP FUNCTION if exists personaloffer(integer,double precision,double precision,double precision,double precision);

create or replace function PersonalOffer
(
  Count_Groups int,
  Max_Churn float,
  Max_Consumption_Stability float,
  Share_SKU float,
  Share_Margin float
)
returns table
(
   Customer_ID int,
   SKU_Name text,
   Offer_Discount_Depth float
)
as $$
begin
  return query with group_sampling as (
    select distinct c.customer_id, g.group_id
    from part2_customers c
    join group_view_support_1 g on g.customer_id = c.customer_id
    where g.group_churn_rate <= Max_Churn and g.group_stability_index < Max_Consumption_Stability
    order by g.group_id desc
    limit Count_Groups
  ), max_margin_sku as (
    select phs.customer_id, r.transaction_store_id, r.sku_id, c.sku_name, c.group_id, (r.sku_retail_price - r.sku_purchase_price) as margin, r.sku_retail_price, r.sku_purchase_price from retailoutlets r
    join commoditymatrix c on r.sku_id = c.sku_id
    join purchase_history_support phs on c.group_id = phs.group_id and r.transaction_store_id = phs.transaction_store_id and r.sku_id = phs.sku_id
    join part2_primary_store p2ps on phs.transaction_store_id = p2ps.customer_primary_store and p2ps.customer_id = phs.customer_id
    group by phs.customer_id, r.transaction_store_id, r.sku_id, c.group_id, c.sku_name
  ), sku_ratio as (
    select mms.customer_id, mms.group_id, mms.sku_name, (count(distinct p1.transaction_id)::float / count(distinct p2.transaction_id)::float)::float as ratio from group_sampling gs
    join max_margin_sku mms on mms.group_id = gs.group_id
    join purchase_history_support p1 on p1.sku_id = mms.sku_id
    join purchase_history_support p2 on p2.group_id = gs.group_id
    group by mms.customer_id, mms.group_id, mms.sku_name
  )
  select sr.customer_id, sr.sku_name, ceil(LEAST((margin * ratio) / mms.sku_retail_price, (Share_Margin / 100) * 5)) * 5 AS offer_discount_depth
  from sku_ratio sr
  join max_margin_sku mms on mms.customer_id = sr.customer_id and mms.sku_name = sr.sku_name and mms.group_id = sr.group_id
  join group_sampling gs on gs.group_id = sr.group_id and gs.customer_id = sr.customer_id
  where sr.ratio <= Share_SKU;

end;
$$ language plpgsql;

select * from PersonalOffer(5, 3, 0.35, 100, 50);