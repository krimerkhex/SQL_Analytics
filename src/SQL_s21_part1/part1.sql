-- Стиль нейминга таблиц UpperCamel
create table Segments
(
    Segments serial unique primary key,
    Average_check varchar not null,
    Frequency_of_purchases varchar not null,
    Churn_probability varchar not null
);

create table PersonalInformation
(
  Customer_ID serial unique primary key,                           -- Идентификатор клиента
  Customer_Name text check (Customer_Name ~                        -- Имя
  '^[A-Za-zА-Яа-яЁё][- A-Za-zА-Яа-яЁё]*$'),
  Customer_Surname text check (Customer_Surname ~                  -- Фамилия
  '^[A-Za-zА-Яа-яЁё][- A-Za-zА-Яа-яЁё]*$'),
  Customer_Primary_Email text check (Customer_Primary_Email ~      -- E-mail клиента
  '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+.[A-Za-z]{2,}$'),
  Customer_Primary_Phone text check (Customer_Primary_Phone ~      -- Телефон клиента
  '^\+7[0-9]{10}$')
);

create table GroupSKU
(
    Group_ID serial unique primary key,
    Group_Name text not null
);

create table CommodityMatrix
(
  SKU_ID serial unique primary key,
  SKU_Name text not null,
  Group_ID serial references GroupSKU(Group_ID) not null
);

create table RetailOutlets
(
  Transaction_Store_ID int not null,
  SKU_ID serial references CommodityMatrix(SKU_ID) not null,
  SKU_Purchase_Price numeric(18, 13) not null,
  SKU_Retail_Price numeric(18, 13) not null default 0,
  primary key (Transaction_Store_ID, SKU_ID)
);

create table Cards
(
  Customer_Card_ID serial primary key,
  Customer_ID serial references PersonalInformation(Customer_ID) not null
);

create table Transactions
(
  Transaction_ID serial unique primary key,
  Customer_Card_ID serial references Cards(Customer_Card_ID) not null,
  Transaction_Summ numeric(18, 13) not null default 0,   -- Сумма транзакции в рублях (полная стоимость покупки без учета скидок)
  Transaction_DateTime TIMESTAMP(0)  WITHOUT TIME ZONE,   -- Дата и время совершения транзакции
  Transaction_Store_ID int not null -- Магазин, в котором была совершена транзакция
);
-- drop table Checks;
create table Checks
(
  Transaction_ID serial references Transactions(Transaction_ID) not null,
  SKU_ID serial references CommodityMatrix(SKU_ID) not null,
  SKU_Amount numeric(18, 13) not null default 0,    -- Указание, какое количество товара было куплено
  SKU_Summ numeric(18, 13) not null default 0,      -- Сумма покупки фактического объема данного товара в рублях (полная стоимость без учета скидок и бонусов)
  SKU_Summ_Paid numeric(18, 13) not null default 0, -- Фактически оплаченная сумма покупки данного товара, не включая сумму предоставленной скидки
  SKU_Discount numeric(18, 13) not null default 0   -- Размер предоставленной на товар скидки в рублях
);

create table AnalysisDate
(
  Analysis_Formation timestamp not null
);

create or replace function CheckTransactionStore()
returns trigger as $$
begin
  if exists(select 1 from RetailOutlets where Transaction_Store_ID = new.Transaction_Store_ID) then
    return new;
  else
    raise exception 'Not valid store';
  end if;
end;
$$ language plpgsql;

create trigger BeforeInsertUpdateTransactions before insert or update on Transactions
for each row execute function CheckTransactionStore();
